#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET="${1:-}"
CUSTOM_ENV_FILE="${2:-}"

if [[ -z "${TARGET}" ]]; then
  echo "Uso: ./scripts/db/apply-clubline-schema.sh <dev|test|prod> [percorso-file-env]"
  exit 1
fi

case "${TARGET}" in
  dev|test|prod) ;;
  *)
    echo "Target non valido: ${TARGET}. Usa dev, test oppure prod."
    exit 1
    ;;
esac

ENV_FILE="${CUSTOM_ENV_FILE:-${ROOT_DIR}/backend/.env.clubline-${TARGET}.local}"
if [[ ! -f "${ENV_FILE}" ]]; then
  echo "File env non trovato: ${ENV_FILE}"
  echo "Crea prima il file locale partendo da ${ROOT_DIR}/backend/.env.clubline-${TARGET}.example"
  exit 1
fi

if ! command -v psql >/dev/null 2>&1; then
  echo "psql non trovato. Installa il client PostgreSQL prima di usare questo script."
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

if [[ -z "${SUPABASE_DB_URL:-}" ]]; then
  echo "SUPABASE_DB_URL non impostata in ${ENV_FILE}"
  exit 1
fi

echo "Applicazione schema Clubline su target ${TARGET}..."
psql "${SUPABASE_DB_URL}" -v ON_ERROR_STOP=1 -f "${ROOT_DIR}/sql/production_schema.sql"
psql "${SUPABASE_DB_URL}" -v ON_ERROR_STOP=1 -f "${ROOT_DIR}/sql/clubline_multi_club_refactor.sql"
psql "${SUPABASE_DB_URL}" -v ON_ERROR_STOP=1 -f "${ROOT_DIR}/sql/clubline_player_identity_refactor.sql"
psql "${SUPABASE_DB_URL}" -v ON_ERROR_STOP=1 -f "${ROOT_DIR}/sql/clubline_player_membership_guardrails.sql"
psql "${SUPABASE_DB_URL}" -v ON_ERROR_STOP=1 -f "${ROOT_DIR}/sql/clubline_backend_hardening.sql"
psql "${SUPABASE_DB_URL}" -v ON_ERROR_STOP=1 -f "${ROOT_DIR}/sql/clubline_post_refactor_grants.sql"
echo "Schema Clubline applicato correttamente su ${TARGET}."
