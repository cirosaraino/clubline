#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET="${1:-}"
shift || true

if [[ -z "${TARGET}" ]]; then
  echo "Uso: ./scripts/flutter/_flutter_with_environment.sh <local|dev|prod> <flutter args...>"
  exit 1
fi

case "${TARGET}" in
  local|dev|prod) ;;
  *)
    echo "Target Flutter non valido: ${TARGET}. Usa local, dev oppure prod."
    exit 1
    ;;
esac

if [[ $# -eq 0 ]]; then
  echo "Specifica almeno un comando Flutter da eseguire."
  exit 1
fi

ENV_FILE="${CLUBLINE_FLUTTER_ENV_FILE:-${ROOT_DIR}/config/environments/flutter/${TARGET}.json}"
if [[ ! -f "${ENV_FILE}" ]]; then
  echo "File di configurazione Flutter non trovato: ${ENV_FILE}"
  exit 1
fi

if [[ -n "${FLUTTER_BIN:-}" ]]; then
  FLUTTER="${FLUTTER_BIN}"
elif command -v flutter >/dev/null 2>&1; then
  FLUTTER="$(command -v flutter)"
else
  echo "Flutter non trovato. Imposta FLUTTER_BIN oppure aggiungi flutter al PATH."
  exit 1
fi

cd "${ROOT_DIR}"

COMMAND=(
  "${FLUTTER}"
  "$@"
  "--dart-define-from-file=${ENV_FILE}"
)

if [[ -n "${API_BASE_URL:-}" ]]; then
  COMMAND+=("--dart-define=API_BASE_URL=${API_BASE_URL}")
fi

if [[ -n "${REALTIME_TRANSPORT:-}" ]]; then
  COMMAND+=("--dart-define=REALTIME_TRANSPORT=${REALTIME_TRANSPORT}")
fi

if [[ -n "${APP_ENV:-}" ]]; then
  COMMAND+=("--dart-define=APP_ENV=${APP_ENV}")
fi

exec "${COMMAND[@]}"
