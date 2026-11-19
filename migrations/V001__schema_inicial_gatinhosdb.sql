-- ============================================================================
-- Migration: V001__schema_inicial_gatinhosdb.sql
-- Descrição: Estrutura inicial do Jogo dos Gatinhos (baseado no banco.odt)
-- ============================================================================

-- 1. Tabela Jogador
CREATE TABLE IF NOT EXISTS jogador (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(20) NOT NULL
);

-- 2. Tabela Raça
CREATE TABLE IF NOT EXISTS raca (
    raca VARCHAR(20) PRIMARY KEY,
    pata SMALLINT NOT NULL CHECK (pata BETWEEN 0 AND 9),
    barriga SMALLINT NOT NULL CHECK (barriga BETWEEN 0 AND 9),
    rabo SMALLINT NOT NULL CHECK (rabo BETWEEN 0 AND 9)
);

-- 3. Tabela Gatinho
CREATE TABLE IF NOT EXISTS gatinho (
    id SERIAL PRIMARY KEY,
    id_jogador INT NOT NULL,
    nome VARCHAR(20) NOT NULL,
    cor VARCHAR(10) NOT NULL,
    raca VARCHAR(20),
    level INT NOT NULL DEFAULT 1,
    CONSTRAINT fk_gatinho_jogador FOREIGN KEY (id_jogador) REFERENCES jogador(id) ON DELETE CASCADE,
    CONSTRAINT fk_gatinho_raca FOREIGN KEY (raca) REFERENCES raca(raca) ON DELETE SET NULL
);

-- 4. Tabela Carinho
CREATE TABLE IF NOT EXISTS carinho (
    id_gatinho INT NOT NULL,
    data_hora TIMESTAMP(0) NOT NULL,
    local_carinho VARCHAR(10) NOT NULL,
    PRIMARY KEY (id_gatinho, data_hora),
    CONSTRAINT fk_carinho_gatinho FOREIGN KEY (id_gatinho) REFERENCES gatinho(id) ON DELETE CASCADE
);

-- 5. Carga Inicial de Raças
INSERT INTO raca (raca, pata, barriga, rabo) VALUES
('siames', 0, 1, 2),
('persa', 0, 2, 1),
('frajola', 1, 0, 2),
('angora', 1, 2, 0),
('bengal', 1, 1, 1),
('ragdoll', 2, 1, 0),
('sphynx', 2, 0, 1)
ON CONFLICT (raca) DO NOTHING;
