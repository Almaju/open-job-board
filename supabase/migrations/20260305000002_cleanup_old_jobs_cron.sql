-- =============================================================================
-- DAILY CLEANUP CRON JOB
-- Schedules a daily invocation of the cleanup-old-jobs edge function to
-- delete job offers older than 7 days.
-- Uses pg_cron + pg_net to make an HTTP POST to the edge function.
-- =============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog;
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

-- Schedule: every day at 03:00 UTC
SELECT cron.schedule(
  'cleanup-old-jobs',
  '0 3 * * *',
  $$
  SELECT net.http_post(
    url    := current_setting('app.settings.supabase_url') || '/functions/v1/cleanup-old-jobs',
    body   := '{}'::jsonb,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key')
    )
  ) AS request_id;
  $$
);
