-- ============================================================================
-- Migration: V003__ocultar_pontuacao_racas.sql
-- Descrição: Oculta pontuações de bônus por parte do corpo (pata/barriga/rabo)
--            das funções acessíveis por jogadores comuns. Descobrir os bônus
--            faz parte do jogo — apenas admins podem ver essa informação.
--            Também restringe listar_racas a administradores.
-- ============================================================================

-- 1. Recriar listar_meus_gatinhos SEM os campos pata/barriga/rabo
DROP FUNCTION IF EXISTS listar_meus_gatinhos(INT, VARCHAR);

CREATE OR REPLACE FUNCTION listar_meus_gatinhos(
    app_userid INT,
    app_userpassword VARCHAR
)
RETURNS TABLE (
    id              INT,
    nome            VARCHAR,
    cor             VARCHAR,
    raca            VARCHAR,
    level           INT,
    total_carinhos  BIGINT,
    ultimo_carinho  TIMESTAMP
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
        r.nome  AS raca,
        g.level,
        g.total_carinhos,
        g.ultimo_carinho
    FROM gatinho g
    JOIN raca r ON r.id = g.id_raca
    WHERE g.id_jogador = app_userid
    ORDER BY g.level DESC, g.total_carinhos DESC;
END;
$$;

-- 2. Recriar listar_racas exigindo isadmin = TRUE
DROP FUNCTION IF EXISTS listar_racas(INT, VARCHAR);

CREATE OR REPLACE FUNCTION listar_racas(
    app_userid INT,
    app_userpassword VARCHAR
)
RETURNS TABLE (
    id              INT,
    nome            VARCHAR,
    bonus_pata      INT,
    bonus_barriga   INT,
    bonus_rabo      INT
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    -- Apenas administradores podem listar raças com bônus
    PERFORM autenticar_jogador(app_userid, app_userpassword, TRUE);

    RETURN QUERY
    SELECT r.id, r.nome, r.bonus_pata, r.bonus_barriga, r.bonus_rabo
    FROM raca r
    ORDER BY r.id;
END;
$$;

-- 3. Reatribuir permissões de execução
GRANT EXECUTE ON FUNCTION listar_meus_gatinhos(INT, VARCHAR) TO api_worker, web_anon;
GRANT EXECUTE ON FUNCTION listar_racas(INT, VARCHAR)         TO api_worker, web_anon;

-- 4. Notificar PostgREST para recarregar o cache de schema
NOTIFY pgrst, 'reload schema';
