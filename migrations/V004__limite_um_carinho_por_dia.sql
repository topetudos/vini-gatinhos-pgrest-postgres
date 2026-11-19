-- ============================================================================
-- Migration: V004__limite_um_carinho_por_dia.sql
-- Descrição: Restringe a no máximo 1 carinho por dia por gatinho.
--            Qualquer tentativa de fazer um segundo carinho no mesmo dia
--            (independente do local: pata, barriga ou rabo) resulta em erro.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- carinho_pata_fn
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
    v_id_dono    INT;
    v_nome       VARCHAR(20);
    v_pontos     SMALLINT;
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

    -- Verifica se já houve carinho hoje (qualquer local)
    IF EXISTS (
        SELECT 1 FROM carinho
        WHERE id_gatinho = p_id_gatinho
          AND date_trunc('day', data_hora) = date_trunc('day', NOW())
    ) THEN
        RAISE EXCEPTION 'Você já fez carinho em % hoje! Volte amanhã.', v_nome;
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

    -- Verifica se já houve carinho hoje (qualquer local)
    IF EXISTS (
        SELECT 1 FROM carinho
        WHERE id_gatinho = p_id_gatinho
          AND date_trunc('day', data_hora) = date_trunc('day', NOW())
    ) THEN
        RAISE EXCEPTION 'Você já fez carinho em % hoje! Volte amanhã.', v_nome;
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

    -- Verifica se já houve carinho hoje (qualquer local)
    IF EXISTS (
        SELECT 1 FROM carinho
        WHERE id_gatinho = p_id_gatinho
          AND date_trunc('day', data_hora) = date_trunc('day', NOW())
    ) THEN
        RAISE EXCEPTION 'Você já fez carinho em % hoje! Volte amanhã.', v_nome;
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

-- Grants (já existiam, mas garantindo)
GRANT EXECUTE ON FUNCTION public.carinho_pata_fn(INTEGER, CHARACTER VARYING, INTEGER)    TO api_worker, web_anon;
GRANT EXECUTE ON FUNCTION public.carinho_barriga_fn(INTEGER, CHARACTER VARYING, INTEGER) TO api_worker, web_anon;
GRANT EXECUTE ON FUNCTION public.carinho_rabo_fn(INTEGER, CHARACTER VARYING, INTEGER)    TO api_worker, web_anon;

NOTIFY pgrst, 'reload schema';
