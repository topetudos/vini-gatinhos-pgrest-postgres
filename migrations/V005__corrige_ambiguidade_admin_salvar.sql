-- ============================================================================
-- Migration: V005__corrige_ambiguidade_admin_salvar.sql
-- Descrição: Corrige o erro 42702 "column reference ... is ambiguous" em
--            admin_salvar_jogador (isadmin) e admin_salvar_raca (raca).
--            As colunas de RETURNS TABLE viram variáveis no PL/pgSQL e
--            colidem com as colunas das tabelas de mesmo nome.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- admin_salvar_jogador: qualifica as colunas no UPDATE e devolve os valores
-- realmente gravados (antes devolvia p_isadmin, que pode ser NULL).
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
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_new_id INT;
BEGIN
    PERFORM autenticar_jogador(app_userid, app_userpassword, TRUE);

    IF p_id IS NULL OR p_id <= 0 THEN
        -- Criar novo
        INSERT INTO jogador (nome, userpassword, isadmin)
        VALUES (p_nome, p_userpassword, COALESCE(p_isadmin, FALSE))
        RETURNING jogador.id INTO v_new_id;

        RETURN QUERY
        SELECT v_new_id, p_nome, COALESCE(p_isadmin, FALSE), 'Jogador criado com sucesso!'::TEXT;
    ELSE
        -- Atualizar existente
        UPDATE jogador AS j
        SET nome = p_nome,
            userpassword = CASE WHEN p_userpassword IS NOT NULL AND length(trim(p_userpassword)) > 0
                                THEN p_userpassword ELSE j.userpassword END,
            isadmin = COALESCE(p_isadmin, j.isadmin)
        WHERE j.id = p_id;

        RETURN QUERY
        SELECT j.id, j.nome, j.isadmin, 'Jogador atualizado com sucesso!'::TEXT
        FROM jogador AS j
        WHERE j.id = p_id;
    END IF;
END;
$function$;

-- ----------------------------------------------------------------------------
-- admin_salvar_raca: usa o nome da constraint no ON CONFLICT em vez da
-- coluna "raca", que colide com a coluna de saída de mesmo nome.
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
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    PERFORM autenticar_jogador(app_userid, app_userpassword, TRUE);

    INSERT INTO raca (raca, pata, barriga, rabo)
    VALUES (p_raca, p_pata, p_barriga, p_rabo)
    ON CONFLICT ON CONSTRAINT raca_pkey
    DO UPDATE SET
        pata    = EXCLUDED.pata,
        barriga = EXCLUDED.barriga,
        rabo    = EXCLUDED.rabo;

    RETURN QUERY
    SELECT p_raca, p_pata, p_barriga, p_rabo, 'Raça salva com sucesso!'::TEXT;
END;
$function$;
