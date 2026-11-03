# Background Jobs: Focus Areas

This lane checks the Sidekiq jobs that run the whole pipeline. Each job class in `app/jobs/` calls
a service in `app/services/` that finds `Job` rows in the database and moves them through a status
flow. Most fixes in this repo's history came from two jobs running at once, a job stuck in
`processing`, or an error that left the wrong status behind.

**How it runs today**

- Sidekiq Pro with `super_fetch!` and `reliable_scheduler!` (`config/initializers/sidekiq.rb`),
  one `default` queue, and `:concurrency: 1` (`config/sidekiq.yml`). Production uses the
  `:sidekiq` ActiveJob adapter.
- Cron comes from sidekiq-cron (`config/schedule.yml`): `WoocommerceRefreshJob` every 50 minutes,
  `PollSheetJob` every 30 minutes, and `CleanJobsJob` at midnight. The cron poller runs in the Puma
  web process (`after_booted` in `config/puma.rb`) because the worker fleet scales to zero when the
  queues are empty. Keep it there; a poller that only starts inside `Sidekiq.configure_server`
  never runs when no worker is up.
  <!-- evidence: PR #84 -->
- sidekiq-unique-jobs: `WoocommerceImportJob` has `sidekiq_options lock: :until_executed`.
  Uniqueness is turned off in tests.
- Status flow on `Job`: `created`, then `paused` (claimed by `poll_jobs`), then `processing` (in
  `handle_job`), then `complete` or `error`. `Job#restart_job` sets `created` and enqueues the
  matching job class.

**One job at a time**

- The services assume one job runs at a time. `poll_jobs` in `LSExtract`, `SFImport`, and
  `WooImport` re-enqueues itself (`set(wait: 5.minutes).perform_later`) while a `WOO_REFRESH` job
  is `processing`, and `WooImport` also refuses to start while a `WOO_IMPORT` job is `processing`.
  Flag a PR that raises `:concurrency:`, adds a queue with its own workers, removes one of these
  guards, or drops `lock: :until_executed`, unless it also makes the check-then-claim step safe
  (a row lock or a unique lock).
  <!-- evidence: PR #43, #45, #53 -->
- Look for: a new job that writes to Woo, Salesforce, or the sheet without the `WOO_REFRESH`
  guard; a new cron entry that can overlap a long job.

**Errors must leave a true status**

- Each job's `rescue => e` marks its work `error` and re-raises. The common form
  `Job.where(type: ..., status: :processing).order(updated_at: :desc).first.status_error!` raises
  `NoMethodError` when no job is processing, which hides the real error. New or edited rescue
  blocks loop over the processing jobs (as `WoocommerceImportJob` does) or guard the nil, and still
  `raise e`.
  <!-- evidence: PR #42, #45 -->
- Look for: a rescue that swallows the error; `status_complete!` after a step already set
  `status_error!`; an early `return` that leaves a row in `processing` (it is never picked up
  again, because `poll_jobs` only takes `created`, `paused`, or `error` rows).

**Creating jobs from cron**

- A cron tick adds at most one new job of its type. When code resets stuck jobs (as
  `WoocommerceRefreshJob` does after an hour), the check that decides whether to create a new job
  must be able to be false. Flag always-true checks such as `existing_jobs.count >= 0`.
  <!-- evidence: PR #49 -->
- `PollSheet#handle_job` creates one `WOO_IMPORT` job per ready tab and skips a tab that already
  has one (matched by `event_code`). Keep that check when the code changes.

**Retries and repeat runs**

- A retried job runs `handle_job` again on its saved `context`. Each step must be safe to repeat:
  `WooImport` skips orders that already have an `id`, `LSExtract` rewrites its sheet tab, and
  `SFImport` creates its `Product_Sale__c` rows again. Flag new steps that send data to an outside
  system with no way to skip work that is already done.
- `WooImport#handle_job` pauses and retries a partly failed run, counting in
  `context["retry_count"]`, before it writes `ERROR` to the sheet. The count must be saved to
  `context` before the job pauses.

**Checklist for a job change**

- [ ] The job still marks its `Job` row `error` on failure and re-raises
- [ ] No path leaves a row in `processing`
- [ ] Concurrency 1, the unique lock, and the `WOO_REFRESH` guard still hold
- [ ] A change to `config/schedule.yml` keeps each `description` true to its `cron:` value
- [ ] `spec/jobs/<name>_job_spec.rb` covers the enqueue, the happy path, and the error path
