-- Clubline development seed hook.
-- Intentionally kept minimal because auth-backed demo users are project-specific.

begin;

do $$
begin
  raise notice 'Clubline dev seed: no default records inserted.';
end
$$;

commit;
