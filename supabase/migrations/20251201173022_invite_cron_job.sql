CREATE OR REPLACE FUNCTION public.delete_expired_kitchen_invites()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  DELETE FROM public.kitchen_invites ki
  WHERE ki.expires_at IS NOT NULL
    AND ki.expires_at < (now() - interval '7 days');
END;
$$;

COMMENT ON FUNCTION public.delete_expired_kitchen_invites IS
  'Deletes rows from public.kitchen_invites where expires_at is more than 7 days in the past. Intended to be run by Supabase Cron.';


create extension if not exists pg_cron with schema pg_catalog;
grant usage on schema cron to postgres;
grant all privileges on all tables in schema cron to postgres;

-- Runs every Sunday at 04:00 UTC
SELECT cron.schedule(
  'cleanup-expired-kitchen-invites',
  '0 4 * * 0',
  $$SELECT public.delete_expired_kitchen_invites();$$
);