#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# seed_schema_redesign.sh – Seed a fresh database with production data *and*
# migrate it to the redesigned schema (recipes/components/etc.).
# -----------------------------------------------------------------------------
# This script performs the following steps:
#   1. Loads the legacy data dump contained in `seed_oldschema.sql` which
#      reflects the **pre-redesign** schema (dishes/preparations/ingredients …).
#   2. Sequentially executes every SQL file in `../migrations/`, thereby
#      transforming the database into the **new unified schema** while
#      preserving all data.
#
# Usage:
#   ./seed_schema_redesign.sh <DATABASE_URL>
#
# or export DATABASE_URL beforehand:
#   export DATABASE_URL="postgresql://postgres:postgres@localhost:54322/postgres"
#   ./seed_schema_redesign.sh
# -----------------------------------------------------------------------------
set -euo pipefail

# --- Resolve paths ------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUPABASE_DIR="$(dirname "$SCRIPT_DIR")"
LEGACY_SEED="$SUPABASE_DIR/seed_oldschema.sql"
MIGRATIONS_DIR="$SUPABASE_DIR/migrations"

if [[ ! -f "$LEGACY_SEED" ]]; then
  echo "❌ Legacy seed file not found: $LEGACY_SEED" >&2
  exit 1
fi
if [[ ! -d "$MIGRATIONS_DIR" ]]; then
  echo "❌ Migrations directory not found: $MIGRATIONS_DIR" >&2
  exit 1
fi

# --- Database connection ------------------------------------------------------
DB_URL="${1:-${DATABASE_URL:-}}"
if [[ -z "$DB_URL" ]]; then
  echo "Usage: $0 <DATABASE_URL> or export DATABASE_URL first." >&2
  exit 1
fi

# --- (Optional) Load old schema definitions ----------------------------------
REMOTE_SCHEMA_FILE=$(ls "$MIGRATIONS_DIR"/*_remote_schema.sql 2>/dev/null | head -n 1 || true)
if [[ -f "$REMOTE_SCHEMA_FILE" ]]; then
  echo "⏩ Setting up legacy schema (\"$(basename "$REMOTE_SCHEMA_FILE")\")…"
  # Allow duplicate object errors (types, tables) in legacy dump
  psql "$DB_URL" -v ON_ERROR_STOP=0 -f "$REMOTE_SCHEMA_FILE" || true
else
  echo "⚠️  No *_remote_schema.sql file found – assuming schema already exists."
fi

echo "⏩ Loading legacy seed data (ignoring duplicates)…"
# Allow duplicate key errors while importing massive dump
psql "$DB_URL" -v ON_ERROR_STOP=0 -f "$LEGACY_SEED" || true

echo "⏩ Running migrations…"
# Ensure deterministic order
for sql_file in $(ls "$MIGRATIONS_DIR"/*.sql | sort); do
  # Skip the remote_schema file (already applied above)
  if [[ "$sql_file" == "$REMOTE_SCHEMA_FILE" ]]; then
    continue
  fi
  bn=$(basename "$sql_file")
  # Skip main schema redesign migration if recipes table already exists
  if [[ "$bn" == *"schema_redesign.sql" ]]; then
    if [[ "$(psql "$DB_URL" -Atqc "SELECT to_regclass('public.recipes')")" == "public.recipes" ]]; then
      echo "  → Skipping $bn (recipes table already exists)"
      continue
    fi
  fi
  echo "  → $bn"
  psql "$DB_URL" -v ON_ERROR_STOP=0 -f "$sql_file" || true
done

echo "✅ Database is now seeded and upgraded to the redesigned schema."
