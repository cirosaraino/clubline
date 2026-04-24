#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET="${1:-local}"
CUSTOM_ENV_FILE="${2:-}"

"${ROOT_DIR}/scripts/db/apply-clubline-schema.sh" "${TARGET}" "${CUSTOM_ENV_FILE}"
