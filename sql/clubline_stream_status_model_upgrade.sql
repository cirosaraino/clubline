alter table public.stream_links
  alter column stream_status set default 'unknown';

update public.stream_links
set stream_status = 'unknown'
where stream_status is null
   or btrim(stream_status) = '';

alter table public.stream_links
  drop constraint if exists stream_links_status_check;

alter table public.stream_links
  add constraint stream_links_status_check
    check (stream_status in ('live', 'scheduled', 'ended', 'unknown'));
