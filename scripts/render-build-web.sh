#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FLUTTER_DIR="${ROOT_DIR}/.render/flutter"
APP_ENV="${APP_ENV:-prod}"
ENV_FILE="${CLUBLINE_FLUTTER_ENV_FILE:-${ROOT_DIR}/config/environments/flutter/${APP_ENV}.json}"

if [[ -n "${FLUTTER_BIN:-}" ]]; then
  FLUTTER="${FLUTTER_BIN}"
elif [[ -x "${FLUTTER_DIR}/bin/flutter" ]]; then
  FLUTTER="${FLUTTER_DIR}/bin/flutter"
else
  echo "Flutter non trovato. Scarico il canale stable in ${FLUTTER_DIR}..."
  rm -rf "${FLUTTER_DIR}"
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable "${FLUTTER_DIR}"
  FLUTTER="${FLUTTER_DIR}/bin/flutter"
fi

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "File di configurazione Flutter non trovato: ${ENV_FILE}"
  exit 1
fi

export PATH="$(dirname "${FLUTTER}"):${PATH}"

cd "${ROOT_DIR}"

"${FLUTTER}" config --enable-web
"${FLUTTER}" pub get
BUILD_COMMAND=(
  "${FLUTTER}"
  build
  web
  --release
  "--dart-define-from-file=${ENV_FILE}"
)

if [[ -n "${API_BASE_URL:-}" ]]; then
  BUILD_COMMAND+=("--dart-define=API_BASE_URL=${API_BASE_URL}")
fi

if [[ -n "${REALTIME_TRANSPORT:-}" ]]; then
  BUILD_COMMAND+=("--dart-define=REALTIME_TRANSPORT=${REALTIME_TRANSPORT}")
fi

if [[ -n "${APP_ENV:-}" ]]; then
  BUILD_COMMAND+=("--dart-define=APP_ENV=${APP_ENV}")
fi

"${BUILD_COMMAND[@]}"
