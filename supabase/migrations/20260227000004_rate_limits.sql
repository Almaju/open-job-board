-- =============================================================================
-- RATE LIMITING
-- Sliding window rate limiter using per-minute buckets.
-- Identifier is either "ip:<address>" or "key:<sha256_hash>".
-- =============================================================================
CREATE TABLE public.rate_limits (
  id             BIGSERIAL   PRIMARY KEY,
  identifier     TEXT        NOT NULL,           -- "ip:1.2.3.4" or "key:abc123..."
  window_start   TIMESTAMPTZ NOT NULL,           -- truncated to the minute
  request_count  INT         NOT NULL DEFAULT 1,
  CONSTRAINT uq_rate_identifier_window UNIQUE (identifier, window_start)
);

CREATE INDEX idx_rate_limits_lookup ON public.rate_limits (identifier, window_start DESC);

-- =============================================================================
-- RPC: check_rate_limit
-- Atomically increments the request count for the current minute window.
-- Returns TRUE if the request is within the limit, FALSE if exceeded.
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
  -- Truncate to the current minute as the window boundary
  v_window := date_trunc('minute', NOW());

  INSERT INTO public.rate_limits (identifier, window_start, request_count)
  VALUES (p_identifier, v_window, 1)
  ON CONFLICT (identifier, window_start)
  DO UPDATE SET request_count = rate_limits.request_count + 1
  RETURNING request_count INTO v_count;

  RETURN v_count <= p_limit;
END;
$$;

-- Cleanup function: remove windows older than 1 hour.
-- Can be called from a scheduled Supabase cron job or from the Edge Function.
CREATE OR REPLACE FUNCTION public.cleanup_rate_limits()
RETURNS VOID LANGUAGE sql AS $$
  DELETE FROM public.rate_limits
  WHERE window_start < NOW() - INTERVAL '1 hour';
$$;
