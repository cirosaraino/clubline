#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REMOTE_API_BASE_URL="${API_BASE_URL:-}"

if [[ -z "${REMOTE_API_BASE_URL}" ]]; then
  echo "Specifica API_BASE_URL verso il backend remoto beta/dev."
  echo "Esempio:"
  echo "  API_BASE_URL=https://clubline-backend-dev.onrender.com/api ./scripts/flutter/build-web-beta.sh"
  exit 1
fi

case "${REMOTE_API_BASE_URL}" in
  http://localhost:*|http://127.0.0.1:*|http://0.0.0.0:*|https://localhost:*|https://127.0.0.1:*|https://0.0.0.0:*)
    echo "API_BASE_URL deve puntare a un backend remoto per il beta web, non a un host locale: ${REMOTE_API_BASE_URL}"
    exit 1
    ;;
esac

export API_BASE_URL="${REMOTE_API_BASE_URL}"
export APP_ENV=dev
export REALTIME_TRANSPORT=supabase

exec "${ROOT_DIR}/scripts/flutter/_flutter_with_environment.sh" \
  dev \
  build \
  web \
  --release
