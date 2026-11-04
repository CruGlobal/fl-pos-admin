# Data Integrity — Focus Areas

Generic baseline. This is where domain-specific data invariants belong once `/agent-review:init`
appends them; keep both.

**Access scoping at the data layer**

- Every query and mutation is scoped to the authenticated user/tenant/household. New tables,
  columns, or collections need matching access policies
- Look for: policy changes that widen a `where`/`using`/`with check` clause; queries filtered only
  in application code where a shared or admin connection bypasses the policy

**Validation at external boundaries**

- Payloads from HTTP requests, webhooks, queues, and third-party APIs are parsed against an explicit
  schema before use
- Look for: external JSON consumed without validation; fields read off an untyped/`any` value; types
  that have drifted from the actual storage shape

**Cache correctness**

- Every write that changes displayed data invalidates or updates the cache entry that serves it
- Look for: mutations with no invalidation; cache keys that omit an input which changes the result
  (filter, tenant/account id, date range), which serves stale or cross-scope data; optimistic
  updates that don't match the server's response shape or don't roll back on error

**Idempotency & retries**

- Sync jobs, webhook handlers, and queue consumers must not double-apply work on retry or replay
- Look for: blind inserts where an upsert on a stable external id is needed; no dedupe key; partial
  writes with no transaction or compensating action

**Numeric precision**

- Values where exactness matters (money, quantities, percentages) must not accumulate floating-point
  drift; round at the display boundary, never mid-calculation
- Look for: repeated rounding inside a pipeline; mixing units or currencies without conversion;
  aggregate totals recomputed differently in two places

**Date & time handling**

- Look for: non-deterministic "now" inside calculations (makes behavior untestable and
  timezone-fragile); naive local-time arithmetic across DST; inconsistent serialization formats
  across boundaries

**Null, undefined, and partial writes**

- An omitted field, an explicit null, and an empty string are three different writes. Be intentional
- Look for: whole objects spread into an insert/update without an explicit field allowlist; defaults
  applied in one code path but not another

**Aggregation over partial data**

- Look for: totals summed client-side over a paginated or filtered subset, silently ignoring rows
  beyond the page — prefer a server-computed aggregate

<!-- init: extend this file with repo-specific focus areas and evidence links -->

## fl-pos-admin: repo-specific focus

**Schema and storage facts**

- Tables: `jobs` (string `type` with STI turned off, integer `status` enum, jsonb `context` with
  default `{}` and a GIN index, `shop_id`, `event_code`, dates), `logs` (model `AppLog`, `jobs_id`
  foreign key to `jobs`), `woo_products`, `woo_product_bundles` (`product_id` foreign key to
  `woo_products.id`), and solid_cache's `solid_cache_entries` (`db/cache_schema.rb`), which also
  holds sessions and the Lightspeed token.
- CI builds the test database with `bin/rails db:schema:load`. A migration must come with the
  matching `db/schema.rb` change from the Rails 8.1 dumper.

**Deleting parents with children**

- When code destroys or deletes a parent row, its children must go first or be covered by
  `dependent:` with the right `foreign_key:` (`WooProduct has_many :woo_product_bundles,
  foreign_key: :product_id, dependent: :destroy`; `Job has_many :logs, foreign_key: "jobs_id",
  dependent: :destroy`). Raw `DELETE` SQL (as in `CleanJobs`, `WooRefresh`, and `PollSheet`)
  must delete from `logs` before `jobs`. Flag a removed `dependent:` or `foreign_key:` option and
  any new raw delete that skips the child table.
  <!-- evidence: PR #51, #52 -->
- Never delete local rows based on a remote list unless the fetch of that list finished.
  `WooRefresh#save_products_to_db` destroys every `WooProduct` missing from the list it is given,
  but `#get_products_from_woo` rescues errors and returns whatever pages it got. Flag code that
  widens this, and flag changes here that do not first check that the fetch succeeded.
  <!-- evidence: PR #51 -->

**The job context column**

- `jobs.context` holds the stripped sales, the report, the sheet rows, and the Woo order list. It
  is saved several times inside one `handle_job`. `LSExtract` and `SFImport` save a Hash;
  `WooImport#handle_job` saves `context.to_json` (a String) and parses it again on the next run.
  Code that reads `context` must handle the shape that job type writes, and jsonb gives back
  string keys, so flag symbol reads such as `context[:sales]`.
- A big event can put thousands of sales in `context`. Flag code that stores the raw
  `load_relations: "all"` sale before `strip_to_named_fields`, or keeps adding keys nothing reads.

**Status and state**

- Status changes go through the enum bang methods (`status_processing!`, `status_paused!`,
  `status_complete!`, `status_error!`, `status_created!`). Flag `update(status: ...)` with a value
  not in `Job::STATUS`, and flag code that sets `status_complete!` after an earlier step in the
  same run already set `status_error!` (as `WooRefresh#handle_job` does today when a page fetch
  fails).
- `JobsController#update` permits `status`, `type`, and `event_code` through `params.expect`. Flag
  new permitted `Job` fields unless the form needs them.

**Writes to outside systems must survive a re-run**

- `SFImport#push_inventory_to_sf` calls `sf_client.create!` once per SKU with an `Upsert_Key__c`
  of `"#{event_code}-#{sku}"`. A re-run must not double count; check how Salesforce treats a
  repeated `Upsert_Key__c` before changing this code.
- `WooImport#send_to_woo` skips orders that already have an Integer `id`, and treats Woo's
  `duplicate_lightspeed_order` error as done (it sets `id` to 1). Keep each order's `id` saved to
  `context` so a retry does not create the order twice.
