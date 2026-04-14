#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="/app"
BACKEND_DIR="$ROOT_DIR/backend"
BACKEND_SRC_DIR="$BACKEND_DIR/src"
FRONTEND_DART_DIR="$ROOT_DIR/lib"

echo "[verify] Environment: iphone-slowness"
echo "[verify] Backend expected language: TypeScript"
echo "[verify] Backend source path: $BACKEND_SRC_DIR"

PY_COUNT=$(find "$BACKEND_DIR" -type f -name "*.py" | wc -l | tr -d ' ')
TS_COUNT=$(find "$BACKEND_SRC_DIR" -type f -name "*.ts" | wc -l | tr -d ' ')
DART_COUNT=$(find "$FRONTEND_DART_DIR" -type f -name "*.dart" | wc -l | tr -d ' ')

echo "[verify] Python files in /app/backend: $PY_COUNT"
echo "[verify] TypeScript files in /app/backend/src: $TS_COUNT"
echo "[verify] Dart files in /app/lib: $DART_COUNT"

if [[ "$TS_COUNT" -eq 0 ]]; then
  echo "[error] Nessun file TypeScript trovato in $BACKEND_SRC_DIR"
  exit 1
fi

echo "[ok] Configurazione path/language coerente con il codebase."