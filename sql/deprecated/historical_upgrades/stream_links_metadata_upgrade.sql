alter table public.stream_links
  add column if not exists stream_title text;

update public.stream_links
set stream_title = coalesce(nullif(btrim(stream_title), ''), nullif(btrim(competition_name), ''), stream_url)
where stream_title is null
   or btrim(stream_title) = '';

alter table public.stream_links
  alter column stream_title set not null;

alter table public.stream_links
  alter column competition_name drop not null;

alter table public.stream_links
  add column if not exists stream_status text not null default 'unknown';

alter table public.stream_links
  add column if not exists stream_ended_at timestamptz;

alter table public.stream_links
  add column if not exists provider text;

alter table public.stream_links
  drop constraint if exists stream_links_competition_name_not_blank;

alter table public.stream_links
  drop constraint if exists stream_links_status_check;

alter table public.stream_links
  add constraint stream_links_status_check
    check (stream_status in ('live', 'scheduled', 'ended', 'unknown'));

create index if not exists stream_links_status_idx
  on public.stream_links (stream_status);
