#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET="${1:-local}"
CUSTOM_ENV_FILE="${2:-}"

case "${TARGET}" in
  local|dev|test) ;;
  *)
    echo "Per sicurezza reset-dev-db.sh accetta solo local, dev o test."
    exit 1
    ;;
esac

"${ROOT_DIR}/scripts/backend/migrate.sh" "${TARGET}" "${CUSTOM_ENV_FILE}"
"${ROOT_DIR}/scripts/backend/seed.sh" "${TARGET}" "${CUSTOM_ENV_FILE}"
"${ROOT_DIR}/scripts/db/verify-clubline-schema.sh" "${TARGET}" "${CUSTOM_ENV_FILE}"
