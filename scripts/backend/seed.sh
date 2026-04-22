#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET="${1:-dev}"
CUSTOM_ENV_FILE="${2:-}"

case "${TARGET}" in
  dev|test) ;;
  *)
    echo "Il seed di default e disponibile solo per dev o test."
    exit 1
    ;;
esac

ENV_FILE="${CUSTOM_ENV_FILE:-${ROOT_DIR}/backend/.env.clubline-${TARGET}.local}"
if [[ ! -f "${ENV_FILE}" ]]; then
  echo "File env non trovato: ${ENV_FILE}"
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

psql "${SUPABASE_DB_URL}" -v ON_ERROR_STOP=1 -f "${ROOT_DIR}/sql/clubline_seed_dev.sql"
echo "Seed Clubline completato per ${TARGET}."
