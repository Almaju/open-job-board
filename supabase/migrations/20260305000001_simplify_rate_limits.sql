-- =============================================================================
-- SIMPLIFY RATE LIMITS
-- Replace per-minute-bucket rows with a single row per identifier.
-- The counter resets when the window expires — no cleanup needed.
-- =============================================================================

-- Drop old objects
DROP FUNCTION IF EXISTS public.cleanup_rate_limits();
DROP INDEX IF EXISTS idx_rate_limits_lookup;
DROP TABLE public.rate_limits;

-- Recreate with identifier as primary key (one row per caller)
CREATE TABLE public.rate_limits (
  identifier     TEXT        PRIMARY KEY,
  window_start   TIMESTAMPTZ NOT NULL DEFAULT date_trunc('minute', NOW()),
  request_count  INT         NOT NULL DEFAULT 1
);

-- Re-apply RLS
ALTER TABLE public.rate_limits ENABLE ROW LEVEL SECURITY;

CREATE POLICY "rate_limits_deny_all"
  ON public.rate_limits
  FOR ALL
  USING (FALSE);

-- =============================================================================
-- Replacement check_rate_limit function
-- If the row's window is the current minute, increment.
-- If it's an old minute, reset to count=1.
-- =============================================================================
CREATE OR REPLACE FUNCTION public.check_rate_limit(
  p_identifier  TEXT,
  p_limit       INT DEFAULT 10,
  p_window_secs INT DEFAULT 60
)
RETURNS BOOLEAN LANGUAGE plpgsql AS $$
DECLARE
  v_window TIMESTAMPTZ;
  v_count  INT;
BEGIN
  v_window := date_trunc('minute', NOW());

  INSERT INTO public.rate_limits (identifier, window_start, request_count)
  VALUES (p_identifier, v_window, 1)
  ON CONFLICT (identifier) DO UPDATE
    SET request_count = CASE
          WHEN rate_limits.window_start = v_window
          THEN rate_limits.request_count + 1
          ELSE 1
        END,
        window_start = v_window
  RETURNING request_count INTO v_count;

  RETURN v_count <= p_limit;
END;
$$;

ALTER FUNCTION public.check_rate_limit(TEXT, INT, INT) SET search_path = '';
