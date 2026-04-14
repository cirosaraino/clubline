alter table if exists public.player_profiles
  add column if not exists auth_user_id uuid;

alter table if exists public.player_profiles
  add column if not exists account_email text;

update public.player_profiles
set account_email = lower(trim(account_email))
where account_email is not null;

alter table public.player_profiles
  drop constraint if exists player_profiles_account_email_check;

alter table public.player_profiles
  add constraint player_profiles_account_email_check
  check (
    account_email is null
    or (
      trim(account_email) <> ''
      and position('@' in account_email) > 1
    )
  );

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'player_profiles_auth_user_id_fkey'
      and conrelid = 'public.player_profiles'::regclass
  ) then
    alter table public.player_profiles
      add constraint player_profiles_auth_user_id_fkey
      foreign key (auth_user_id)
      references auth.users(id)
      on delete set null;
  end if;
end $$;

create unique index if not exists player_profiles_auth_user_id_unique
  on public.player_profiles(auth_user_id)
  where auth_user_id is not null;

create unique index if not exists player_profiles_account_email_unique
  on public.player_profiles(lower(account_email))
  where account_email is not null;

create or replace function public.can_bootstrap_captain()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select not exists (
    select 1
    from public.player_profiles
    where auth_user_id is not null
  );
$$;

create or replace function public.current_user_can_manage_players()
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  current_role text;
  vice_manage_players_enabled boolean := false;
begin
  if auth.uid() is null then
    return false;
  end if;

  select player.team_role
    into current_role
  from public.player_profiles as player
  where player.auth_user_id = auth.uid()
  order by player.id
  limit 1;

  if current_role = 'captain' then
    return true;
  end if;

  if current_role <> 'vice_captain' then
    return false;
  end if;

  begin
    select coalesce(settings.vice_manage_players, false)
      into vice_manage_players_enabled
    from public.team_permission_settings as settings
    where settings.id = 1;
  exception
    when undefined_table then
      vice_manage_players_enabled := false;
  end;

  return coalesce(vice_manage_players_enabled, false);
end;
$$;

grant execute on function public.can_bootstrap_captain() to authenticated;
grant execute on function public.current_user_can_manage_players() to authenticated;

create or replace function public.apply_player_profile_auth_defaults()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  jwt_email text;
begin
  jwt_email := nullif(lower(trim(coalesce(auth.jwt() ->> 'email', ''))), '');

  if tg_op = 'INSERT' then
    if public.current_user_can_manage_players() then
      new.account_email := nullif(lower(trim(coalesce(new.account_email, ''))), '');
      return new;
    end if;

    if auth.uid() is null then
      raise exception 'Autenticazione richiesta per creare un profilo squadra';
    end if;

    new.auth_user_id := auth.uid();
    new.account_email := coalesce(
      nullif(lower(trim(coalesce(new.account_email, ''))), ''),
      jwt_email
    );
    new.team_role := case
      when public.can_bootstrap_captain() then 'captain'
      else 'player'
    end;

    return new;
  end if;

  if tg_op = 'UPDATE' then
    if public.current_user_can_manage_players() then
      new.account_email := nullif(lower(trim(coalesce(new.account_email, ''))), '');
      return new;
    end if;

    if auth.uid() is null then
      raise exception 'Autenticazione richiesta per completare il profilo squadra';
    end if;

    if old.auth_user_id is null
       and nullif(lower(trim(coalesce(old.account_email, ''))), '') is null then
      new.auth_user_id := auth.uid();
      new.account_email := coalesce(
        nullif(lower(trim(coalesce(new.account_email, ''))), ''),
        jwt_email
      );
      new.team_role := case
        when public.can_bootstrap_captain() then 'captain'
        else old.team_role
      end;
      return new;
    end if;

    if old.auth_user_id is distinct from auth.uid() then
      raise exception 'Non puoi modificare questo profilo squadra';
    end if;

    new.auth_user_id := old.auth_user_id;
    new.account_email := coalesce(old.account_email, jwt_email);
    new.team_role := old.team_role;
    return new;
  end if;

  return new;
end;
$$;

drop trigger if exists player_profiles_apply_auth_defaults on public.player_profiles;

create trigger player_profiles_apply_auth_defaults
before insert or update on public.player_profiles
for each row
execute function public.apply_player_profile_auth_defaults();

alter table public.player_profiles enable row level security;

drop policy if exists player_profiles_select_authenticated on public.player_profiles;
drop policy if exists player_profiles_insert_authenticated on public.player_profiles;
drop policy if exists player_profiles_update_authenticated on public.player_profiles;
drop policy if exists player_profiles_delete_authenticated on public.player_profiles;

create policy player_profiles_select_authenticated
  on public.player_profiles
  for select
  using (true);

create policy player_profiles_insert_authenticated
  on public.player_profiles
  for insert
  to authenticated
  with check (
    auth.uid() is not null
    and (
      public.current_user_can_manage_players()
      or auth_user_id = auth.uid()
    )
  );

create policy player_profiles_update_authenticated
  on public.player_profiles
  for update
  to authenticated
  using (
    public.current_user_can_manage_players()
    or auth_user_id = auth.uid()
    or (
      auth.uid() is not null
      and auth_user_id is null
      and nullif(lower(trim(coalesce(account_email, ''))), '') is null
    )
  )
  with check (
    public.current_user_can_manage_players()
    or auth_user_id = auth.uid()
  );

create policy player_profiles_delete_authenticated
  on public.player_profiles
  for delete
  to authenticated
  using (public.current_user_can_manage_players());
