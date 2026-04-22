-- Clubline player membership guardrails
-- Run this after:
-- - sql/production_schema.sql
-- - sql/clubline_multi_club_refactor.sql
-- - sql/clubline_player_identity_refactor.sql

begin;

create or replace function public.detach_player_identity_from_membership()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  update public.player_profiles
  set club_id = null,
      membership_id = null,
      team_role = 'player'
  where membership_id = old.id
    and archived_at is null;

  if tg_op = 'DELETE' then
    return old;
  end if;

  return new;
end;
$$;

alter table public.player_profiles
  drop constraint if exists player_profiles_membership_requires_club_check;

alter table public.player_profiles
  add constraint player_profiles_membership_requires_club_check
  check (membership_id is null or club_id is not null);

alter table public.player_profiles
  drop constraint if exists player_profiles_standalone_team_role_check;

alter table public.player_profiles
  add constraint player_profiles_standalone_team_role_check
  check (membership_id is not null or team_role = 'player');

create index if not exists player_profiles_active_standalone_auth_idx
  on public.player_profiles (auth_user_id)
  where club_id is null
    and membership_id is null
    and archived_at is null
    and auth_user_id is not null;

commit;
