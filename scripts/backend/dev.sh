#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET="${1:-}"
CUSTOM_ENV_FILE="${2:-}"

if [[ -n "${TARGET}" ]]; then
  "${ROOT_DIR}/scripts/env/use-backend-env.sh" "${TARGET}" "${CUSTOM_ENV_FILE}"
fi

cd "${ROOT_DIR}/backend"
npm run dev
