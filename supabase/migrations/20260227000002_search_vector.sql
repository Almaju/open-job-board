-- =============================================================================
-- FULL-TEXT SEARCH via tsvector
-- =============================================================================

-- Add search_vector column
ALTER TABLE public.jobs
  ADD COLUMN search_vector TSVECTOR;

-- GIN index for fast full-text queries
CREATE INDEX idx_jobs_search_vector ON public.jobs USING gin(search_vector);

-- Trigger to maintain search_vector on insert/update
-- Weights: title=A (highest), company=B, description=C, location=D
CREATE OR REPLACE FUNCTION public.update_search_vector()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.search_vector :=
    setweight(to_tsvector('english', COALESCE(NEW.title, '')),        'A') ||
    setweight(to_tsvector('english', COALESCE(NEW.company_name, '')), 'B') ||
    setweight(to_tsvector('english', COALESCE(NEW.description, '')),  'C') ||
    setweight(to_tsvector('english',
      COALESCE(NEW.location_city, '') || ' ' ||
      COALESCE(NEW.location_country, '')), 'D');
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_jobs_search_vector
  BEFORE INSERT OR UPDATE ON public.jobs
  FOR EACH ROW EXECUTE FUNCTION public.update_search_vector();

-- =============================================================================
-- RPC: search_jobs
-- Full-text + filter search, returns ranked results (light columns only)
-- Called via POST /rest/v1/rpc/search_jobs
-- =============================================================================
CREATE OR REPLACE FUNCTION public.search_jobs(
  query           TEXT      DEFAULT NULL,
  country         TEXT      DEFAULT NULL,
  city            TEXT      DEFAULT NULL,
  remote          BOOLEAN   DEFAULT NULL,
  employment      TEXT      DEFAULT NULL,
  salary_min_val  NUMERIC   DEFAULT NULL,
  salary_max_val  NUMERIC   DEFAULT NULL,
  source_filter   TEXT      DEFAULT NULL,
  page_num        INT       DEFAULT 1,
  page_size       INT       DEFAULT 20
)
RETURNS TABLE (
  id               UUID,
  title            TEXT,
  source           TEXT,
  reference        TEXT,
  company_name     TEXT,
  company_sector   TEXT,
  location_city    TEXT,
  location_country TEXT,
  remote_full      BOOLEAN,
  remote_days      INT,
  employment_type  TEXT,
  salary_currency  TEXT,
  salary_min       NUMERIC,
  salary_max       NUMERIC,
  salary_period    TEXT,
  posted_at        TIMESTAMPTZ,
  created_at       TIMESTAMPTZ,
  rank             REAL
)
LANGUAGE plpgsql STABLE SECURITY DEFINER AS $$
DECLARE
  ts_query TSQUERY;
  v_limit  INT;
  v_offset INT;
BEGIN
  v_limit  := LEAST(COALESCE(page_size, 20), 100);
  v_offset := (COALESCE(page_num, 1) - 1) * v_limit;

  IF query IS NOT NULL AND trim(query) <> '' THEN
    ts_query := websearch_to_tsquery('english', query);
  END IF;

  RETURN QUERY
  SELECT
    j.id, j.title, j.source, j.reference,
    j.company_name, j.company_sector,
    j.location_city, j.location_country,
    j.remote_full, j.remote_days,
    j.employment_type,
    j.salary_currency, j.salary_min, j.salary_max, j.salary_period,
    j.posted_at, j.created_at,
    CASE WHEN ts_query IS NOT NULL
      THEN ts_rank(j.search_vector, ts_query)
      ELSE 0.0
    END::REAL AS rank
  FROM public.jobs j
  WHERE
    j.is_active = TRUE
    AND (ts_query IS NULL       OR j.search_vector @@ ts_query)
    AND (country IS NULL        OR j.location_country ILIKE country)
    AND (city IS NULL           OR j.location_city ILIKE city)
    AND (remote IS NULL         OR j.remote_full = remote)
    AND (employment IS NULL     OR j.employment_type ILIKE employment)
    AND (salary_min_val IS NULL OR j.salary_min >= salary_min_val)
    AND (salary_max_val IS NULL OR j.salary_max <= salary_max_val)
    AND (source_filter IS NULL  OR j.source ILIKE source_filter)
  ORDER BY
    CASE WHEN ts_query IS NOT NULL THEN ts_rank(j.search_vector, ts_query) ELSE 0 END DESC,
    j.posted_at DESC NULLS LAST,
    j.created_at DESC
  LIMIT v_limit
  OFFSET v_offset;
END;
$$;

-- =============================================================================
-- RPC: get_job_detail
-- Returns full job record including description, requirements, and JSONB fields
-- Called via POST /rest/v1/rpc/get_job_detail
-- =============================================================================
CREATE OR REPLACE FUNCTION public.get_job_detail(job_id UUID)
RETURNS TABLE (
  id                UUID,
  created_at        TIMESTAMPTZ,
  source            TEXT,
  reference         TEXT,
  contact           JSONB,
  title             TEXT,
  description       TEXT,
  responsibilities  JSONB,
  benefits          JSONB,
  employment_type   TEXT,
  company_name      TEXT,
  company_website   TEXT,
  company_sector    TEXT,
  company_anecdote  TEXT,
  company_locations JSONB,
  location_city     TEXT,
  location_country  TEXT,
  remote_full       BOOLEAN,
  remote_days       INT,
  requirements      JSONB,
  salary_currency   TEXT,
  salary_min        NUMERIC,
  salary_max        NUMERIC,
  salary_period     TEXT,
  posted_at         TIMESTAMPTZ,
  parsed_at         TIMESTAMPTZ
)
LANGUAGE plpgsql STABLE SECURITY DEFINER AS $$
BEGIN
  RETURN QUERY
  SELECT
    j.id, j.created_at,
    j.source, j.reference, j.contact,
    j.title, j.description, j.responsibilities, j.benefits,
    j.employment_type,
    j.company_name, j.company_website, j.company_sector,
    j.company_anecdote, j.company_locations,
    j.location_city, j.location_country,
    j.remote_full, j.remote_days,
    j.requirements,
    j.salary_currency, j.salary_min, j.salary_max, j.salary_period,
    j.posted_at, j.parsed_at
  FROM public.jobs j
  WHERE j.id = job_id AND j.is_active = TRUE;
END;
$$;
