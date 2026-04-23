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

grant execute on function public.restore_attendance_week(bigint)
  to anon, authenticated;
