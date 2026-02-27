-- =============================================================================
-- ROW LEVEL SECURITY
-- Must be applied after all tables and functions are created.
-- =============================================================================

-- Enable RLS on all tables
ALTER TABLE public.jobs        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.api_keys    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rate_limits ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- JOBS: Public read-only access for anonymous users
-- All writes must go through the submit-job Edge Function (service role)
-- =============================================================================

-- Anyone (anon, authenticated) can read active jobs
CREATE POLICY "jobs_public_select"
  ON public.jobs
  FOR SELECT
  USING (is_active = TRUE);

-- No direct inserts/updates/deletes from anon or authenticated roles
-- (The Edge Function uses the service role key which bypasses RLS)

-- =============================================================================
-- API_KEYS: Service role only — anon has no access
-- =============================================================================

CREATE POLICY "api_keys_deny_all"
  ON public.api_keys
  FOR ALL
  USING (FALSE);

-- =============================================================================
-- RATE_LIMITS: Service role only — anon has no access
-- =============================================================================

CREATE POLICY "rate_limits_deny_all"
  ON public.rate_limits
  FOR ALL
  USING (FALSE);

-- =============================================================================
-- GRANTS
-- PostgREST needs explicit GRANT to expose tables/functions to anon role
-- =============================================================================

-- Read access to jobs for all API consumers
GRANT SELECT ON public.jobs TO anon;
GRANT SELECT ON public.jobs TO authenticated;

-- RPC access for search functions
GRANT EXECUTE ON FUNCTION public.search_jobs TO anon;
GRANT EXECUTE ON FUNCTION public.search_jobs TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_job_detail TO anon;
GRANT EXECUTE ON FUNCTION public.get_job_detail TO authenticated;
