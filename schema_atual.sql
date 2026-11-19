-- ============================================================================
-- schema_atual.sql
-- Snapshot do schema completo do banco Gatinhos DB (Aiven PostgreSQL)
-- Gerado em: 2026-11-19
-- Database: gatinhos
-- Host: pg-3c07c90e-vacadbteste.f.aivencloud.com:20582
--
-- Contém: tabelas, sequences, constraints, indexes, procedures,
--         functions e grants (exceto tabela schema_migrations).
-- ============================================================================


-- ============================================================================
-- SEQUENCES
-- ============================================================================

CREATE SEQUENCE IF NOT EXISTS public.jogador_id_seq
    AS integer START WITH 1 INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647;

CREATE SEQUENCE IF NOT EXISTS public.gatinho_id_seq
    AS integer START WITH 1 INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647;


-- ============================================================================
-- TABELAS
-- ============================================================================

-- Jogadores do sistema
CREATE TABLE IF NOT EXISTS public.jogador (
    id           INTEGER      NOT NULL DEFAULT nextval('jogador_id_seq'::regclass),
    nome         VARCHAR(20)  NOT NULL,
    userpassword VARCHAR(100) NOT NULL DEFAULT '123',
    isadmin      BOOLEAN      NOT NULL DEFAULT FALSE,
    CONSTRAINT jogador_pkey PRIMARY KEY (id)
);

-- Raças de gatinhos (bônus por parte do corpo — visível apenas para admins)
CREATE TABLE IF NOT EXISTS public.raca (
    raca    VARCHAR(20) NOT NULL,
    pata    SMALLINT    NOT NULL,
    barriga SMALLINT    NOT NULL,
    rabo    SMALLINT    NOT NULL,
    CONSTRAINT raca_pkey PRIMARY KEY (raca)
);

-- Gatinhos pertencentes aos jogadores
CREATE TABLE IF NOT EXISTS public.gatinho (
    id         INTEGER     NOT NULL DEFAULT nextval('gatinho_id_seq'::regclass),
    id_jogador INTEGER     NOT NULL,
    nome       VARCHAR(20) NOT NULL,
    cor        VARCHAR(10) NOT NULL,
    raca       VARCHAR(20),
    level      INTEGER     NOT NULL DEFAULT 1,
    CONSTRAINT gatinho_pkey PRIMARY KEY (id),
    CONSTRAINT fk_gatinho_jogador FOREIGN KEY (id_jogador)
        REFERENCES public.jogador (id) ON DELETE CASCADE,
    CONSTRAINT fk_gatinho_raca FOREIGN KEY (raca)
        REFERENCES public.raca (raca) ON DELETE SET NULL
);

-- Histórico de carinhos dados nos gatinhos
CREATE TABLE IF NOT EXISTS public.carinho (
    id_gatinho    INTEGER      NOT NULL,
    data_hora     TIMESTAMP    NOT NULL,
    local_carinho VARCHAR(10)  NOT NULL,
    CONSTRAINT carinho_pkey PRIMARY KEY (id_gatinho, data_hora),
    CONSTRAINT fk_carinho_gatinho FOREIGN KEY (id_gatinho)
        REFERENCES public.gatinho (id) ON DELETE CASCADE
);


-- ============================================================================
-- INDEXES
-- (os de PK já são criados automaticamente pelas constraints acima)
-- ============================================================================

-- Nenhum índice adicional além dos gerados pelas PKs.


-- ============================================================================
-- FUNCTIONS E PROCEDURES
-- ============================================================================

-- ----------------------------------------------------------------------------
-- autenticar_jogador
-- Função interna: valida ID + senha e opcionalmente exige isadmin=TRUE.
-- Usada como guard em todas as outras funções RPC.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.autenticar_jogador(
    p_userid       INTEGER,
    p_userpassword CHARACTER VARYING,
    p_requer_admin BOOLEAN DEFAULT FALSE
)
RETURNS public.jogador
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
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
$function$;

-- ----------------------------------------------------------------------------
-- login_jogador
-- Autentica o jogador e retorna id, nome e flag isadmin.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.login_jogador(
    app_userid       INTEGER,
    app_userpassword CHARACTER VARYING
)
RETURNS TABLE(id INTEGER, nome CHARACTER VARYING, isadmin BOOLEAN)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_jog jogador%ROWTYPE;
BEGIN
    v_jog := autenticar_jogador(app_userid, app_userpassword, FALSE);
    RETURN QUERY SELECT v_jog.id, v_jog.nome, v_jog.isadmin;
END;
$function$;

-- ----------------------------------------------------------------------------
-- listar_meus_gatinhos
-- Retorna os gatinhos do jogador autenticado.
-- NOTA: NÃO expõe bonus_pata/barriga/rabo — descobrir faz parte do jogo.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.listar_meus_gatinhos(
    app_userid       INTEGER,
    app_userpassword CHARACTER VARYING
)
RETURNS TABLE(
    id             INTEGER,
    nome           CHARACTER VARYING,
    cor            CHARACTER VARYING,
    raca           CHARACTER VARYING,
    level          INTEGER,
    total_carinhos BIGINT,
    ultimo_carinho TIMESTAMP WITHOUT TIME ZONE
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
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
        MAX(c.data_hora)    AS ultimo_carinho
    FROM gatinho g
    LEFT JOIN carinho c ON g.id = c.id_gatinho
    WHERE g.id_jogador = app_userid
    GROUP BY g.id, g.nome, g.cor, g.raca, g.level
    ORDER BY g.level DESC, g.id ASC;
END;
$function$;

-- ----------------------------------------------------------------------------
-- listar_racas
-- Retorna todas as raças COM os bônus — REQUER isadmin=TRUE.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.listar_racas(
    app_userid       INTEGER,
    app_userpassword CHARACTER VARYING
)
RETURNS TABLE(raca CHARACTER VARYING, pata SMALLINT, barriga SMALLINT, rabo SMALLINT)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    PERFORM autenticar_jogador(app_userid, app_userpassword, TRUE);
    RETURN QUERY SELECT r.raca, r.pata, r.barriga, r.rabo FROM raca r ORDER BY r.raca;
END;
$function$;

-- ----------------------------------------------------------------------------
-- ganhar_novo_gato
-- Sorteia raça e cor, insere novo gatinho para o jogador autenticado.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.ganhar_novo_gato(
    app_userid       INTEGER,
    app_userpassword CHARACTER VARYING
)
RETURNS TABLE(id INTEGER, nome CHARACTER VARYING, cor CHARACTER VARYING, raca CHARACTER VARYING, level INTEGER, mensagem TEXT)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_raca_gato VARCHAR(20);
    v_cor_gato  VARCHAR(10);
    v_id_gato   INT;
    v_cores     VARCHAR[] := ARRAY['amarelo', 'branco', 'preto'];
    v_msg       TEXT;
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

    v_msg := 'Parabéns! Você ganhou um novo gatinho da raça ' || v_raca_gato ||
             ' (' || v_cor_gato || ') com ID ' || v_id_gato ||
             '. Lembre de dar um nome para ele!';

    RETURN QUERY
    SELECT v_id_gato, 'Sem Nome'::VARCHAR(20), v_cor_gato, v_raca_gato, 1, v_msg;
END;
$function$;

-- ----------------------------------------------------------------------------
-- renomear_gatinho
-- Renomeia um gatinho pertencente ao jogador autenticado.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.renomear_gatinho(
    app_userid       INTEGER,
    app_userpassword CHARACTER VARYING,
    p_id_gatinho     INTEGER,
    p_novo_nome      CHARACTER VARYING
)
RETURNS TABLE(id INTEGER, nome CHARACTER VARYING, mensagem TEXT)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
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
$function$;

-- ----------------------------------------------------------------------------
-- carinho_pata_fn
-- Faz carinho na pata do gatinho — adiciona bonus_pata ao level.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.carinho_pata_fn(
    app_userid       INTEGER,
    app_userpassword CHARACTER VARYING,
    p_id_gatinho     INTEGER
)
RETURNS TABLE(id INTEGER, nome CHARACTER VARYING, novo_level INTEGER, pontos_ganhos INTEGER, mensagem TEXT)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_id_dono   INT;
    v_nome      VARCHAR(20);
    v_pontos    SMALLINT;
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
           ('Você fez carinho na pata de ' || v_nome || '! Ganhou +' || v_pontos ||
            ' level (Novo level: ' || v_novo_level || ')')::TEXT;
END;
$function$;

-- ----------------------------------------------------------------------------
-- carinho_barriga_fn
-- Faz carinho na barriga do gatinho — adiciona bonus_barriga ao level.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.carinho_barriga_fn(
    app_userid       INTEGER,
    app_userpassword CHARACTER VARYING,
    p_id_gatinho     INTEGER
)
RETURNS TABLE(id INTEGER, nome CHARACTER VARYING, novo_level INTEGER, pontos_ganhos INTEGER, mensagem TEXT)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_id_dono    INT;
    v_nome       VARCHAR(20);
    v_pontos     SMALLINT;
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
           ('Você fez carinho na barriga de ' || v_nome || '! Ganhou +' || v_pontos ||
            ' level (Novo level: ' || v_novo_level || ')')::TEXT;
END;
$function$;

-- ----------------------------------------------------------------------------
-- carinho_rabo_fn
-- Faz carinho no rabo do gatinho — adiciona bonus_rabo ao level.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.carinho_rabo_fn(
    app_userid       INTEGER,
    app_userpassword CHARACTER VARYING,
    p_id_gatinho     INTEGER
)
RETURNS TABLE(id INTEGER, nome CHARACTER VARYING, novo_level INTEGER, pontos_ganhos INTEGER, mensagem TEXT)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_id_dono    INT;
    v_nome       VARCHAR(20);
    v_pontos     SMALLINT;
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
           ('Você fez carinho no rabo de ' || v_nome || '! Ganhou +' || v_pontos ||
            ' level (Novo level: ' || v_novo_level || ')')::TEXT;
END;
$function$;

-- ----------------------------------------------------------------------------
-- obter_ranking_gatinhos
-- Retorna o top 5 gatinhos por level (critério de desempate: menos carinhos,
-- carinho mais antigo, id maior).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.obter_ranking_gatinhos(
    app_userid       INTEGER,
    app_userpassword CHARACTER VARYING
)
RETURNS TABLE(
    posicao             BIGINT,
    id_gato             INTEGER,
    nome_gato           CHARACTER VARYING,
    level_gato          INTEGER,
    raca                CHARACTER VARYING,
    cor                 CHARACTER VARYING,
    nome_dono           CHARACTER VARYING,
    quantidade_carinhos BIGINT,
    data_ultimo_carinho TIMESTAMP WITHOUT TIME ZONE
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
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
        g.id              AS id_gato,
        g.nome            AS nome_gato,
        g.level           AS level_gato,
        g.raca,
        g.cor,
        j.nome            AS nome_dono,
        COUNT(c.id_gatinho) AS quantidade_carinhos,
        MAX(c.data_hora)  AS data_ultimo_carinho
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
$function$;

-- ----------------------------------------------------------------------------
-- admin_listar_jogadores  [ADMIN]
-- Lista todos os jogadores com contagem de gatinhos.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_listar_jogadores(
    app_userid       INTEGER,
    app_userpassword CHARACTER VARYING
)
RETURNS TABLE(id INTEGER, nome CHARACTER VARYING, isadmin BOOLEAN, total_gatinhos BIGINT)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
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
$function$;

-- ----------------------------------------------------------------------------
-- admin_salvar_jogador  [ADMIN]
-- Cria ou atualiza um jogador.
-- Se p_id IS NULL ou <= 0: insere novo. Caso contrário: atualiza.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_salvar_jogador(
    app_userid       INTEGER,
    app_userpassword CHARACTER VARYING,
    p_id             INTEGER,
    p_nome           CHARACTER VARYING,
    p_userpassword   CHARACTER VARYING,
    p_isadmin        BOOLEAN
)
RETURNS TABLE(id INTEGER, nome CHARACTER VARYING, isadmin BOOLEAN, mensagem TEXT)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
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
            userpassword = CASE WHEN p_userpassword IS NOT NULL AND length(trim(p_userpassword)) > 0
                                THEN p_userpassword ELSE userpassword END,
            isadmin = COALESCE(p_isadmin, isadmin)
        WHERE jogador.id = p_id;

        RETURN QUERY
        SELECT p_id, p_nome, p_isadmin, 'Jogador atualizado com sucesso!'::TEXT;
    END IF;
END;
$function$;

-- ----------------------------------------------------------------------------
-- admin_salvar_raca  [ADMIN]
-- Cria ou atualiza uma raça (upsert).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_salvar_raca(
    app_userid       INTEGER,
    app_userpassword CHARACTER VARYING,
    p_raca           CHARACTER VARYING,
    p_pata           SMALLINT,
    p_barriga        SMALLINT,
    p_rabo           SMALLINT
)
RETURNS TABLE(raca CHARACTER VARYING, pata SMALLINT, barriga SMALLINT, rabo SMALLINT, mensagem TEXT)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    PERFORM autenticar_jogador(app_userid, app_userpassword, TRUE);

    INSERT INTO raca (raca, pata, barriga, rabo)
    VALUES (p_raca, p_pata, p_barriga, p_rabo)
    ON CONFLICT (raca)
    DO UPDATE SET
        pata    = EXCLUDED.pata,
        barriga = EXCLUDED.barriga,
        rabo    = EXCLUDED.rabo;

    RETURN QUERY
    SELECT p_raca, p_pata, p_barriga, p_rabo, 'Raça salva com sucesso!'::TEXT;
END;
$function$;

-- ----------------------------------------------------------------------------
-- admin_listar_todos_gatos  [ADMIN]
-- Lista todos os gatinhos de todos os jogadores.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_listar_todos_gatos(
    app_userid       INTEGER,
    app_userpassword CHARACTER VARYING
)
RETURNS TABLE(
    id             INTEGER,
    id_jogador     INTEGER,
    nome_dono      CHARACTER VARYING,
    nome           CHARACTER VARYING,
    cor            CHARACTER VARYING,
    raca           CHARACTER VARYING,
    level          INTEGER,
    total_carinhos BIGINT
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    PERFORM autenticar_jogador(app_userid, app_userpassword, TRUE);

    RETURN QUERY
    SELECT
        g.id,
        g.id_jogador,
        j.nome  AS nome_dono,
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
$function$;

-- ----------------------------------------------------------------------------
-- PROCEDURES legadas (versão anterior sem autenticação RPC)
-- Mantidas por compatibilidade; não são usadas pelo app atual.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE public.ganhar_gato(
    IN p_id_jogador INTEGER,
    INOUT r_mensagem TEXT DEFAULT NULL
)
LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_raca_gato VARCHAR(20);
    v_cor_gato  VARCHAR(10);
    v_id_gato   INT;
    v_cores     VARCHAR[] := ARRAY['amarelo', 'branco', 'preto'];
BEGIN
    SELECT raca INTO v_raca_gato FROM raca ORDER BY RANDOM() LIMIT 1;
    IF v_raca_gato IS NULL THEN
        r_mensagem := 'Erro: Cadastre pelo menos uma raça antes de ganhar um gato!';
        RETURN;
    END IF;

    v_cor_gato := v_cores[1 + floor(random() * array_length(v_cores, 1))::int];

    INSERT INTO gatinho (id_jogador, nome, cor, raca, level)
    VALUES (p_id_jogador, 'Sem Nome', v_cor_gato, v_raca_gato, 1)
    RETURNING id INTO v_id_gato;

    r_mensagem := 'Parabéns, você ganhou um novo gato, ' || v_raca_gato ||
                  ', cor ' || v_cor_gato ||
                  ', com o ID ' || v_id_gato ||
                  '. Lembre de dar um nome para ele!';
END;
$procedure$;

CREATE OR REPLACE PROCEDURE public.carinho_pata(
    IN p_id_gatinho INTEGER,
    INOUT r_nome_gatinho CHARACTER VARYING DEFAULT NULL,
    INOUT r_novo_level   INTEGER DEFAULT NULL
)
LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_pontos SMALLINT;
BEGIN
    SELECT r.pata, g.nome INTO v_pontos, r_nome_gatinho
    FROM gatinho g JOIN raca r ON g.raca = r.raca
    WHERE g.id = p_id_gatinho;

    IF v_pontos IS NOT NULL THEN
        UPDATE gatinho SET level = level + v_pontos
        WHERE id = p_id_gatinho
        RETURNING level INTO r_novo_level;

        INSERT INTO carinho (id_gatinho, data_hora, local_carinho)
        VALUES (p_id_gatinho, date_trunc('second', NOW()), 'pata');
    END IF;
END;
$procedure$;

CREATE OR REPLACE PROCEDURE public.carinho_barriga(
    IN p_id_gatinho INTEGER,
    INOUT r_nome_gatinho CHARACTER VARYING DEFAULT NULL,
    INOUT r_novo_level   INTEGER DEFAULT NULL
)
LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_pontos SMALLINT;
BEGIN
    SELECT r.barriga, g.nome INTO v_pontos, r_nome_gatinho
    FROM gatinho g JOIN raca r ON g.raca = r.raca
    WHERE g.id = p_id_gatinho;

    IF v_pontos IS NOT NULL THEN
        UPDATE gatinho SET level = level + v_pontos
        WHERE id = p_id_gatinho
        RETURNING level INTO r_novo_level;

        INSERT INTO carinho (id_gatinho, data_hora, local_carinho)
        VALUES (p_id_gatinho, date_trunc('second', NOW()), 'barriga');
    END IF;
END;
$procedure$;

CREATE OR REPLACE PROCEDURE public.carinho_rabo(
    IN p_id_gatinho INTEGER,
    INOUT r_nome_gatinho CHARACTER VARYING DEFAULT NULL,
    INOUT r_novo_level   INTEGER DEFAULT NULL
)
LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_pontos SMALLINT;
BEGIN
    SELECT r.rabo, g.nome INTO v_pontos, r_nome_gatinho
    FROM gatinho g JOIN raca r ON g.raca = r.raca
    WHERE g.id = p_id_gatinho;

    IF v_pontos IS NOT NULL THEN
        UPDATE gatinho SET level = level + v_pontos
        WHERE id = p_id_gatinho
        RETURNING level INTO r_novo_level;

        INSERT INTO carinho (id_gatinho, data_hora, local_carinho)
        VALUES (p_id_gatinho, date_trunc('second', NOW()), 'rabo');
    END IF;
END;
$procedure$;

CREATE OR REPLACE FUNCTION public.obter_ranking_gatinhos_fn()
RETURNS TABLE(
    posicao             BIGINT,
    id_gato             INTEGER,
    nome_gato           CHARACTER VARYING,
    level_gato          INTEGER,
    raca                CHARACTER VARYING,
    cor                 CHARACTER VARYING,
    nome_dono           CHARACTER VARYING,
    quantidade_carinhos BIGINT,
    data_ultimo_carinho TIMESTAMP WITHOUT TIME ZONE
)
LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT
        ROW_NUMBER() OVER (
            ORDER BY g.level DESC, COUNT(c.id_gatinho) ASC, MAX(c.data_hora) ASC, g.id DESC
        ) AS posicao,
        g.id, g.nome, g.level, g.raca, g.cor, j.nome,
        COUNT(c.id_gatinho), MAX(c.data_hora)
    FROM gatinho g
    JOIN jogador j ON g.id_jogador = j.id
    LEFT JOIN carinho c ON g.id = c.id_gatinho
    GROUP BY g.id, g.nome, g.level, g.raca, g.cor, j.nome
    ORDER BY level_gato DESC, quantidade_carinhos ASC, data_ultimo_carinho ASC, id_gato DESC
    LIMIT 5;
END;
$function$;


-- ============================================================================
-- GRANTS EM TABELAS
-- (apenas o owner "gatinhos"/avnadmin tem acesso — api_worker e web_anon NÃO)
-- ============================================================================

-- Nenhum GRANT de SELECT/INSERT/UPDATE/DELETE para api_worker ou web_anon
-- nas tabelas. Todo acesso se dá exclusivamente via funções SECURITY DEFINER.
-- (Os grants de tabela visíveis no catálogo são do owner avnadmin.)


-- ============================================================================
-- GRANTS EM FUNCTIONS
-- ============================================================================

-- Funções RPC principais (acessíveis pelo PostgREST via api_worker / web_anon)
GRANT EXECUTE ON FUNCTION public.login_jogador(INTEGER, CHARACTER VARYING)             TO api_worker, web_anon;
GRANT EXECUTE ON FUNCTION public.listar_meus_gatinhos(INTEGER, CHARACTER VARYING)      TO api_worker, web_anon;
GRANT EXECUTE ON FUNCTION public.listar_racas(INTEGER, CHARACTER VARYING)              TO api_worker, web_anon;
GRANT EXECUTE ON FUNCTION public.ganhar_novo_gato(INTEGER, CHARACTER VARYING)          TO api_worker, web_anon;
GRANT EXECUTE ON FUNCTION public.renomear_gatinho(INTEGER, CHARACTER VARYING, INTEGER, CHARACTER VARYING) TO api_worker, web_anon;
GRANT EXECUTE ON FUNCTION public.carinho_pata_fn(INTEGER, CHARACTER VARYING, INTEGER)  TO api_worker, web_anon;
GRANT EXECUTE ON FUNCTION public.carinho_barriga_fn(INTEGER, CHARACTER VARYING, INTEGER) TO api_worker, web_anon;
GRANT EXECUTE ON FUNCTION public.carinho_rabo_fn(INTEGER, CHARACTER VARYING, INTEGER)  TO api_worker, web_anon;
GRANT EXECUTE ON FUNCTION public.obter_ranking_gatinhos(INTEGER, CHARACTER VARYING)    TO api_worker, web_anon;
GRANT EXECUTE ON FUNCTION public.admin_listar_jogadores(INTEGER, CHARACTER VARYING)    TO api_worker, web_anon;
GRANT EXECUTE ON FUNCTION public.admin_salvar_jogador(INTEGER, CHARACTER VARYING, INTEGER, CHARACTER VARYING, CHARACTER VARYING, BOOLEAN) TO api_worker, web_anon;
GRANT EXECUTE ON FUNCTION public.admin_salvar_raca(INTEGER, CHARACTER VARYING, CHARACTER VARYING, SMALLINT, SMALLINT, SMALLINT) TO api_worker, web_anon;
GRANT EXECUTE ON FUNCTION public.admin_listar_todos_gatos(INTEGER, CHARACTER VARYING)  TO api_worker, web_anon;
GRANT EXECUTE ON FUNCTION public.autenticar_jogador(INTEGER, CHARACTER VARYING, BOOLEAN) TO api_worker, web_anon;

-- Funções legadas (procedures sem autenticação)
GRANT EXECUTE ON FUNCTION public.obter_ranking_gatinhos_fn()                           TO api_worker, web_anon;


-- ============================================================================
-- FIM DO SCHEMA
-- ============================================================================
