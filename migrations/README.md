# 📦 Migrações do Banco de Dados — Gatinhos DB

Este diretório contém o histórico completo de alterações na estrutura e nas funções do banco de dados PostgreSQL do projeto Gatinhos RPG.

## 📋 Convenção de Nomes

```
V{NNN}__{descricao_snake_case}.sql
```

| Exemplo | Significado |
|---|---|
| `V001__schema_inicial_gatinhosdb.sql` | Primeira versão — schema base |
| `V002__seguranca_e_funcoes_rpc.sql` | Adiciona autenticação e funções RPC |
| `V003__ocultar_pontuacao_racas.sql` | Esconde bônus de raças dos jogadores |
| `V004__limite_um_carinho_por_dia.sql` | Limita a 1 carinho por dia por gatinho |

**Regra de ouro:** Uma vez que uma migração é commitada no Git, ela é **imutável**. Para alterar algo, crie um novo `V00N`.

---

## 📁 Arquivos

| Arquivo | Função |
|---|---|
| `V001__schema_inicial_gatinhosdb.sql` | Schema original: tabelas `jogador`, `raca`, `gatinho` |
| `V002__seguranca_e_funcoes_rpc.sql` | Colunas `userpassword`/`isadmin`, funções RPC com `SECURITY DEFINER`, revogação de acesso direto |
| `V003__ocultar_pontuacao_racas.sql` | Remove `pata/barriga/rabo` de `listar_meus_gatinhos`; `listar_racas` passa a exigir `isadmin=TRUE` |
| `V004__limite_um_carinho_por_dia.sql` | Recria `carinho_pata_fn`, `carinho_barriga_fn` e `carinho_rabo_fn`: no máximo 1 carinho por dia por gatinho, em qualquer local |
| `schema_migrations_setup.sql` | Cria a tabela `schema_migrations` e registra V001–V003 como já aplicadas |
| `run_migrations.py` | Script Python para aplicar migrações pendentes automaticamente |

---

## 🚀 Como Aplicar uma Nova Migração

### 1. Criar a tabela de controle (apenas uma vez)

```bash
export DATABASE_URL="postgres://avnadmin:SENHA@host:porta/gatinhos?sslmode=require"
psql $DATABASE_URL -f migrations/schema_migrations_setup.sql
```

### 2. Verificar quais migrações serão aplicadas (dry-run)

```bash
DATABASE_URL="$DATABASE_URL" \
PYTHONPATH=/home/s007379909/snap/antigravity-cli/common/local/lib/python3.14/dist-packages \
python3 migrations/run_migrations.py --dry-run
```

### 3. Aplicar as migrações pendentes

```bash
DATABASE_URL="$DATABASE_URL" \
PYTHONPATH=/home/s007379909/snap/antigravity-cli/common/local/lib/python3.14/dist-packages \
python3 migrations/run_migrations.py
```

---

## ✍️ Como Criar uma Nova Migração

1. Crie o arquivo seguindo o padrão: `V004__descricao_da_mudanca.sql`
2. Escreva o SQL idempotente sempre que possível (`CREATE OR REPLACE`, `ALTER TABLE ... ADD COLUMN IF NOT EXISTS`, etc.)
3. Inclua um cabeçalho comentado explicando o que a migração faz
4. Commite o arquivo no Git **antes** de aplicar
5. Aplique com `run_migrations.py`

---

## 🔍 Verificar Migrações Aplicadas no Banco

```sql
SELECT versao, descricao, aplicado_em, executado_por
FROM schema_migrations
ORDER BY versao;
```

---

## ⚠️ Estado Atual

As migrações V001, V002 e V003 foram aplicadas **manualmente** antes da criação deste sistema de controle.  
O arquivo `schema_migrations_setup.sql` registra esses históricos retroativamente na tabela de controle.
