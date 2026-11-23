-- ============================================================================
-- Migration: V006__limite_quatro_gatinhos.sql
-- Descrição: ganhar_novo_gato passa a recusar quando o jogador já tem
--            4 gatinhos. A linha do jogador é travada (FOR UPDATE) antes da
--            contagem para que chamadas simultâneas não ultrapassem o limite.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.ganhar_novo_gato(
    app_userid       INTEGER,
    app_userpassword CHARACTER VARYING
)
RETURNS TABLE(id INTEGER, nome CHARACTER VARYING, cor CHARACTER VARYING, raca CHARACTER VARYING, level INTEGER, mensagem TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    c_max_gatinhos CONSTANT INT := 4;
    v_qtd_gatos INT;
    v_raca_gato VARCHAR(20);
    v_cor_gato VARCHAR(10);
    v_id_gato INT;
    v_cores VARCHAR[] := ARRAY['amarelo', 'branco', 'preto'];
    v_msg TEXT;
BEGIN
    PERFORM autenticar_jogador(app_userid, app_userpassword, FALSE);

    -- Serializa chamadas do mesmo jogador
    PERFORM 1 FROM jogador j WHERE j.id = app_userid FOR UPDATE;

    SELECT count(*) INTO v_qtd_gatos FROM gatinho g WHERE g.id_jogador = app_userid;
    IF v_qtd_gatos >= c_max_gatinhos THEN
        RAISE EXCEPTION 'Você já tem % gatinhos, o máximo permitido é %.', v_qtd_gatos, c_max_gatinhos;
    END IF;

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
$function$;
