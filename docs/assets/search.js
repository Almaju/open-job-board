/* ============================================================
   Open Job Board — Search UI
   Calls Supabase PostgREST RPC directly from the browser.
   The anon key is intentionally public — RLS enforces read-only.
   ============================================================ */

const SUPABASE_URL = "https://ppubgurkauoptjsuyfff.supabase.co";
const ANON_KEY     = "sb_publishable_S9AJoMdDWsX1cPOXpM3LJw_pqdn9U0B";
const PAGE_SIZE    = 20;

let currentPage = 1;
let lastParams   = {};
let hasMore      = false;

// ============================================================
// Search
// ============================================================

async function searchJobs(params, page) {
  const body = {
    query:          params.query    || null,
    country:        params.country  || null,
    city:           params.city     || null,
    remote:         params.remote   || null,
    employment:     params.employment || null,
    salary_min_val: params.salary_min ? Number(params.salary_min) : null,
    salary_max_val: params.salary_max ? Number(params.salary_max) : null,
    page_num:       page,
    page_size:      PAGE_SIZE + 1, // fetch one extra to detect next page
  };

  // Remove null values
  Object.keys(body).forEach((k) => { if (body[k] === null) delete body[k]; });

  const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/search_jobs`, {
    method: "POST",
    headers: {
      "apikey":        ANON_KEY,
      "Authorization": `Bearer ${ANON_KEY}`,
      "Content-Type":  "application/json",
    },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.message || `HTTP ${res.status}`);
  }

  return res.json();
}

// ============================================================
// Rendering
// ============================================================

function escHtml(str) {
  return String(str ?? "").replace(
    /[&<>"']/g,
    (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]),
  );
}

function formatSalary(job) {
  if (!job.salary_min && !job.salary_max) return null;
  const currency = escHtml(job.salary_currency ?? "");
  const period   = job.salary_period ? `/ ${escHtml(job.salary_period)}` : "";
  if (job.salary_min && job.salary_max) {
    return `${currency} ${Number(job.salary_min).toLocaleString()}–${Number(job.salary_max).toLocaleString()} ${period}`.trim();
  }
  const single = job.salary_min ?? job.salary_max;
  return `${currency} ${Number(single).toLocaleString()} ${period}`.trim();
}

function renderJob(job) {
  const location = [job.location_city, job.location_country].filter(Boolean).map(escHtml).join(", ");
  const postedAt = job.posted_at
    ? new Date(job.posted_at).toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" })
    : null;
  const salary   = formatSalary(job);

  const tags = [];
  if (job.remote_full)  tags.push(`<span class="tag remote">Remote</span>`);
  else if (job.remote_days) tags.push(`<span class="tag remote">${escHtml(String(job.remote_days))}d/week remote</span>`);
  if (job.employment_type) tags.push(`<span class="tag">${escHtml(job.employment_type)}</span>`);
  if (salary) tags.push(`<span class="tag salary">${salary}</span>`);

  return `
    <article class="job-card">
      <h3>${escHtml(job.title)}</h3>
      <div class="job-card-meta">
        ${job.company_name ? `<span>${escHtml(job.company_name)}</span>` : ""}
        ${location         ? `<span>${location}</span>` : ""}
        ${postedAt         ? `<span>Posted ${postedAt}</span>` : ""}
      </div>
      ${tags.length ? `<div class="job-tags">${tags.join("")}</div>` : ""}
    </article>
  `;
}

function renderResults(jobs, page) {
  const resultsDiv = document.getElementById("results");
  const header     = document.getElementById("results-header");
  const countEl    = document.getElementById("results-count");
  const pagination = document.getElementById("pagination");
  const prevBtn    = document.getElementById("prev-btn");
  const nextBtn    = document.getElementById("next-btn");
  const pageInfo   = document.getElementById("page-info");

  // Detect next page (we fetched PAGE_SIZE+1)
  hasMore = jobs.length > PAGE_SIZE;
  const displayJobs = hasMore ? jobs.slice(0, PAGE_SIZE) : jobs;

  if (displayJobs.length === 0 && page === 1) {
    resultsDiv.innerHTML = "";
    header.hidden = true;
    pagination.hidden = true;
    showStatus("No jobs found matching your search.");
    return;
  }

  hideStatus();
  header.hidden = false;
  countEl.textContent = displayJobs.length
    ? `Page ${page} — ${displayJobs.length} result${displayJobs.length !== 1 ? "s" : ""}`
    : "";

  resultsDiv.innerHTML = displayJobs.map(renderJob).join("");

  // Pagination
  pagination.hidden  = page === 1 && !hasMore;
  prevBtn.disabled   = page <= 1;
  nextBtn.disabled   = !hasMore;
  pageInfo.textContent = `Page ${page}`;
}

// ============================================================
// Status messages
// ============================================================

function showStatus(msg, isError = false) {
  const el = document.getElementById("status");
  el.textContent = msg;
  el.classList.toggle("error", isError);
  el.hidden = false;
}

function hideStatus() {
  document.getElementById("status").hidden = true;
}

function showLoading() {
  showStatus("Searching...");
  document.getElementById("results").innerHTML = "";
  document.getElementById("results-header").hidden = true;
  document.getElementById("pagination").hidden = true;
}

// ============================================================
// Form handling
// ============================================================

function getParams() {
  return {
    query:      document.getElementById("q").value.trim(),
    country:    document.getElementById("country").value.trim(),
    city:       document.getElementById("city").value.trim(),
    employment: document.getElementById("employment").value,
    remote:     document.getElementById("remote").checked ? true : null,
    salary_min: document.getElementById("salary_min").value,
    salary_max: document.getElementById("salary_max").value,
  };
}

async function doSearch(params, page) {
  showLoading();
  try {
    const jobs = await searchJobs(params, page);
    renderResults(jobs, page);
  } catch (err) {
    showStatus(`Error: ${err.message}`, true);
  }
}

document.getElementById("search-form").addEventListener("submit", async (e) => {
  e.preventDefault();
  currentPage  = 1;
  lastParams   = getParams();
  await doSearch(lastParams, currentPage);
});

document.getElementById("prev-btn").addEventListener("click", async () => {
  if (currentPage <= 1) return;
  currentPage -= 1;
  await doSearch(lastParams, currentPage);
  window.scrollTo({ top: 0, behavior: "smooth" });
});

document.getElementById("next-btn").addEventListener("click", async () => {
  if (!hasMore) return;
  currentPage += 1;
  await doSearch(lastParams, currentPage);
  window.scrollTo({ top: 0, behavior: "smooth" });
});

// ============================================================
// Initial load: show recent jobs
// ============================================================

(async () => {
  lastParams = {};
  await doSearch(lastParams, 1);
})();
