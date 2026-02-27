-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- =============================================================================
-- JOBS TABLE
-- Hybrid schema: flat columns for filterable fields, JSONB for nested arrays
-- =============================================================================
CREATE TABLE public.jobs (
  -- Identity
  id                UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Origin (proto: Origin)
  source            TEXT        NOT NULL,       -- origin.source (required)
  reference         TEXT,                        -- origin.reference
  contact           JSONB,                       -- { name?, email?, phone? }

  -- Core fields
  title             TEXT        NOT NULL,
  description       TEXT        NOT NULL,
  responsibilities  JSONB       NOT NULL DEFAULT '[]',  -- string[]
  benefits          JSONB       NOT NULL DEFAULT '[]',  -- string[]
  employment_type   TEXT,                        -- "full-time", "part-time", etc.

  -- Company (proto: Company, denormalized for query simplicity)
  company_name      TEXT,
  company_website   TEXT,
  company_sector    TEXT,
  company_anecdote  TEXT,
  company_locations JSONB       NOT NULL DEFAULT '[]',  -- string[]

  -- Location (flat for filtering)
  location_city     TEXT,
  location_country  TEXT,
  remote_full       BOOLEAN,
  remote_days       INT,                         -- partial remote: N days/week

  -- Requirements (proto: Requirements, rarely filtered)
  requirements      JSONB,                       -- { qualifications[], hard_skills[], soft_skills[], others[] }

  -- Salary (flat for range filtering)
  salary_currency   TEXT,
  salary_min        NUMERIC(12,2),
  salary_max        NUMERIC(12,2),
  salary_period     TEXT,                        -- "hourly","daily","weekly","monthly","yearly"

  -- Timestamps from source
  posted_at         TIMESTAMPTZ,
  parsed_at         TIMESTAMPTZ,

  -- Moderation
  is_active         BOOLEAN     NOT NULL DEFAULT TRUE,
  flagged           BOOLEAN     NOT NULL DEFAULT FALSE,

  -- Deduplication: same scraper cannot insert the same job twice
  CONSTRAINT uq_source_reference UNIQUE NULLS NOT DISTINCT (source, reference)
);

-- Indexes for common filter patterns
CREATE INDEX idx_jobs_title_trgm        ON public.jobs USING gin (title gin_trgm_ops);
CREATE INDEX idx_jobs_location_country  ON public.jobs (location_country) WHERE is_active;
CREATE INDEX idx_jobs_location_city     ON public.jobs (location_city)    WHERE is_active;
CREATE INDEX idx_jobs_company_name      ON public.jobs (company_name)     WHERE is_active;
CREATE INDEX idx_jobs_employment_type   ON public.jobs (employment_type)  WHERE is_active;
CREATE INDEX idx_jobs_remote_full       ON public.jobs (remote_full)      WHERE is_active;
CREATE INDEX idx_jobs_salary_min        ON public.jobs (salary_min)       WHERE is_active;
CREATE INDEX idx_jobs_salary_max        ON public.jobs (salary_max)       WHERE is_active;
CREATE INDEX idx_jobs_posted_at         ON public.jobs (posted_at DESC)   WHERE is_active;
CREATE INDEX idx_jobs_created_at        ON public.jobs (created_at DESC)  WHERE is_active;
CREATE INDEX idx_jobs_source            ON public.jobs (source)           WHERE is_active;

-- Auto-update updated_at on every row change
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_jobs_updated_at
  BEFORE UPDATE ON public.jobs
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
