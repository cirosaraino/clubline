-- Verify player identity refactor

select
  column_name,
  is_nullable
from information_schema.columns
where table_schema = 'public'
  and table_name = 'player_profiles'
  and column_name in ('club_id', 'membership_id');

select
  conname as constraint_name,
  pg_get_constraintdef(oid) as definition
from pg_constraint
where conrelid = 'public.player_profiles'::regclass
  and conname = 'player_profiles_club_id_fkey';

select
  indexname,
  indexdef
from pg_indexes
where schemaname = 'public'
  and tablename = 'player_profiles'
  and indexname in (
    'player_profiles_active_console_unique',
    'player_profiles_active_auth_user_id_unique',
    'player_profiles_active_account_email_unique',
    'player_profiles_active_membership_unique'
  );

select
  trigger_name,
  event_manipulation,
  action_timing
from information_schema.triggers
where event_object_schema = 'public'
  and event_object_table = 'memberships'
  and trigger_name in (
    'memberships_detach_player_profiles_on_left',
    'memberships_detach_player_profiles_on_delete'
  )
order by trigger_name, event_manipulation;
