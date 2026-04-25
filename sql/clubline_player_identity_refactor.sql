-- Clubline player identity refactor
-- Goal:
-- 1. allow a player profile to exist without an active club
-- 2. preserve the player profile when a club or membership is removed
-- 3. make ID console unique at app level for active player identities
--
-- Run this after:
-- - sql/production_schema.sql
-- - sql/clubline_multi_club_refactor.sql
-- - sql/clubline_post_refactor_grants.sql

begin;

do $$
begin
  if exists (
    select 1
    from (
      select id_console
      from public.player_profiles
      where archived_at is null
        and id_console is not null
        and btrim(id_console) <> ''
      group by id_console
      having count(*) > 1
    ) as duplicate_console_ids
  ) then
    raise exception
      'Duplicate active id_console values found in public.player_profiles. Resolve them before applying clubline_player_identity_refactor.sql';
  end if;
end
$$;

alter table public.player_profiles
  alter column club_id drop not null;

do $$
declare
  existing_constraint text;
begin
  select conname
    into existing_constraint
  from pg_constraint
  where conrelid = 'public.player_profiles'::regclass
    and contype = 'f'
    and confrelid = 'public.clubs'::regclass
    and conkey = array[
      (
        select attnum
        from pg_attribute
        where attrelid = 'public.player_profiles'::regclass
          and attname = 'club_id'
      )
    ]
  limit 1;

  if existing_constraint is not null then
    execute format(
      'alter table public.player_profiles drop constraint %I',
      existing_constraint
    );
  end if;
end
$$;

alter table public.player_profiles
  add constraint player_profiles_club_id_fkey
  foreign key (club_id)
  references public.clubs(id)
  on delete set null;

drop index if exists player_profiles_club_console_unique;
drop index if exists player_profiles_id_console_unique;

create unique index if not exists player_profiles_active_console_unique
  on public.player_profiles (id_console)
  where id_console is not null
    and btrim(id_console) <> ''
    and archived_at is null;

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

drop trigger if exists memberships_detach_player_profiles_on_left
  on public.memberships;

create trigger memberships_detach_player_profiles_on_left
before update of status on public.memberships
for each row
when (old.status is distinct from new.status and new.status = 'left')
execute function public.detach_player_identity_from_membership();

drop trigger if exists memberships_detach_player_profiles_on_delete
  on public.memberships;

create trigger memberships_detach_player_profiles_on_delete
before delete on public.memberships
for each row
execute function public.detach_player_identity_from_membership();

commit;
