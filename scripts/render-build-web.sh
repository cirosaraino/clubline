#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FLUTTER_DIR="${ROOT_DIR}/.render/flutter"

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

if [[ -z "${API_BASE_URL:-}" ]]; then
  echo "Variabile API_BASE_URL mancante."
  exit 1
fi

export PATH="$(dirname "${FLUTTER}"):${PATH}"

cd "${ROOT_DIR}"

"${FLUTTER}" config --enable-web
"${FLUTTER}" pub get
"${FLUTTER}" build web --release --dart-define=API_BASE_URL="${API_BASE_URL}"
