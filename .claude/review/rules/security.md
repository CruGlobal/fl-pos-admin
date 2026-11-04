# Security — Focus Areas

Generic baseline. `/agent-review:init` appends the repo-specific concerns; keep both.

**Authentication & authorization boundaries**

- Every server endpoint, background job, and privileged action independently verifies the caller's
  identity — never trusts a user id, tenant id, or role passed in from the client
- Authorization is enforced at the data layer (row/tenant scoping, ACL check), not only by hiding UI
- Look for: endpoints added without a session/permission check; ownership checks that compare
  against client-supplied identifiers; policy changes that widen who can read or write a record

**Privileged clients & credentials**

- Admin/service-level clients that bypass normal access control must stay server-only and must never
  be importable from browser or otherwise untrusted code
- Look for: privileged clients imported into client-side modules; secrets read in code that ships to
  the browser; credentials committed to the repo or baked into build artifacts

**Secrets exposure**

- Server-only environment variables must not be exposed through client-visible prefixes, build-time
  inlining, or error payloads
- Look for: new environment-variable references; API keys or tokens in logs, error messages, HTTP
  responses, or analytics events

**Input validation & injection**

- Untrusted input (request bodies, query params, headers, webhooks, third-party payloads, file
  uploads) is validated against an explicit schema before use
- Look for: raw string interpolation into SQL/shell/HTML/templates; parsers fed unvalidated JSON;
  client-side validation with no server-side counterpart; unbounded sizes and counts

**Cross-site and browser-surface risks**

- Look for: raw-HTML injection sinks; unsanitized user content rendered as markup; open redirects
  where a redirect target comes from a query parameter without an allowlist check; missing CSRF
  protection on state-changing requests; weakened CSP or security headers

**Session & cookie handling**

- Look for: session cookies missing `HttpOnly`/`Secure`/`SameSite`; tokens stored where scripts can
  read them; sessions that are not invalidated on logout, password change, or privilege change;
  long-lived or non-rotating credentials

**Webhooks & third-party integrations**

- Look for: webhook handlers that parse and act on a payload before verifying the signature against
  the raw body; missing replay protection; secrets or tokens forwarded to the client

**Supply chain & CI**

- Look for: new dependencies (who maintains them, what they pull in); CI workflow changes that widen
  permission scopes, echo secrets, or let untrusted contributors trigger privileged jobs; changes to
  the review configuration itself that weaken risk scoring or strip checks

<!-- init: extend this file with repo-specific focus areas and evidence links -->

## fl-pos-admin: repo-specific focus

This app reads finished sales from Lightspeed POS, writes inventory counts to Salesforce, writes a
review sheet to Google Sheets, and creates WooCommerce orders. The GitHub repo is **public**, so
anything committed is visible to everyone.

**Card data stays out (the PCI boundary)**

No card data enters this app today. `LightspeedApiHelper#get_sales` and `#get_sale` ask Lightspeed
for `load_relations: "all"`, so the raw sale objects carry `SalePayments` (payment type names such
as "Credit Card", and `ccChargeID`). `LSExtract#handle_job` and `SFImport#handle_job` pass every
sale through `strip_to_named_fields` with `LightspeedSaleSchema` or `LightspeedInventorySchema`
before saving it, and `SalePayments` is not in the sale schema's `"root"` list. So nothing about
payments reaches `jobs.context`, `logs`, the Google Sheet, Salesforce, or WooCommerce. Keep it
that way:

- Flag as a blocker any diff that adds `SalePayments`, `SalePayment`, `PaymentType`, `CCCharge`,
  `ccChargeID`, masked card digits, card type, gateway or auth ids, or cardholder fields to a
  keep-list in `app/services/lightspeed_sale_schema.rb` or
  `app/services/lightspeed_inventory_schema.rb`. That would store card-related data in the
  database, the sheet, and the logs, and pull this repo into PCI scope.
- Flag code that saves, logs, or sends a raw `get_sales` / `get_sale` result before it is
  stripped (for example `job.save!` or `log job, sale.inspect` between the fetch and the
  `strip_to_named_fields` call).
- Flag any payment processor or gateway gem or call (charge, refund, or store a card). This app
  only reads sales that Lightspeed already finished.
- Woo order payloads built in `WooImport#get_create_object` carry billing name, address, email,
  and line items only. Flag new `payment_method`, `transaction_id`, or card fields there.

**Customer data (PII) in a public repo**

- `jobs.context` (jsonb), `logs.content`, the Google Sheet, and Woo orders hold customer names,
  addresses, phones, and emails. Flag new `log job, ...` or `Rails.logger` lines that write a
  whole sale, customer, sheet row, or order (`#{sale}`, `#{row}`, `#{order}`, `.inspect`,
  `.to_json`). Log ids and counts instead. `WooImport#send_to_woo` already logs a whole failed
  response; do not copy that pattern.
- Flag any new fixture, seed, or JSON file that holds real customer contact data. Fixtures must
  use Faker or clearly fake values. Real Lightspeed, Salesforce, or Woo exports must never be
  committed here.
  <!-- evidence: PR #24 -->

**Secrets and tokens**

- Secrets come from ENV (`SF_PASSWORD`, `SF_TOKEN`, `SF_CLIENT_SECRET`,
  `LIGHTSPEED_CLIENT_SECRET`, `WOO_API_SECRET`, `OKTA_CLIENT_SECRET`,
  `GOOGLE_SERVICE_ACCOUNT_KEY`, and so on). The committed `.env` holds blank or dummy dev
  defaults only; real values go in the git-ignored `.env.local` and `.env.test.local`. Flag any
  real-looking value added to `.env`.
- Flag log lines that print OAuth responses or tokens. `LightspeedTokenHolder#refresh_oauth_token`
  logs the full token response at info level, and its error paths (and `trade_access_token`'s)
  log the response body. New code must not repeat this, and a PR that touches those lines should
  drop the body.
- The Lightspeed token is stored only in `Rails.cache` under `lightspeed_auth` (see
  `rules/integrations.md`). Flag new places that write it to disk, the session, or a log.

**Authentication boundaries**

- Every controller inherits `ApplicationController#authenticate_user`, which checks
  `session[:id_token]`. Only `SessionsController` and `MonitorsController` skip it. Flag any new
  `skip_before_action :authenticate_user`, most of all on `LightspeedauthController`: a public
  `/lightspeedauth?code=...` would let anyone swap in their own Lightspeed token for the whole app.
- `/sidekiq` is mounted inside the `user_constraint` block in `config/routes.rb`. Flag changes
  that move the mount out of the constraint or loosen the check.
- `allow_other_host: true` is used only for the Okta logout (`SessionsController#destroy`) and
  the Lightspeed auth URL (`LightspeedinitController#index`), both built from ENV. Flag new ones,
  or any whose target comes from params.
- Links whose GET clears state or redirects to another host need `data-turbo="false"`. Turbo
  prefetches links on hover and cannot follow a cross-site redirect, which is how Logout silently
  failed to sign anyone out.
  <!-- evidence: PR #109 -->

**Injection**

- Raw SQL and SOQL are built with string interpolation today: `CleanJobs#handle_job`
  (`created_at < '#{1.month.ago}'`), the `DELETE` statements in `WooRefresh#poll_jobs` and
  `PollSheet#poll_jobs`, and `LSExtract#get_event_address`
  (`WHERE EventCode__c = '#{event_code}'`, where `event_code` comes from a Lightspeed shop field
  and can also be edited through `JobsController#update`). Flag new interpolation of any value
  into `connection.execute` or a SOQL string. Use `where` with bind values, `sanitize_sql`, or an
  escaped SOQL literal.

**Security tooling**

- Brakeman runs at every confidence level (`bundle exec brakeman -A -q --no-pager`). Flag new
  `config/brakeman.ignore` entries without a `note` that says why the warning is safe, and flag
  confidence filters such as `-w2` or `--ensure-latest` added back to `bin/brakeman` or
  `.github/workflows/ruby.yml`. Fix the warning instead of hiding it.
  <!-- evidence: PR #102, #104, #105 -->
- `config/initializers/filter_parameter_logging.rb` is what keeps params out of the lograge
  request logs (`config/initializers/lograge.rb` logs `params`). Flag removals from that list.
