#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET="${1:-}"
CUSTOM_ENV_FILE="${2:-}"

# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/env/_backend_env_helpers.sh"

if [[ -z "${TARGET}" ]]; then
  echo "Uso: ./scripts/db/apply-clubline-schema.sh <local|dev|prod|test> [percorso-file-env]"
  exit 1
fi

if ! TARGET="$(normalize_backend_target "${TARGET}")"; then
  echo "Target non valido: ${TARGET}. Usa local, dev, prod oppure test."
  exit 1
fi

ENV_FILE="${CUSTOM_ENV_FILE:-$(backend_env_local_file "${ROOT_DIR}" "${TARGET}")}"
if [[ ! -f "${ENV_FILE}" ]]; then
  echo "File env non trovato: ${ENV_FILE}"
  echo "Crea prima il file locale partendo da $(backend_env_example_file "${ROOT_DIR}" "${TARGET}")"
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
