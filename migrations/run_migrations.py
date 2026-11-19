#!/usr/bin/env python3
"""
run_migrations.py — Aplicador de migrações para o banco Gatinhos DB (Aiven PostgreSQL)

USO:
    python3 run_migrations.py [--dry-run]

REQUISITOS:
    - psycopg2 instalado:
      pip install psycopg2-binary
      (ou use o prefixo PYTHONPATH se estiver no ambiente snap do Antigravity)

    - Variável de ambiente DATABASE_URL configurada, ex:
      export DATABASE_URL="postgres://avnadmin:SENHA@host:porta/gatinhos?sslmode=require"

    - Tabela schema_migrations criada no banco:
      psql $DATABASE_URL -f migrations/schema_migrations_setup.sql

EXEMPLOS:
    # Visualizar quais migrações seriam aplicadas (sem executar)
    DATABASE_URL="postgres://..." python3 migrations/run_migrations.py --dry-run

    # Aplicar todas as migrações pendentes
    DATABASE_URL="postgres://..." python3 migrations/run_migrations.py

CONVENÇÃO DE NOMES:
    Arquivos seguem o padrão:  V{NNN}__{descricao_snake_case}.sql
    Ex:  V001__schema_inicial.sql
         V004__nova_funcionalidade.sql

    - Uma vez commitado, um arquivo de migração é IMUTÁVEL.
    - Para desfazer ou alterar algo, crie um novo V00N.
"""

import os
import sys
import glob
import re

try:
    import psycopg2
    import psycopg2.extras
except ImportError:
    print("ERRO: psycopg2 não encontrado.")
    print("Tente: PYTHONPATH=/home/s007379909/snap/antigravity-cli/common/local/lib/python3.14/dist-packages python3 migrations/run_migrations.py")
    sys.exit(1)

DRY_RUN = "--dry-run" in sys.argv

DATABASE_URL = os.environ.get("DATABASE_URL")
if not DATABASE_URL:
    print("ERRO: Variável DATABASE_URL não definida.")
    print('Exemplo: export DATABASE_URL="postgres://avnadmin:SENHA@host:porta/gatinhos?sslmode=require"')
    sys.exit(1)

# Diretório onde estão as migrações (mesmo diretório deste script)
MIGRATIONS_DIR = os.path.dirname(os.path.abspath(__file__))

VERSION_RE = re.compile(r'^V(\d+)__.*\.sql$', re.IGNORECASE)


def get_migration_files():
    """Retorna lista de arquivos de migração ordenados por versão."""
    files = glob.glob(os.path.join(MIGRATIONS_DIR, "V*.sql"))
    # Filtra apenas arquivos que seguem o padrão V000__....sql
    valid = [(f, VERSION_RE.match(os.path.basename(f))) for f in files]
    valid = [(f, m) for f, m in valid if m]
    # Ordena pelo número de versão
    valid.sort(key=lambda x: int(x[1].group(1)))
    return [(f, int(m.group(1)), os.path.basename(f).split('__', 1)[1].replace('.sql', '').replace('_', ' ')) for f, m in valid]


def get_applied_versions(cursor):
    """Retorna conjunto de versões já aplicadas."""
    try:
        cursor.execute("SELECT versao FROM schema_migrations ORDER BY versao;")
        return {row[0] for row in cursor.fetchall()}
    except psycopg2.errors.UndefinedTable:
        print("AVISO: Tabela schema_migrations não existe. Execute schema_migrations_setup.sql primeiro.")
        sys.exit(1)


def run():
    migration_files = get_migration_files()
    if not migration_files:
        print("Nenhum arquivo de migração encontrado em:", MIGRATIONS_DIR)
        return

    conn = psycopg2.connect(DATABASE_URL)
    conn.autocommit = False
    cur = conn.cursor()

    applied = get_applied_versions(cur)
    pending = [(f, num, desc) for f, num, desc in migration_files if f"V{num:03d}" not in applied]

    if not pending:
        print("✅ Todas as migrações já foram aplicadas. Nada a fazer.")
        conn.close()
        return

    print(f"{'[DRY-RUN] ' if DRY_RUN else ''}Migrações pendentes ({len(pending)}):")
    for f, num, desc in pending:
        print(f"  → V{num:03d}: {desc}")

    if DRY_RUN:
        print("\n[DRY-RUN] Nenhuma alteração foi feita no banco.")
        conn.close()
        return

    for filepath, num, desc in pending:
        versao = f"V{num:03d}"
        print(f"\nAplicando {versao}: {desc}...")
        try:
            with open(filepath, 'r', encoding='utf-8') as fh:
                sql = fh.read()

            cur.execute(sql)
            cur.execute(
                "INSERT INTO schema_migrations (versao, descricao) VALUES (%s, %s) ON CONFLICT DO NOTHING;",
                (versao, desc)
            )
            conn.commit()
            print(f"  ✅ {versao} aplicada com sucesso.")
        except Exception as e:
            conn.rollback()
            print(f"  ❌ ERRO ao aplicar {versao}: {e}")
            print("  Rollback realizado. Corrija o problema e tente novamente.")
            conn.close()
            sys.exit(1)

    print("\n✅ Todas as migrações pendentes foram aplicadas com sucesso!")
    conn.close()


if __name__ == "__main__":
    run()
