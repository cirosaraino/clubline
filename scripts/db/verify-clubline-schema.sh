#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET="${1:-}"
CUSTOM_ENV_FILE="${2:-}"

if [[ -z "${TARGET}" ]]; then
  echo "Uso: ./scripts/db/verify-clubline-schema.sh <dev|test|prod> [percorso-file-env]"
  exit 1
fi

case "${TARGET}" in
  dev|test|prod) ;;
  *)
    echo "Target non valido: ${TARGET}. Usa dev, test oppure prod."
    exit 1
    ;;
esac

ENV_FILE="${CUSTOM_ENV_FILE:-${ROOT_DIR}/backend/.env.clubline-${TARGET}.local}"
if [[ ! -f "${ENV_FILE}" ]]; then
  echo "File env non trovato: ${ENV_FILE}"
  exit 1
fi

if ! command -v psql >/dev/null 2>&1; then
  echo "psql non trovato. Installa il client PostgreSQL prima di usare questo script."
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

if [[ -z "${SUPABASE_DB_URL:-}" ]]; then
  echo "SUPABASE_DB_URL non impostata in ${ENV_FILE}"
  exit 1
fi

echo "Verifica schema Clubline su target ${TARGET}..."
psql "${SUPABASE_DB_URL}" -v ON_ERROR_STOP=1 <<'SQL'
\pset tuples_only on
\pset format unaligned

select 'clubs=' || coalesce(to_regclass('public.clubs')::text, 'missing');
select 'memberships=' || coalesce(to_regclass('public.memberships')::text, 'missing');
select 'player_profiles=' || coalesce(to_regclass('public.player_profiles')::text, 'missing');
select 'join_requests=' || coalesce(to_regclass('public.join_requests')::text, 'missing');
select 'leave_requests=' || coalesce(to_regclass('public.leave_requests')::text, 'missing');
select 'club_settings=' || coalesce(to_regclass('public.club_settings')::text, 'missing');
select 'club_permission_settings=' || coalesce(to_regclass('public.club_permission_settings')::text, 'missing');
select 'player_profiles_active_console_unique=' || exists(
  select 1
  from pg_indexes
  where schemaname = 'public'
    and indexname = 'player_profiles_active_console_unique'
)::text;
select 'player_profiles_membership_requires_club_check=' || exists(
  select 1
  from pg_constraint
  where conname = 'player_profiles_membership_requires_club_check'
)::text;
select 'player_profiles_standalone_team_role_check=' || exists(
  select 1
  from pg_constraint
  where conname = 'player_profiles_standalone_team_role_check'
)::text;
select 'club_assets_bucket=' || exists(select 1 from storage.buckets where id = 'club-assets')::text;
select 'service_role_clubs_rw=' || has_table_privilege('service_role', 'public.clubs', 'select,insert,update,delete')::text;
select 'service_role_memberships_rw=' || has_table_privilege('service_role', 'public.memberships', 'select,insert,update,delete')::text;
select 'service_role_player_profiles_rw=' || has_table_privilege('service_role', 'public.player_profiles', 'select,insert,update,delete')::text;
select 'service_role_join_requests_rw=' || has_table_privilege('service_role', 'public.join_requests', 'select,insert,update,delete')::text;
select 'service_role_leave_requests_rw=' || has_table_privilege('service_role', 'public.leave_requests', 'select,insert,update,delete')::text;
SQL

echo "Verifica completata per ${TARGET}."
