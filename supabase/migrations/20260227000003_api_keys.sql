-- =============================================================================
-- API KEYS TABLE
-- Stores SHA-256 hashes of API keys for trusted scrapers/companies.
-- The actual key value is never stored.
-- =============================================================================
CREATE TABLE public.api_keys (
  id          UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  key_hash    TEXT        NOT NULL UNIQUE,   -- SHA-256 hex digest of the actual key
  name        TEXT        NOT NULL,           -- human label, e.g. "MyScraperBot v2"
  owner_email TEXT,
  is_active   BOOLEAN     NOT NULL DEFAULT TRUE,
  rate_limit  INT         NOT NULL DEFAULT 100,  -- max requests per minute
  last_used   TIMESTAMPTZ
);

COMMENT ON TABLE public.api_keys IS
  'Trusted API keys for scrapers and companies. Keys are stored as SHA-256 hashes only.';
COMMENT ON COLUMN public.api_keys.rate_limit IS
  'Maximum number of submit-job requests per minute for this key.';
