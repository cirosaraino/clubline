create table if not exists team_settings (
  id integer primary key default 1,
  team_name text not null default 'Ultras Mentality',
  crest_url text,
  website_url text,
  youtube_url text,
  discord_url text,
  facebook_url text,
  instagram_url text,
  twitch_url text,
  tiktok_url text,
  additional_links jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default timezone('utc', now()),
  constraint team_settings_singleton_check check (id = 1),
  constraint team_settings_additional_links_is_array_check
    check (jsonb_typeof(additional_links) = 'array')
);

insert into team_settings (
  id,
  team_name
)
values (1, 'Ultras Mentality')
on conflict (id) do nothing;

create or replace function touch_team_settings_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists team_settings_touch_updated_at on team_settings;

create trigger team_settings_touch_updated_at
before update on team_settings
for each row
execute function touch_team_settings_updated_at();

alter table public.team_settings enable row level security;

drop policy if exists team_settings_select_dev on public.team_settings;
drop policy if exists team_settings_insert_dev on public.team_settings;
drop policy if exists team_settings_update_dev on public.team_settings;
drop policy if exists team_settings_delete_dev on public.team_settings;

create policy team_settings_select_dev
  on public.team_settings
  for select
  using (true);

create policy team_settings_insert_dev
  on public.team_settings
  for insert
  with check (true);

create policy team_settings_update_dev
  on public.team_settings
  for update
  using (true)
  with check (true);

create policy team_settings_delete_dev
  on public.team_settings
  for delete
  using (true);
