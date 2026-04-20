#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET="${1:-}"
CUSTOM_SOURCE="${2:-}"

if [[ -z "${TARGET}" ]]; then
  echo "Uso: ./scripts/env/use-backend-env.sh <dev|test|prod> [percorso-file-env]"
  exit 1
fi

case "${TARGET}" in
  dev|test|prod) ;;
  *)
    echo "Target non valido: ${TARGET}. Usa dev, test oppure prod."
    exit 1
    ;;
esac

SOURCE_FILE="${CUSTOM_SOURCE:-${ROOT_DIR}/backend/.env.clubline-${TARGET}.local}"
DEST_FILE="${ROOT_DIR}/backend/.env"
EXAMPLE_FILE="${ROOT_DIR}/backend/.env.clubline-${TARGET}.example"

if [[ ! -f "${SOURCE_FILE}" ]]; then
  echo "File env non trovato: ${SOURCE_FILE}"
  echo "Crea prima il file locale partendo da: ${EXAMPLE_FILE}"
  exit 1
fi

cp "${SOURCE_FILE}" "${DEST_FILE}"
echo "backend/.env aggiornato usando ${SOURCE_FILE}"
