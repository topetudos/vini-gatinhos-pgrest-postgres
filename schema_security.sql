-- ============================================================================
-- Banco de Dados: gatinhos (Aiven PostgreSQL + PostgREST Data API)
-- Script de Segurança: Proteção de Tabelas e Funções RPC com Autenticação
-- ============================================================================

-- 1. ADICIONAR CAMPOS userpassword E isadmin NA TABELA JOGADOR
ALTER TABLE jogador 
ADD COLUMN IF NOT EXISTS userpassword VARCHAR(100) NOT NULL DEFAULT '123',
ADD COLUMN IF NOT EXISTS isadmin BOOLEAN NOT NULL DEFAULT FALSE;

-- Atualizar jogadores padrão
UPDATE jogador SET isadmin = TRUE, userpassword = '123' WHERE id = 1;
UPDATE jogador SET isadmin = FALSE, userpassword = '123' WHERE id IN (2, 3);

-- 2. FUNÇÃO INTERNA DE AUTENTICAÇÃO E CHECAGEM DE PERMISSÕES
CREATE OR REPLACE FUNCTION autenticar_jogador(
    p_userid INT,
    p_userpassword VARCHAR,
    p_requer_admin BOOLEAN DEFAULT FALSE
) RETURNS jogador
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_jogador jogador%ROWTYPE;
BEGIN
    SELECT * INTO v_jogador
    FROM jogador
    WHERE id = p_userid AND userpassword = p_userpassword;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Acesso negado: ID ou senha incorretos'
            USING ERRCODE = '28000';
    END IF;

    IF p_requer_admin AND NOT v_jogador.isadmin THEN
        RAISE EXCEPTION 'Acesso negado: Requer privilégios de administrador'
            USING ERRCODE = '42501';
    END IF;

    RETURN v_jogador;
END;
$$;

-- 3. FUNÇÃO: LOGIN DO JOGADOR
CREATE OR REPLACE FUNCTION login_jogador(
    app_userid INT,
    app_userpassword VARCHAR
)
RETURNS TABLE (id INT, nome VARCHAR, isadmin BOOLEAN)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_jog jogador%ROWTYPE;
BEGIN
    v_jog := autenticar_jogador(app_userid, app_userpassword, FALSE);
    RETURN QUERY SELECT v_jog.id, v_jog.nome, v_jog.isadmin;
END;
$$;

-- 4. FUNÇÃO: LISTAR GATINHOS DO USUÁRIO (Sem expor bônus das raças)
CREATE OR REPLACE FUNCTION listar_meus_gatinhos(
    app_userid INT,
    app_userpassword VARCHAR
)
RETURNS TABLE (
    id INT,
    nome VARCHAR,
    cor VARCHAR,
    raca VARCHAR,
    level INT,
    total_carinhos BIGINT,
    ultimo_carinho TIMESTAMP
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    PERFORM autenticar_jogador(app_userid, app_userpassword, FALSE);

    RETURN QUERY
    SELECT 
        g.id,
        g.nome,
        g.cor,
        g.raca,
        g.level,
        COUNT(c.id_gatinho) AS total_carinhos,
        MAX(c.data_hora) AS ultimo_carinho
    FROM gatinho g
    LEFT JOIN carinho c ON g.id = c.id_gatinho
    WHERE g.id_jogador = app_userid
    GROUP BY g.id, g.nome, g.cor, g.raca, g.level
    ORDER BY g.level DESC, g.id ASC;
END;
$$;

-- 5. FUNÇÃO: GANHAR NOVO GATO
CREATE OR REPLACE FUNCTION ganhar_novo_gato(
    app_userid INT,
    app_userpassword VARCHAR
)
RETURNS TABLE (
    id INT,
    nome VARCHAR,
    cor VARCHAR,
    raca VARCHAR,
    level INT,
    mensagem TEXT
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_raca_gato VARCHAR(20);
    v_cor_gato VARCHAR(10);
    v_id_gato INT;
    v_cores VARCHAR[] := ARRAY['amarelo', 'branco', 'preto'];
    v_msg TEXT;
BEGIN
    PERFORM autenticar_jogador(app_userid, app_userpassword, FALSE);

    SELECT r.raca INTO v_raca_gato FROM raca r ORDER BY RANDOM() LIMIT 1;
    IF v_raca_gato IS NULL THEN
        RAISE EXCEPTION 'Erro: Não há raças cadastradas no sistema!';
    END IF;

    v_cor_gato := v_cores[1 + floor(random() * array_length(v_cores, 1))::int];

    INSERT INTO gatinho (id_jogador, nome, cor, raca, level)
    VALUES (app_userid, 'Sem Nome', v_cor_gato, v_raca_gato, 1)
    RETURNING gatinho.id INTO v_id_gato;

    v_msg := 'Parabéns! Você ganhou um novo gatinho da raça ' || v_raca_gato || ' (' || v_cor_gato || ') com ID ' || v_id_gato || '. Lembre de dar um nome para ele!';

    RETURN QUERY
    SELECT v_id_gato, 'Sem Nome'::VARCHAR(20), v_cor_gato, v_raca_gato, 1, v_msg;
END;
$$;

-- 6. FUNÇÃO: RENOMEAR GATINHO
CREATE OR REPLACE FUNCTION renomear_gatinho(
    app_userid INT,
    app_userpassword VARCHAR,
    p_id_gatinho INT,
    p_novo_nome VARCHAR
)
RETURNS TABLE (
    id INT,
    nome VARCHAR,
    mensagem TEXT
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_id_dono INT;
BEGIN
    PERFORM autenticar_jogador(app_userid, app_userpassword, FALSE);

    SELECT id_jogador INTO v_id_dono FROM gatinho WHERE gatinho.id = p_id_gatinho;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Gatinho com ID % não encontrado.', p_id_gatinho;
    END IF;

    IF v_id_dono <> app_userid THEN
        RAISE EXCEPTION 'Acesso negado: Este gatinho não pertence a você!';
    END IF;

    IF length(trim(p_novo_nome)) = 0 THEN
        RAISE EXCEPTION 'O nome do gatinho não pode ser vazio.';
    END IF;

    UPDATE gatinho
    SET nome = trim(p_novo_nome)
    WHERE gatinho.id = p_id_gatinho;

    RETURN QUERY
    SELECT p_id_gatinho, trim(p_novo_nome)::VARCHAR(20), 'Gatinho renomeado com sucesso!'::TEXT;
END;
$$;

-- 7. FUNÇÕES DE CARINHO
CREATE OR REPLACE FUNCTION carinho_pata_fn(
    app_userid INT,
    app_userpassword VARCHAR,
    p_id_gatinho INT
)
RETURNS TABLE (
    id INT,
    nome VARCHAR,
    novo_level INT,
    pontos_ganhos INT,
    mensagem TEXT
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_id_dono INT;
    v_nome VARCHAR(20);
    v_pontos SMALLINT;
    v_novo_level INT;
BEGIN
    PERFORM autenticar_jogador(app_userid, app_userpassword, FALSE);

    SELECT g.id_jogador, g.nome, COALESCE(r.pata, 0)
    INTO v_id_dono, v_nome, v_pontos
    FROM gatinho g
    LEFT JOIN raca r ON g.raca = r.raca
    WHERE g.id = p_id_gatinho;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Gatinho com ID % não encontrado.', p_id_gatinho;
    END IF;

    IF v_id_dono <> app_userid THEN
        RAISE EXCEPTION 'Acesso negado: Este gatinho pertence a outro jogador!';
    END IF;

    UPDATE gatinho
    SET level = level + v_pontos
    WHERE gatinho.id = p_id_gatinho
    RETURNING level INTO v_novo_level;

    INSERT INTO carinho (id_gatinho, data_hora, local_carinho)
    VALUES (p_id_gatinho, date_trunc('second', NOW()), 'pata');

    RETURN QUERY
    SELECT p_id_gatinho, v_nome, v_novo_level, v_pontos::INT,
           ('Você fez carinho na pata de ' || v_nome || '! Ganhou +' || v_pontos || ' level (Novo level: ' || v_novo_level || ')')::TEXT;
END;
$$;

CREATE OR REPLACE FUNCTION carinho_barriga_fn(
    app_userid INT,
    app_userpassword VARCHAR,
    p_id_gatinho INT
)
RETURNS TABLE (
    id INT,
    nome VARCHAR,
    novo_level INT,
    pontos_ganhos INT,
    mensagem TEXT
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_id_dono INT;
    v_nome VARCHAR(20);
    v_pontos SMALLINT;
    v_novo_level INT;
BEGIN
    PERFORM autenticar_jogador(app_userid, app_userpassword, FALSE);

    SELECT g.id_jogador, g.nome, COALESCE(r.barriga, 0)
    INTO v_id_dono, v_nome, v_pontos
    FROM gatinho g
    LEFT JOIN raca r ON g.raca = r.raca
    WHERE g.id = p_id_gatinho;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Gatinho com ID % não encontrado.', p_id_gatinho;
    END IF;

    IF v_id_dono <> app_userid THEN
        RAISE EXCEPTION 'Acesso negado: Este gatinho pertence a outro jogador!';
    END IF;

    UPDATE gatinho
    SET level = level + v_pontos
    WHERE gatinho.id = p_id_gatinho
    RETURNING level INTO v_novo_level;

    INSERT INTO carinho (id_gatinho, data_hora, local_carinho)
    VALUES (p_id_gatinho, date_trunc('second', NOW()), 'barriga');

    RETURN QUERY
    SELECT p_id_gatinho, v_nome, v_novo_level, v_pontos::INT,
           ('Você fez carinho na barriga de ' || v_nome || '! Ganhou +' || v_pontos || ' level (Novo level: ' || v_novo_level || ')')::TEXT;
END;
$$;

CREATE OR REPLACE FUNCTION carinho_rabo_fn(
    app_userid INT,
    app_userpassword VARCHAR,
    p_id_gatinho INT
)
RETURNS TABLE (
    id INT,
    nome VARCHAR,
    novo_level INT,
    pontos_ganhos INT,
    mensagem TEXT
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_id_dono INT;
    v_nome VARCHAR(20);
    v_pontos SMALLINT;
    v_novo_level INT;
BEGIN
    PERFORM autenticar_jogador(app_userid, app_userpassword, FALSE);

    SELECT g.id_jogador, g.nome, COALESCE(r.rabo, 0)
    INTO v_id_dono, v_nome, v_pontos
    FROM gatinho g
    LEFT JOIN raca r ON g.raca = r.raca
    WHERE g.id = p_id_gatinho;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Gatinho com ID % não encontrado.', p_id_gatinho;
    END IF;

    IF v_id_dono <> app_userid THEN
        RAISE EXCEPTION 'Acesso negado: Este gatinho pertence a outro jogador!';
    END IF;

    UPDATE gatinho
    SET level = level + v_pontos
    WHERE gatinho.id = p_id_gatinho
    RETURNING level INTO v_novo_level;

    INSERT INTO carinho (id_gatinho, data_hora, local_carinho)
    VALUES (p_id_gatinho, date_trunc('second', NOW()), 'rabo');

    RETURN QUERY
    SELECT p_id_gatinho, v_nome, v_novo_level, v_pontos::INT,
           ('Você fez carinho no rabo de ' || v_nome || '! Ganhou +' || v_pontos || ' level (Novo level: ' || v_novo_level || ')')::TEXT;
END;
$$;

-- 8. FUNÇÃO: RANKING TOP 5
CREATE OR REPLACE FUNCTION obter_ranking_gatinhos(
    app_userid INT,
    app_userpassword VARCHAR
)
RETURNS TABLE (
    posicao BIGINT,
    id_gato INT,
    nome_gato VARCHAR(20),
    level_gato INT,
    raca VARCHAR(20),
    cor VARCHAR(10),
    nome_dono VARCHAR(20),
    quantidade_carinhos BIGINT,
    data_ultimo_carinho TIMESTAMP
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    PERFORM autenticar_jogador(app_userid, app_userpassword, FALSE);

    RETURN QUERY
    SELECT 
        ROW_NUMBER() OVER (
            ORDER BY 
                g.level DESC, 
                COUNT(c.id_gatinho) ASC, 
                MAX(c.data_hora) ASC, 
                g.id DESC
        ) AS posicao,
        g.id AS id_gato,
        g.nome AS nome_gato,
        g.level AS level_gato,
        g.raca,
        g.cor,
        j.nome AS nome_dono,
        COUNT(c.id_gatinho) AS quantidade_carinhos,
        MAX(c.data_hora) AS data_ultimo_carinho
    FROM gatinho g
    JOIN jogador j ON g.id_jogador = j.id
    LEFT JOIN carinho c ON g.id = c.id_gatinho
    GROUP BY g.id, g.nome, g.level, g.raca, g.cor, j.nome
    ORDER BY 
        level_gato DESC, 
        quantidade_carinhos ASC, 
        data_ultimo_carinho ASC, 
        id_gato DESC
    LIMIT 5;
END;
$$;

-- 9. FUNÇÃO: LISTAR RAÇAS (Restrita a administradores)
CREATE OR REPLACE FUNCTION listar_racas(
    app_userid INT,
    app_userpassword VARCHAR
)
RETURNS TABLE (
    raca VARCHAR(20),
    pata SMALLINT,
    barriga SMALLINT,
    rabo SMALLINT
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    PERFORM autenticar_jogador(app_userid, app_userpassword, TRUE);
    RETURN QUERY SELECT r.raca, r.pata, r.barriga, r.rabo FROM raca r ORDER BY r.raca;
END;
$$;

-- 10. FUNÇÕES ADMINISTRATIVAS (isadmin = TRUE)
CREATE OR REPLACE FUNCTION admin_listar_jogadores(
    app_userid INT,
    app_userpassword VARCHAR
)
RETURNS TABLE (
    id INT,
    nome VARCHAR,
    isadmin BOOLEAN,
    total_gatinhos BIGINT
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    PERFORM autenticar_jogador(app_userid, app_userpassword, TRUE);

    RETURN QUERY
    SELECT 
        j.id,
        j.nome,
        j.isadmin,
        COUNT(g.id) AS total_gatinhos
    FROM jogador j
    LEFT JOIN gatinho g ON j.id = g.id_jogador
    GROUP BY j.id, j.nome, j.isadmin
    ORDER BY j.id ASC;
END;
$$;

CREATE OR REPLACE FUNCTION admin_salvar_jogador(
    app_userid INT,
    app_userpassword VARCHAR,
    p_id INT,
    p_nome VARCHAR,
    p_userpassword VARCHAR,
    p_isadmin BOOLEAN
)
RETURNS TABLE (
    id INT,
    nome VARCHAR,
    isadmin BOOLEAN,
    mensagem TEXT
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_new_id INT;
BEGIN
    PERFORM autenticar_jogador(app_userid, app_userpassword, TRUE);

    IF p_id IS NULL OR p_id <= 0 THEN
        INSERT INTO jogador (nome, userpassword, isadmin)
        VALUES (p_nome, p_userpassword, COALESCE(p_isadmin, FALSE))
        RETURNING jogador.id INTO v_new_id;

        RETURN QUERY
        SELECT v_new_id, p_nome, COALESCE(p_isadmin, FALSE), 'Jogador criado com sucesso!'::TEXT;
    ELSE
        UPDATE jogador
        SET nome = p_nome,
            userpassword = CASE WHEN p_userpassword IS NOT NULL AND length(trim(p_userpassword)) > 0 THEN p_userpassword ELSE userpassword END,
            isadmin = COALESCE(p_isadmin, isadmin)
        WHERE jogador.id = p_id;

        RETURN QUERY
        SELECT p_id, p_nome, p_isadmin, 'Jogador atualizado com sucesso!'::TEXT;
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION admin_salvar_raca(
    app_userid INT,
    app_userpassword VARCHAR,
    p_raca VARCHAR,
    p_pata SMALLINT,
    p_barriga SMALLINT,
    p_rabo SMALLINT
)
RETURNS TABLE (
    raca VARCHAR(20),
    pata SMALLINT,
    barriga SMALLINT,
    rabo SMALLINT,
    mensagem TEXT
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    PERFORM autenticar_jogador(app_userid, app_userpassword, TRUE);

    INSERT INTO raca (raca, pata, barriga, rabo)
    VALUES (p_raca, p_pata, p_barriga, p_rabo)
    ON CONFLICT (raca) 
    DO UPDATE SET 
        pata = EXCLUDED.pata,
        barriga = EXCLUDED.barriga,
        rabo = EXCLUDED.rabo;

    RETURN QUERY
    SELECT p_raca, p_pata, p_barriga, p_rabo, 'Raça salva com sucesso!'::TEXT;
END;
$$;

CREATE OR REPLACE FUNCTION admin_listar_todos_gatos(
    app_userid INT,
    app_userpassword VARCHAR
)
RETURNS TABLE (
    id INT,
    id_jogador INT,
    nome_dono VARCHAR,
    nome VARCHAR,
    cor VARCHAR,
    raca VARCHAR,
    level INT,
    total_carinhos BIGINT
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    PERFORM autenticar_jogador(app_userid, app_userpassword, TRUE);

    RETURN QUERY
    SELECT 
        g.id,
        g.id_jogador,
        j.nome AS nome_dono,
        g.nome,
        g.cor,
        g.raca,
        g.level,
        COUNT(c.id_gatinho) AS total_carinhos
    FROM gatinho g
    JOIN jogador j ON g.id_jogador = j.id
    LEFT JOIN carinho c ON g.id = c.id_gatinho
    GROUP BY g.id, g.id_jogador, j.nome, g.nome, g.cor, g.raca, g.level
    ORDER BY g.id ASC;
END;
$$;

-- 11. REVOGAR ACESSO DIRETO ÀS TABELAS E GARANTIR EXECUÇÃO DAS FUNÇÕES
REVOKE ALL ON TABLE jogador, gatinho, raca, carinho FROM api_worker, web_anon, PUBLIC;
GRANT USAGE ON SCHEMA public TO api_worker, web_anon;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO api_worker, web_anon;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO api_worker;
