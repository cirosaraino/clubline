#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET="${1:-}"
CUSTOM_SOURCE="${2:-}"

# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/env/_backend_env_helpers.sh"

if [[ -z "${TARGET}" ]]; then
  echo "Uso: ./scripts/env/use-backend-env.sh <local|dev|prod|test> [percorso-file-env]"
  exit 1
fi

if ! TARGET="$(normalize_backend_target "${TARGET}")"; then
  echo "Target non valido: ${TARGET}. Usa local, dev, prod oppure test."
  exit 1
fi

SOURCE_FILE="${CUSTOM_SOURCE:-$(backend_env_local_file "${ROOT_DIR}" "${TARGET}")}"
DEST_FILE="${ROOT_DIR}/backend/.env"
EXAMPLE_FILE="$(backend_env_example_file "${ROOT_DIR}" "${TARGET}")"

if [[ ! -f "${SOURCE_FILE}" ]]; then
  echo "File env non trovato: ${SOURCE_FILE}"
  echo "Crea prima il file locale partendo da: ${EXAMPLE_FILE}"
  exit 1
fi

cp "${SOURCE_FILE}" "${DEST_FILE}"
echo "backend/.env aggiornato usando ${SOURCE_FILE}"
