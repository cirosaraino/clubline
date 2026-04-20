grant usage on schema public to service_role;

grant select, insert, update, delete
  on table public.player_profiles,
           public.team_settings,
           public.team_permission_settings,
           public.stream_links,
           public.lineups,
           public.lineup_players,
           public.attendance_weeks,
           public.attendance_entries,
           public.clubs,
           public.club_settings,
           public.club_permission_settings,
           public.memberships,
           public.join_requests,
           public.leave_requests
  to service_role;

grant usage, select on all sequences in schema public
  to service_role;

revoke all
  on table public.player_profiles,
           public.team_settings,
           public.team_permission_settings,
           public.stream_links,
           public.lineups,
           public.lineup_players,
           public.attendance_weeks,
           public.attendance_entries,
           public.clubs,
           public.club_settings,
           public.club_permission_settings,
           public.memberships,
           public.join_requests,
           public.leave_requests
  from anon, authenticated;
