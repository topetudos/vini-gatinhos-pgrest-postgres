-- ============================================================================
-- Tabela de controle de migrações aplicadas
-- Execute este script UMA VEZ no banco para criar a tabela de rastreamento.
-- Depois, execute run_migrations.py para aplicar as migrações pendentes.
-- ============================================================================

CREATE TABLE IF NOT EXISTS schema_migrations (
    versao        VARCHAR(50)  PRIMARY KEY,
    descricao     TEXT         NOT NULL,
    aplicado_em   TIMESTAMP    NOT NULL DEFAULT NOW(),
    executado_por VARCHAR(100) NOT NULL DEFAULT CURRENT_USER
);

-- Registrar as migrações que já foram aplicadas manualmente
INSERT INTO schema_migrations (versao, descricao) VALUES
    ('V001', 'Schema inicial gatinhosdb'),
    ('V002', 'Segurança e funções RPC'),
    ('V003', 'Ocultar pontuação de raças dos jogadores')
ON CONFLICT (versao) DO NOTHING;
