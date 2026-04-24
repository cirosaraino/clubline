#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET="${1:-local}"
CUSTOM_ENV_FILE="${2:-}"

case "${TARGET}" in
  local|dev|test) ;;
  *)
    echo "Per sicurezza rebuild-from-zero.sh accetta solo local, dev o test."
    exit 1
    ;;
esac

"${ROOT_DIR}/scripts/backend/install.sh"
"${ROOT_DIR}/scripts/env/use-backend-env.sh" "${TARGET}" "${CUSTOM_ENV_FILE}"
"${ROOT_DIR}/scripts/backend/reset-dev-db.sh" "${TARGET}" "${CUSTOM_ENV_FILE}"

cd "${ROOT_DIR}/backend"
npm run typecheck
