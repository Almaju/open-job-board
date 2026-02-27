# Open Job Board

A free, open job board with a public REST API. Anyone can post jobs (scrapers, companies, individuals). Anyone can query them.

**Live:** https://almaju.github.io/open-job-board
**API Docs:** https://almaju.github.io/open-job-board/docs.html

---

## Quick Start

### Query jobs

```bash
# List recent jobs
curl "https://ppubgurkauoptjsuyfff.supabase.co/rest/v1/jobs?order=posted_at.desc&limit=10" \
  -H "apikey: sb_publishable_S9AJoMdDWsX1cPOXpM3LJw_pqdn9U0B"

# Filter: remote jobs in France
curl "https://ppubgurkauoptjsuyfff.supabase.co/rest/v1/jobs?location_country=eq.France&remote_full=eq.true" \
  -H "apikey: sb_publishable_S9AJoMdDWsX1cPOXpM3LJw_pqdn9U0B"

# Full-text search with filters
curl -X POST "https://ppubgurkauoptjsuyfff.supabase.co/rest/v1/rpc/search_jobs" \
  -H "apikey: sb_publishable_S9AJoMdDWsX1cPOXpM3LJw_pqdn9U0B" \
  -H "Content-Type: application/json" \
  -d '{"query": "senior engineer", "country": "Germany", "remote": true, "page_size": 20}'
```

### Submit a job

```bash
curl -X POST "https://ppubgurkauoptjsuyfff.supabase.co/functions/v1/submit-job" \
  -H "Content-Type: application/json" \
  -d '{
    "origin": { "source": "my-scraper", "reference": "job-12345" },
    "title": "Senior Backend Engineer",
    "description": "We are looking for a backend engineer...",
    "company": { "name": "Acme Corp", "website": "https://acme.com", "sector": "Technology" },
    "location": { "city": "Berlin", "country": "Germany", "remote": { "full": true } },
    "employment_type": "full-time",
    "salary": { "currency": "EUR", "min": 80000, "max": 120000, "period": "yearly" },
    "benefits": ["health insurance", "30 days vacation"],
    "posted_at": "2026-02-27T10:00:00Z"
  }'
```

**Rate limits:** 10 requests/minute per IP without an API key. Request an API key for higher limits (see below).

---

## API Reference

### Base URLs

| Purpose | URL |
|---------|-----|
| Read (PostgREST) | `https://ppubgurkauoptjsuyfff.supabase.co/rest/v1` |
| Write (Edge Functions) | `https://ppubgurkauoptjsuyfff.supabase.co/functions/v1` |

All read requests require the header: `apikey: sb_publishable_S9AJoMdDWsX1cPOXpM3LJw_pqdn9U0B`

### Endpoints

#### `GET /rest/v1/jobs`
List and filter jobs. Supports full [PostgREST filter syntax](https://docs.postgrest.org/en/stable/references/api/tables_views.html).

Common filters:
- `?location_country=eq.France` — filter by country
- `?remote_full=eq.true` — remote jobs only
- `?employment_type=eq.full-time`
- `?salary_min=gte.50000`
- `?title=ilike.*engineer*` — fuzzy title match
- `?order=posted_at.desc&limit=20&offset=0` — pagination

#### `POST /rest/v1/rpc/search_jobs`
Full-text search with ranking and combined filters.

```json
{
  "query": "string (full-text search)",
  "country": "string",
  "city": "string",
  "remote": true,
  "employment": "full-time",
  "salary_min_val": 50000,
  "salary_max_val": 150000,
  "source_filter": "string",
  "page_num": 1,
  "page_size": 20
}
```

#### `POST /rest/v1/rpc/get_job_detail`
Get a full job record including description, requirements, and all nested fields.

```json
{ "job_id": "uuid" }
```

#### `POST /functions/v1/submit-job`
Submit a new job. See [Job Schema](#job-schema) below.

Optional header: `X-API-Key: <your-key>` for higher rate limits.

---

## Job Schema

```json
{
  "origin": {
    "source": "required — name of your scraper or 'direct'",
    "reference": "optional — original job ID from the source",
    "contact": {
      "name": "optional",
      "email": "optional",
      "phone": "optional"
    }
  },
  "title": "required",
  "description": "required",
  "responsibilities": ["optional array of strings"],
  "company": {
    "name": "optional",
    "website": "optional URL",
    "sector": "optional",
    "anecdote": "optional blurb about the company",
    "location": ["optional array of office locations"]
  },
  "employment_type": "full-time | part-time | contract | freelance | internship",
  "location": {
    "city": "optional",
    "country": "optional",
    "remote": {
      "full": true,
      "days": 3
    }
  },
  "requirements": {
    "qualifications": ["optional"],
    "hard_skills": ["optional"],
    "soft_skills": ["optional"],
    "others": ["optional"]
  },
  "salary": {
    "currency": "EUR",
    "min": 80000,
    "max": 120000,
    "period": "hourly | daily | weekly | monthly | yearly"
  },
  "benefits": ["optional array of strings"],
  "posted_at": "2026-02-27T10:00:00Z",
  "parsed_at": "2026-02-27T11:00:00Z"
}
```

---

## Response Codes (submit-job)

| Code | Meaning |
|------|---------|
| 201 | Job created successfully |
| 409 | Duplicate — same `source` + `reference` already exists |
| 422 | Validation error — check `details` field in response |
| 429 | Rate limit exceeded — retry after 60 seconds |

---

## Getting an API Key

For trusted scrapers or high-volume use cases, request an API key by opening a GitHub issue with:
- Your scraper/company name
- Estimated volume (jobs/day)
- Contact email

API keys unlock higher rate limits (configurable, default 100 req/min).

---

## Infrastructure

| Component | Technology |
|-----------|-----------|
| Database | Supabase (PostgreSQL + PostgREST) |
| Write API | Supabase Edge Functions (Deno) |
| Documentation | GitHub Pages (static) |
| CI/CD | GitHub Actions |

No external servers. Everything runs on Supabase + GitHub.

---

## Contributing

- **Scrapers:** Submit a PR with your scraper script in `scrapers/`
- **Bug reports:** Open a GitHub issue
- **Schema improvements:** Open a GitHub issue or PR against `supabase/migrations/`

---

## License

MIT
