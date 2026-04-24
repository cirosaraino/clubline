#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

exec "${ROOT_DIR}/scripts/flutter/_flutter_with_environment.sh" \
  local \
  run \
  -d \
  chrome
