alter table if exists public.player_profiles
  add column if not exists secondary_roles text[] not null default '{}'::text[];

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'player_profiles'
      and column_name = 'secondary_role'
  ) then
    update public.player_profiles
    set secondary_roles = case
      when secondary_role is null or btrim(secondary_role) = '' then '{}'::text[]
      when secondary_role = primary_role then '{}'::text[]
      else array[secondary_role]
    end
    where secondary_roles = '{}'::text[];
  end if;
end $$;

alter table public.player_profiles
  drop constraint if exists player_profiles_secondary_roles_check;

alter table public.player_profiles
  add constraint player_profiles_secondary_roles_check
  check (
    secondary_roles <@ array[
      'POR',
      'TS',
      'DC',
      'TD',
      'CDC',
      'CC',
      'COC',
      'ES',
      'ED',
      'AS',
      'AD',
      'ATT'
    ]::text[]
  );
