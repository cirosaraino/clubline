create table if not exists team_permission_settings (
  id integer primary key default 1,
  vice_manage_players boolean not null default true,
  vice_manage_lineups boolean not null default true,
  vice_manage_streams boolean not null default true,
  vice_manage_attendance boolean not null default true,
  vice_manage_team_info boolean not null default false,
  updated_at timestamptz not null default timezone('utc', now()),
  constraint team_permission_settings_singleton_check check (id = 1)
);

alter table if exists team_permission_settings
  add column if not exists vice_manage_team_info boolean not null default false;

insert into team_permission_settings (
  id,
  vice_manage_players,
  vice_manage_lineups,
  vice_manage_streams,
  vice_manage_attendance,
  vice_manage_team_info
)
values (1, true, true, true, true, false)
on conflict (id) do nothing;

create or replace function touch_team_permission_settings_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists team_permission_settings_touch_updated_at on team_permission_settings;

create trigger team_permission_settings_touch_updated_at
before update on team_permission_settings
for each row
execute function touch_team_permission_settings_updated_at();

alter table public.team_permission_settings enable row level security;

drop policy if exists team_permission_settings_select_dev on public.team_permission_settings;
drop policy if exists team_permission_settings_insert_dev on public.team_permission_settings;
drop policy if exists team_permission_settings_update_dev on public.team_permission_settings;
drop policy if exists team_permission_settings_delete_dev on public.team_permission_settings;

create policy team_permission_settings_select_dev
  on public.team_permission_settings
  for select
  using (true);

create policy team_permission_settings_insert_dev
  on public.team_permission_settings
  for insert
  with check (true);

create policy team_permission_settings_update_dev
  on public.team_permission_settings
  for update
  using (true)
  with check (true);

create policy team_permission_settings_delete_dev
  on public.team_permission_settings
  for delete
  using (true);
