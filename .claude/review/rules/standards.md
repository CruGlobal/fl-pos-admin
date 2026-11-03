# Standards — Checklist

Generic baseline. Every item here is mandatory unless the repo's own conventions override it —
`/agent-review:init` appends the repo-specific checklist, and both layers are kept.

This is an explicit checklist: report compliance for each **bold group below** in the
`### Rule Checklist Results` section of your output (✅ / ⚠️ / ❌ / N/A), and raise anything
non-compliant as a finding at the severity its impact warrants.

**Exports & Naming**

- [ ] Export style matches the repo's convention (named vs default) — don't introduce a second style
- [ ] File and directory naming follows the existing convention (casing, suffixes, special filenames
      the framework requires)
- [ ] Public identifiers are descriptive; abbreviations match ones already used in the codebase
- [ ] Imports use the repo's alias/path convention rather than deep relative traversal

**Types**

- [ ] No escape hatches that disable type checking in new code (untyped `any`-equivalents, suppression
      comments) without an inline comment explaining why
- [ ] No non-null/force-unwrap assertions on values that can legitimately be absent — check explicitly
- [ ] Types are derived from a single source of truth rather than hand-duplicated alongside it

**Input & Forms**

- [ ] User input is validated with the repo's established validation approach, not ad-hoc checks
- [ ] Every client-side validation rule has a server-side counterpart
- [ ] Submit/confirm actions are disabled or guarded while in flight so they can't double-fire

**Data**

- [ ] Writes invalidate or update the cached data they affect
- [ ] Cache/query keys are stable, descriptive, and scoped to the resource and its inputs
- [ ] Queries rely on the real authorization boundary, not on a client-side filter

**Dates & Numbers**

- [ ] Date math uses the repo's chosen date library and format conventions, not ad-hoc arithmetic
- [ ] Numeric formatting and rounding happen at the display boundary, consistently

**Testing**

- [ ] Every new function, hook, and non-trivial component has a test in the repo's conventional
      location
- [ ] Tests use the repo's runner and mocking idioms
- [ ] Test code is typed as strictly as production code

**Code Quality**

- [ ] Lint, type-check, and format commands pass
- [ ] No debug output left behind (console/print statements, debuggers, `TODO` without a tracked issue
      reference)
- [ ] No unused imports, variables, or dead parameters
- [ ] No commented-out code blocks (delete, don't comment)
- [ ] No empty catch blocks that swallow errors silently
- [ ] Package-manager usage matches the repo's lockfile (don't mix tools)

<!-- init: extend this file with repo-specific focus areas and evidence links -->

## fl-pos-admin: repo-specific checklist

**Commands (quoted exactly)**

- [ ] Tests: `bundle exec rspec --color` (CI job `test`, with a Postgres 17 service and
      `bundle exec rails db:schema:load`)
- [ ] Style: `bundle exec standardrb --format simple` (CI job `lint`); fix with
      `bundle exec standardrb --fix`
- [ ] Security: `bundle exec brakeman -A -q --no-pager` (CI job `lint`), then
      `bin/bundler-audit check --update` and `bin/importmap audit` (CI job `audit`, not required)
- [ ] All of it locally: `bin/ci` (runs the steps in `config/ci.rb`)

**Ruby style**

- [ ] StandardRB owns style (double quotes, spacing, hash shorthand such as `{sku:, quantity:}`).
      Do not raise style nits it would catch. Do flag a new `# standard:disable` or
      `# rubocop:disable` comment that has no reason; the only one today is in
      `config/initializers/woocommerce_api_patch.rb`.
      <!-- evidence: PR #24, #33 -->
- [ ] No second linter or RuboCop config. `bin/rubocop` was removed on purpose.

**Service and job classes**

- [ ] New pipeline work follows the service shape in `app/services/`: an empty `initialize`,
      memoized clients (`@sf_client ||= Restforce.new(...)`, `@woo ||= WooCommerce::API.new(...)`,
      `@lsh ||= LightspeedApiHelper.new`), `create_job`, `poll_jobs`, `handle_job(job)`, and a
      `log job, message` helper that calls `job.logs.create(content: ...)` and
      `Rails.logger.info`.
- [ ] File names map to class names the Zeitwerk way: `l_s_extract.rb` defines `LSExtract` and
      `s_f_import.rb` defines `SFImport`. Keep that mapping for new files.
- [ ] Job classes in `app/jobs/` stay thin: `queue_as :default`, a `perform(*args)` that calls the
      service, and a `rescue => e` that marks the job `error` and re-raises.
- [ ] Job types are the uppercase strings in `Job::TYPE` (`"LS_EXTRACT"`, `"SF_IMPORT"`,
      `"WOO_IMPORT"`, `"WOO_REFRESH"`, `"POLL_SHEET"`; `CleanJobs` also uses `"CLEAN_JOBS"`). A
      new type is added to `Job::TYPE` and `Job#restart_job`.
- [ ] App code logs with `Rails.logger` or the `log` helper, never `puts` or `pp`.

**Controllers and params**

- [ ] Strong params use Rails 8 `params.expect(job: [...])`, and failed saves render with
      `status: :unprocessable_content`.
- [ ] The health check path comes from `FlPosAdmin::HEALTHCHECK_PATH` and
      `FlPosAdmin::HEALTHCHECK_ACTION` (`config/application.rb`). Only `config/routes.rb` and
      cru-terraform spell out `/monitors/lb`.

**Config, ENV, and dependencies**

- [ ] A new ENV var gets a blank entry in the committed `.env` (dev defaults only) and is read with
      `ENV["NAME"]` or `ENV.fetch("NAME")`. Real values never go in `.env`.
      <!-- evidence: PR #22, #34 -->
- [ ] Gems use Bundler (`Gemfile`, `Gemfile.lock`), and `sidekiq-pro` comes from the contribsys
      source block. JS packages use Yarn (`yarn.lock`) and exist only for the CSS build; there is
      no `package-lock.json`. Browser JS goes through importmap (`config/importmap.rb`).
- [ ] Security-only gem bumps touch `Gemfile.lock` only and move as little as possible:
      `bundle lock --update <gem> --conservative`, with a PR body that lists each gem's old and new
      version and its advisory. Run `bin/bundler-audit check --update` before opening any PR,
      config-only ones included, because a new advisory turns the `audit` job red on an
      unrelated change.
      <!-- evidence: PR #102, #110, #111 -->
- [ ] When a PR edits a gem's `configure` block (Datadog, Sidekiq, Rollbar, OmniAuth), every option
      it sets exists in the locked gem version. `Datadog.configure` silently skips unknown keys,
      which is how this app's DB and cache spans ended up under shared services.
      <!-- evidence: PR #105 -->

**Comments and PR text**

- [ ] Comments and the PR description match the code as it stands after this PR. When a change
      removes what a comment explains (a version pin, a flag, a workaround), update or delete the
      comment in the same PR, and do not copy a claim from a sibling repo or a template without
      checking it here. AI-written PRs drifted this way, for example a Dependabot ignore whose
      comment outlived its pin and a comment that credited a digest with checks it never ran.
      <!-- evidence: PR #102, #104 -->
