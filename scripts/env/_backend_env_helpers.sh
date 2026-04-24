#!/usr/bin/env bash

normalize_backend_target() {
  local target="${1:-}"

  case "${target}" in
    local|dev|prod|test)
      printf '%s\n' "${target}"
      ;;
    "")
      return 1
      ;;
    *)
      return 1
      ;;
  esac
}

backend_env_example_file() {
  local root_dir="${1:?root_dir mancante}"
  local target="${2:?target mancante}"

  printf '%s/config/environments/backend/%s.env.example\n' "${root_dir}" "${target}"
}

backend_env_local_file() {
  local root_dir="${1:?root_dir mancante}"
  local target="${2:?target mancante}"

  printf '%s/config/environments/backend/%s.env.local\n' "${root_dir}" "${target}"
}
