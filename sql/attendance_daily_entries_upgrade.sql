alter table public.attendance_entries
  add column if not exists attendance_date date;

update public.attendance_entries as entry
set attendance_date = week.week_start
from public.attendance_weeks as week
where week.id = entry.week_id
  and entry.attendance_date is null;

alter table public.attendance_entries
  drop constraint if exists attendance_entries_unique_player_per_week;

alter table public.attendance_entries
  drop constraint if exists attendance_entries_unique_player_per_day;

insert into public.attendance_entries (
  week_id,
  player_id,
  attendance_date,
  availability,
  updated_by_player_id,
  updated_at,
  created_at
)
select
  entry.week_id,
  entry.player_id,
  week.week_start + day_offset.day_index,
  entry.availability,
  entry.updated_by_player_id,
  entry.updated_at,
  entry.created_at
from public.attendance_entries as entry
join public.attendance_weeks as week
  on week.id = entry.week_id
cross join generate_series(1, 3) as day_offset(day_index)
where entry.attendance_date = week.week_start
  and not exists (
    select 1
    from public.attendance_entries as existing
    where existing.week_id = entry.week_id
      and existing.player_id = entry.player_id
      and existing.attendance_date = week.week_start + day_offset.day_index
  );

alter table public.attendance_entries
  alter column attendance_date set not null;

alter table public.attendance_entries
  add constraint attendance_entries_unique_player_per_day
    unique (week_id, player_id, attendance_date);

create index if not exists attendance_entries_attendance_date_idx
  on public.attendance_entries (attendance_date);

create or replace function public.sync_attendance_entries_for_week(
  target_week_id bigint
)
returns void
language sql
as $$
  insert into public.attendance_entries (
    week_id,
    player_id,
    attendance_date,
    availability
  )
  select
    target_week_id,
    player.id,
    week.week_start + day_offset.day_index,
    'pending'
  from public.player_profiles as player
  join public.attendance_weeks as week
    on week.id = target_week_id
  cross join generate_series(0, 3) as day_offset(day_index)
  left join public.attendance_entries as entry
    on entry.week_id = target_week_id
   and entry.player_id = player.id
   and entry.attendance_date = week.week_start + day_offset.day_index
  where entry.id is null;
$$;
