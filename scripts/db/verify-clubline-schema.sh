#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET="${1:-}"
CUSTOM_ENV_FILE="${2:-}"

# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/env/_backend_env_helpers.sh"

if [[ -z "${TARGET}" ]]; then
  echo "Uso: ./scripts/db/verify-clubline-schema.sh <local|dev|prod|test> [percorso-file-env]"
  exit 1
fi

if ! TARGET="$(normalize_backend_target "${TARGET}")"; then
  echo "Target non valido: ${TARGET}. Usa local, dev, prod oppure test."
  exit 1
fi

ENV_FILE="${CUSTOM_ENV_FILE:-$(backend_env_local_file "${ROOT_DIR}" "${TARGET}")}"
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
select 'club_membership_events=' || coalesce(to_regclass('public.club_membership_events')::text, 'missing');
select 'stream_links=' || coalesce(to_regclass('public.stream_links')::text, 'missing');
select 'lineups=' || coalesce(to_regclass('public.lineups')::text, 'missing');
select 'lineup_players=' || coalesce(to_regclass('public.lineup_players')::text, 'missing');
select 'attendance_weeks=' || coalesce(to_regclass('public.attendance_weeks')::text, 'missing');
select 'attendance_entries=' || coalesce(to_regclass('public.attendance_entries')::text, 'missing');
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
select 'detach_player_identity_preserves_profile_fields=' || (
  pg_get_functiondef('public.detach_player_identity_from_membership()'::regprocedure)
    not like '%shirt_number = null%'
  and pg_get_functiondef('public.detach_player_identity_from_membership()'::regprocedure)
    not like '%primary_role = null%'
  and pg_get_functiondef('public.detach_player_identity_from_membership()'::regprocedure)
    not like '%secondary_roles = ''{}''::text[]%'
)::text;
select 'memberships_user_status_created_idx=' || exists(
  select 1
  from pg_indexes
  where schemaname = 'public'
    and indexname = 'memberships_user_status_created_idx'
)::text;
select 'join_requests_pending_club_created_idx=' || exists(
  select 1
  from pg_indexes
  where schemaname = 'public'
    and indexname = 'join_requests_pending_club_created_idx'
)::text;
select 'leave_requests_pending_club_created_idx=' || exists(
  select 1
  from pg_indexes
  where schemaname = 'public'
    and indexname = 'leave_requests_pending_club_created_idx'
)::text;
select 'clubs_normalized_name_prefix_idx=' || exists(
  select 1
  from pg_indexes
  where schemaname = 'public'
    and indexname = 'clubs_normalized_name_prefix_idx'
)::text;
select 'clubs_slug_prefix_idx=' || exists(
  select 1
  from pg_indexes
  where schemaname = 'public'
    and indexname = 'clubs_slug_prefix_idx'
)::text;
select 'lineup_players_has_club_id=' || exists(
  select 1
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'lineup_players'
    and column_name = 'club_id'
)::text;
select 'lineup_players_club_lineup_idx=' || exists(
  select 1
  from pg_indexes
  where schemaname = 'public'
    and indexname = 'lineup_players_club_lineup_idx'
)::text;
select 'clubs_rls_enabled=' || coalesce((
  select relrowsecurity::text
  from pg_class
  where oid = 'public.clubs'::regclass
), 'false');
select 'memberships_rls_enabled=' || coalesce((
  select relrowsecurity::text
  from pg_class
  where oid = 'public.memberships'::regclass
), 'false');
select 'join_requests_rls_enabled=' || coalesce((
  select relrowsecurity::text
  from pg_class
  where oid = 'public.join_requests'::regclass
), 'false');
select 'leave_requests_rls_enabled=' || coalesce((
  select relrowsecurity::text
  from pg_class
  where oid = 'public.leave_requests'::regclass
), 'false');
select 'stream_links_rls_enabled=' || coalesce((
  select relrowsecurity::text
  from pg_class
  where oid = 'public.stream_links'::regclass
), 'false');
select 'lineups_rls_enabled=' || coalesce((
  select relrowsecurity::text
  from pg_class
  where oid = 'public.lineups'::regclass
), 'false');
select 'lineup_players_rls_enabled=' || coalesce((
  select relrowsecurity::text
  from pg_class
  where oid = 'public.lineup_players'::regclass
), 'false');
select 'attendance_weeks_rls_enabled=' || coalesce((
  select relrowsecurity::text
  from pg_class
  where oid = 'public.attendance_weeks'::regclass
), 'false');
select 'attendance_entries_rls_enabled=' || coalesce((
  select relrowsecurity::text
  from pg_class
  where oid = 'public.attendance_entries'::regclass
), 'false');
select 'clubs_select_member_or_requester_policy=' || exists(
  select 1 from pg_policies
  where schemaname = 'public'
    and tablename = 'clubs'
    and policyname = 'clubs_select_member_or_requester'
)::text;
select 'join_requests_select_own_or_captain_policy=' || exists(
  select 1 from pg_policies
  where schemaname = 'public'
    and tablename = 'join_requests'
    and policyname = 'join_requests_select_own_or_captain'
)::text;
select 'leave_requests_select_own_or_captain_policy=' || exists(
  select 1 from pg_policies
  where schemaname = 'public'
    and tablename = 'leave_requests'
    and policyname = 'leave_requests_select_own_or_captain'
)::text;
select 'stream_links_select_member_policy=' || exists(
  select 1 from pg_policies
  where schemaname = 'public'
    and tablename = 'stream_links'
    and policyname = 'stream_links_select_member'
)::text;
select 'lineup_players_select_member_policy=' || exists(
  select 1 from pg_policies
  where schemaname = 'public'
    and tablename = 'lineup_players'
    and policyname = 'lineup_players_select_member'
)::text;
select 'attendance_entries_select_member_or_manager_policy=' || exists(
  select 1 from pg_policies
  where schemaname = 'public'
    and tablename = 'attendance_entries'
    and policyname = 'attendance_entries_select_member_or_manager'
)::text;
select 'legacy_stream_links_dev_policies_absent=' || not exists(
  select 1 from pg_policies
  where schemaname = 'public'
    and tablename = 'stream_links'
    and policyname in (
      'stream_links_select_dev',
      'stream_links_insert_dev',
      'stream_links_update_dev',
      'stream_links_delete_dev'
    )
)::text;
select 'legacy_lineups_dev_policies_absent=' || not exists(
  select 1 from pg_policies
  where schemaname = 'public'
    and tablename = 'lineups'
    and policyname in (
      'lineups_select_dev',
      'lineups_insert_dev',
      'lineups_update_dev',
      'lineups_delete_dev'
    )
)::text;
select 'legacy_lineup_players_dev_policies_absent=' || not exists(
  select 1 from pg_policies
  where schemaname = 'public'
    and tablename = 'lineup_players'
    and policyname in (
      'lineup_players_select_dev',
      'lineup_players_insert_dev',
      'lineup_players_update_dev',
      'lineup_players_delete_dev'
    )
)::text;
select 'legacy_attendance_weeks_dev_policies_absent=' || not exists(
  select 1 from pg_policies
  where schemaname = 'public'
    and tablename = 'attendance_weeks'
    and policyname in (
      'attendance_weeks_select_dev',
      'attendance_weeks_insert_dev',
      'attendance_weeks_update_dev',
      'attendance_weeks_delete_dev'
    )
)::text;
select 'legacy_attendance_entries_dev_policies_absent=' || not exists(
  select 1 from pg_policies
  where schemaname = 'public'
    and tablename = 'attendance_entries'
    and policyname in (
      'attendance_entries_select_dev',
      'attendance_entries_insert_dev',
      'attendance_entries_update_dev',
      'attendance_entries_delete_dev'
    )
)::text;
select 'legacy_team_settings_dev_policies_absent=' || not exists(
  select 1 from pg_policies
  where schemaname = 'public'
    and tablename = 'team_settings'
    and policyname in (
      'team_settings_select_dev',
      'team_settings_insert_dev',
      'team_settings_update_dev',
      'team_settings_delete_dev'
    )
)::text;
select 'legacy_team_permission_settings_dev_policies_absent=' || not exists(
  select 1 from pg_policies
  where schemaname = 'public'
    and tablename = 'team_permission_settings'
    and policyname in (
      'team_permission_settings_select_dev',
      'team_permission_settings_insert_dev',
      'team_permission_settings_update_dev',
      'team_permission_settings_delete_dev'
    )
)::text;
select 'clubline_create_club_function=' || exists(
  select 1
  from pg_proc
  where proname = 'clubline_create_club'
)::text;
select 'clubline_approve_join_request_function=' || exists(
  select 1
  from pg_proc
  where proname = 'clubline_approve_join_request'
)::text;
select 'service_role_create_club_execute=' || has_function_privilege(
  'service_role',
  'public.clubline_create_club(uuid,text,text,text,text,text,integer,text,text,text,text)',
  'execute'
)::text;
select 'club_assets_bucket=' || exists(select 1 from storage.buckets where id = 'club-assets')::text;
select 'service_role_clubs_rw=' || has_table_privilege('service_role', 'public.clubs', 'select,insert,update,delete')::text;
select 'service_role_memberships_rw=' || has_table_privilege('service_role', 'public.memberships', 'select,insert,update,delete')::text;
select 'service_role_player_profiles_rw=' || has_table_privilege('service_role', 'public.player_profiles', 'select,insert,update,delete')::text;
select 'service_role_join_requests_rw=' || has_table_privilege('service_role', 'public.join_requests', 'select,insert,update,delete')::text;
select 'service_role_leave_requests_rw=' || has_table_privilege('service_role', 'public.leave_requests', 'select,insert,update,delete')::text;
select 'service_role_club_membership_events_rw=' || has_table_privilege('service_role', 'public.club_membership_events', 'select,insert,update,delete')::text;
select 'authenticated_stream_links_select=' || has_table_privilege('authenticated', 'public.stream_links', 'select')::text;
select 'authenticated_lineups_select=' || has_table_privilege('authenticated', 'public.lineups', 'select')::text;
select 'authenticated_lineup_players_select=' || has_table_privilege('authenticated', 'public.lineup_players', 'select')::text;
select 'authenticated_attendance_weeks_select=' || has_table_privilege('authenticated', 'public.attendance_weeks', 'select')::text;
select 'authenticated_attendance_entries_select=' || has_table_privilege('authenticated', 'public.attendance_entries', 'select')::text;
select 'supabase_realtime_stream_links=' || exists(
  select 1
  from pg_publication_tables
  where pubname = 'supabase_realtime'
    and schemaname = 'public'
    and tablename = 'stream_links'
)::text;
select 'supabase_realtime_lineups=' || exists(
  select 1
  from pg_publication_tables
  where pubname = 'supabase_realtime'
    and schemaname = 'public'
    and tablename = 'lineups'
)::text;
select 'supabase_realtime_lineup_players=' || exists(
  select 1
  from pg_publication_tables
  where pubname = 'supabase_realtime'
    and schemaname = 'public'
    and tablename = 'lineup_players'
)::text;
select 'supabase_realtime_attendance_weeks=' || exists(
  select 1
  from pg_publication_tables
  where pubname = 'supabase_realtime'
    and schemaname = 'public'
    and tablename = 'attendance_weeks'
)::text;
select 'supabase_realtime_attendance_entries=' || exists(
  select 1
  from pg_publication_tables
  where pubname = 'supabase_realtime'
    and schemaname = 'public'
    and tablename = 'attendance_entries'
)::text;
SQL

echo "Verifica completata per ${TARGET}."
