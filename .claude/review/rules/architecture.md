# Architecture — Focus Areas

Generic baseline. `/agent-review:init` appends the repo-specific concerns; keep both.

**Layering & boundaries**

- Business logic lives in testable modules, not inline in entry points (route/page/controller/CLI
  handlers). Entry points compose and delegate
- Server-only code stays out of code paths that ship to a client or untrusted runtime
- Look for: domain math embedded in view code; a module reaching across layers it shouldn't know
  about; new circular dependencies

**Placement & structure**

- New files land where the existing convention says they belong; shared code goes to the shared
  location only when it is genuinely used by more than one feature
- Look for: one-off code dropped into a "shared"/"common"/"utils" bucket; parallel structures that
  duplicate an existing module instead of extending it; new top-level directories

**Pattern consistency**

- The change should look like the code around it. Deviating is fine when the existing pattern is
  what's being fixed — but then it should be fixed consistently, not forked
- Look for: a second way of doing something the codebase already does one way (data fetching, error
  handling, configuration, logging); framework features reimplemented by hand

**State & data flow**

- Cached/derived state has a clear owner, and writes invalidate or update what they affect
- Look for: the same state maintained in two places; refetching in an effect what a cache already
  owns; values threaded through three or more layers that would be better read closer to use

**Effects & lifecycle**

- Look for: effects whose dependency list omits referenced values (stale closures); work in an
  effect that belongs in an event handler or a derived value; subscriptions and timers without
  cleanup

**Concurrency & performance shape**

- Look for: sequential awaits on independent work that could run concurrently; N+1 query patterns;
  unbounded loops over remote calls; work done per-item that could be batched

**Error handling & resilience**

- Look for: swallowed errors (empty catch, error logged and ignored); failures that leave state
  half-written; missing error/loading boundaries on user-facing surfaces; retries without backoff or
  idempotency

**Technical debt**

- Weigh debt added against debt removed. A refactor that only moves code without improving clarity
  is neutral, not positive. When a convention is ambiguous, raise it as a question rather than a
  blocking finding

<!-- init: extend this file with repo-specific focus areas and evidence links -->

## fl-pos-admin: repo-specific focus

Under the `code-review` engine this lane does not run on its own. This section is scoring context
for the code-review lane.

**Pipeline shape**

- The app is a pipeline of job types. Each is a service class in `app/services/` driven by a thin
  ActiveJob in `app/jobs/`: `LSExtract` (LS_EXTRACT: Lightspeed sales to a Google Sheet tab),
  `SFImport` (SF_IMPORT: Lightspeed sales to Salesforce `Product_Sale__c`), `PollSheet`
  (POLL_SHEET: finds tabs marked "READY FOR WOO IMPORT"), `WooImport` (WOO_IMPORT: sheet rows to
  Woo orders), `WooRefresh` (WOO_REFRESH: local cache of Woo products), and `CleanJobs`
  (CLEAN_JOBS: deletes old jobs). New work follows this split: logic in the service, and the job
  class only calls the service and handles errors.
- Every service has the same methods: `create_job`, `poll_jobs`, `handle_job(job)`, and
  `log job, message`. A new job type copies this shape, adds its type string to `Job::TYPE`, and
  adds a branch to `Job#restart_job`.
- Controllers stay thin. `JobsController#create` makes both an SF_IMPORT and an LS_EXTRACT job for
  one shop and date range; keep those two in step.

**Contracts between services**

- The Google Sheet is the hand-off from `LSExtract` to `WooImport`. The headers in
  `LSExtract#put_sheet`, the keys built in `LSExtract#get_report_line`, and the `@columns[...]`
  lookups in `WooImport#get_create_object` and `#get_row_items` must change together. The
  "Status" row and its strings are shared by `LSExtract`, `PollSheet`, and `WooImport`.
- `WooProduct` and `WooProductBundle` rows (filled by `WooRefresh`) are read by
  `SFImport#get_inventory` for bundle expansion and by `LSExtract#get_products`.
- Hardcoded SKUs live in two places: `LSExtract::SPECIAL_ORDER_SKU` and `SFImport#filter_skus`
  (`"MSC17061"`, `"COL20277"`). A change to one should consider the other.

**Known debt (weigh it; do not re-raise it as new)**

- The rescue blocks in five `app/jobs/*_job.rb` files call `.first.status_error!`, which raises
  on nil. `WoocommerceImportJob` was fixed to loop over every processing job instead.
- `WooImport` saves `context` as a JSON string while the other services save a Hash.
- Each service repeats its own Restforce, Woo, and Sheets client setup and its own `log` helper.
  A shared client is welcome, but not required in an unrelated PR.
