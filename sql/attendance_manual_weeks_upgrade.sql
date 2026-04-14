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

alter table public.attendance_weeks
  add column if not exists selected_dates date[];

alter table public.attendance_weeks
  add column if not exists archived_at timestamptz;

create or replace function public.attendance_calendar_week_start(
  reference_date date
)
returns date
language sql
immutable
as $$
  select reference_date - (extract(isodow from reference_date)::int - 1);
$$;

update public.attendance_weeks as week
set selected_dates = coalesce(
  (
    select array_agg(distinct entry.attendance_date order by entry.attendance_date)
    from public.attendance_entries as entry
    where entry.week_id = week.id
  ),
  array[week.week_start]
)
where week.selected_dates is null
   or coalesce(cardinality(week.selected_dates), 0) = 0;

alter table public.attendance_weeks
  drop constraint if exists attendance_weeks_week_bounds_check;

with ordered_weeks as (
  select
    id,
    row_number() over (order by week_start desc, id desc) as sort_order
  from public.attendance_weeks
)
update public.attendance_weeks as week
set archived_at = coalesce(week.archived_at, week.created_at, timezone('utc', now()))
from ordered_weeks
where ordered_weeks.id = week.id
  and ordered_weeks.sort_order > 1
  and week.archived_at is null;

update public.attendance_weeks
set
  week_start = public.attendance_calendar_week_start(week_start),
  week_end = public.attendance_calendar_week_start(week_start) + 6
where week_start <> public.attendance_calendar_week_start(week_start)
   or week_end <> public.attendance_calendar_week_start(week_start) + 6;

alter table public.attendance_weeks
  alter column selected_dates set not null;

alter table public.attendance_weeks
  add constraint attendance_weeks_week_bounds_check
  check (week_end = week_start + 6);

alter table public.attendance_weeks
  drop constraint if exists attendance_weeks_selected_dates_check;

alter table public.attendance_weeks
  add constraint attendance_weeks_selected_dates_check
  check (cardinality(selected_dates) > 0);

create index if not exists attendance_weeks_archived_at_idx
  on public.attendance_weeks (archived_at);

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
    selected_day.attendance_date,
    'pending'
  from public.player_profiles as player
  join public.attendance_weeks as week
    on week.id = target_week_id
  cross join unnest(week.selected_dates) as selected_day(attendance_date)
  left join public.attendance_entries as entry
    on entry.week_id = target_week_id
   and entry.player_id = player.id
   and entry.attendance_date = selected_day.attendance_date
  where entry.id is null;
$$;

create or replace function public.create_attendance_week(
  reference_date date,
  selected_dates date[]
)
returns bigint
language plpgsql
as $$
declare
  target_week_start date;
  target_week_end date;
  normalized_dates date[];
  target_week_id bigint;
begin
  if reference_date is null then
    raise exception 'Specifica una data valida per la settimana presenze';
  end if;

  target_week_start := public.attendance_calendar_week_start(reference_date);
  target_week_end := target_week_start + 6;

  select array_agg(distinct selected_date order by selected_date)
    into normalized_dates
  from unnest(selected_dates) as selected_date
  where selected_date between target_week_start and target_week_end;

  if normalized_dates is null or cardinality(normalized_dates) = 0 then
    raise exception 'Seleziona almeno un giorno valido per la settimana scelta';
  end if;

  if exists (
    select 1
    from unnest(selected_dates) as selected_date
    where selected_date < target_week_start
       or selected_date > target_week_end
  ) then
    raise exception 'Tutti i giorni selezionati devono appartenere alla stessa settimana';
  end if;

  if exists (
    select 1
    from public.attendance_weeks
    where archived_at is null
  ) then
    raise exception 'Archivia prima la settimana presenze attiva';
  end if;

  insert into public.attendance_weeks (
    week_start,
    week_end,
    selected_dates
  )
  values (
    target_week_start,
    target_week_end,
    normalized_dates
  )
  returning id into target_week_id;

  perform public.sync_attendance_entries_for_week(target_week_id);

  return target_week_id;
end;
$$;

create or replace function public.archive_attendance_week(
  target_week_id bigint
)
returns bigint
language plpgsql
as $$
declare
  archived_week_id bigint;
begin
  update public.attendance_weeks
  set archived_at = timezone('utc', now())
  where id = target_week_id
    and archived_at is null
  returning id into archived_week_id;

  return archived_week_id;
end;
$$;

create or replace function public.restore_attendance_week(
  target_week_id bigint
)
returns bigint
language plpgsql
as $$
declare
  restored_week_id bigint;
begin
  if exists (
    select 1
    from public.attendance_weeks
    where archived_at is null
      and id <> target_week_id
  ) then
    raise exception 'Esiste gia una settimana presenze attiva';
  end if;

  update public.attendance_weeks
  set archived_at = null
  where id = target_week_id
    and archived_at is not null
  returning id into restored_week_id;

  if restored_week_id is null then
    raise exception 'La settimana selezionata non puo essere ripristinata';
  end if;

  perform public.sync_attendance_entries_for_week(restored_week_id);

  return restored_week_id;
end;
$$;

grant execute on function public.sync_attendance_entries_for_week(bigint)
  to anon, authenticated;

grant execute on function public.create_attendance_week(date, date[])
  to anon, authenticated;

grant execute on function public.archive_attendance_week(bigint)
  to anon, authenticated;

grant execute on function public.restore_attendance_week(bigint)
  to anon, authenticated;

drop function if exists public.ensure_active_attendance_week(timestamptz);
drop function if exists public.attendance_target_week_start(timestamptz);
drop function if exists public.manual_attendance_target_week_start(timestamptz);
drop function if exists public.activate_attendance_week_manually(timestamptz);
