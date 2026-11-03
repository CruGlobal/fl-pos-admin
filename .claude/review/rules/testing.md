# Testing — Focus Areas

Generic baseline. `/agent-review:init` appends this repo's test conventions (runner, layout,
mocking idioms); keep both.

**Prefer pure-function unit tests**

- Business and domain logic should be extracted out of UI/handler code into plain functions and
  tested directly, rather than asserted through a rendered surface or an HTTP round trip
- Look for: new logic that is only reachable through a component or endpoint, with no seam to test

**Use the repo's existing test framework and idioms**

- Match the repo's test runner, assertion style, mocking helpers, and import conventions. Do not
  assume a framework, rendering harness, or helper library that the repo does not already depend on
- Look for: tests introducing a second runner or harness; imports of libraries absent from the
  manifest

**Mock at module/external boundaries**

- External services (databases, third-party APIs, mail, payments, LLMs) are mocked at the module
  boundary, not by patching global network primitives ad hoc
- Look for: real network or filesystem access in unit tests; mocks that drift from the real
  signature; over-mocking that leaves the logic under test unexercised

**Determinism**

- Time-dependent logic uses the runner's fake-timer/clock control rather than real system time.
  Random values are seeded or injected
- Look for: tests that depend on the current date, timezone, ordering of a map/set, or on another
  test having run first

**Coverage of the shape of the input**

- Every new test should exercise: empty, zero / one / many, boundary values, and at least one happy
  path
- Look for: tests that only assert the happy path; parameters whose invalid values are never tested

**Error paths**

- Validation rejections, rejected promises, timeouts, and the failure branches of domain functions
  are tested, not just success
- Look for: `catch` branches with no covering test

**Test placement and naming**

- Follow the repo's convention for where tests live and how they're named
- Test names describe the behavior asserted, not the function name alone

**Quality gates**

- The repo's test, type-check, lint, and format commands must all pass
- Look for: skipped or `.only` tests left behind; loosely-typed mocks that defeat type checking;
  assertions that can never fail (e.g. asserting on the mock's own return)

<!-- init: extend this file with repo-specific focus areas and evidence links -->

## fl-pos-admin: repo-specific focus

**Runner and layout**

- RSpec only (`rspec-rails`), run with `bundle exec rspec --color`. Specs live in
  `spec/controllers`, `spec/jobs`, `spec/models`, `spec/routing`, `spec/services`, and
  `spec/views`, named `<file>_spec.rb` to match `app/`. Each service in `app/services/` has a spec
  in `spec/services/`, and each job in `app/jobs/` has one in `spec/jobs/`.
- Factories live in `spec/factories/` (`:job`, `:woo_product`) and use Faker. JSON fixtures live
  in `spec/fixtures/` and are read with
  `JSON.parse(File.read("#{Rails.root}/spec/fixtures/..."))`.
- Coverage is collected with simplecov-cobertura only when `CI=true` and uploaded to Codecov,
  which fails the `test` job on upload errors.

**Mocking outside services**

- Outside APIs are stubbed at the client:
  `allow_any_instance_of(Restforce::Data::Client).to receive(:query)`,
  `allow(Google::Auth::ServiceAccountCredentials).to receive(:make_creds).and_return(nil)`,
  `allow_any_instance_of(Google::Apis::SheetsV4::SheetsService)`, doubles for Lightspeed shops
  (`double("shop")` with `Contact` and `name`), and
  `LightspeedStubHelpers.stub_lightspeed_account_request` for the account call.
- `spec/rails_helper.rb` sets `WebMock.allow_net_connect!`, so a spec that forgets a stub can
  reach the real Lightspeed, Salesforce, Woo, or Google APIs. Flag new specs that call a client
  method without a stub.
- Specs that stub `Job.where` with exact arguments (as in `spec/services/woo_import_spec.rb`)
  break when the query changes. When a PR changes a `Job.where(...)` in a service, check that the
  matching `with(...)` stubs changed too.

**Fixtures**

- New or changed fixtures must use synthetic data (Faker, or clearly fake values such as
  `example.com` emails). Never commit a real Lightspeed, Salesforce, or Woo export: this repo is
  public.
  <!-- evidence: PR #24 -->

**What to check in a diff**

- When a service method's return shape changes, the PR must update every caller and every spec
  that builds that output by hand. `SFImport#get_inventory` changed from a Hash to an Array of
  `{sku:, quantity:}`, and the Salesforce push broke because its spec fed the old shape straight
  into the consumer. Feed the producer's real output into the consumer in at least one spec.
  <!-- evidence: PR #33, #41 -->
- Lightspeed sales without `SaleLines`, without `Customer`, or with a single Hash where a list is
  expected are real shapes. Parsing changes need a spec for each of them.
  <!-- evidence: PR #40, #48 -->
- Money helpers in `LightspeedApiHelper` (`custom_round`, `get_all_unit_taxes`,
  `get_all_unit_prices`, `get_discount`) need direct specs with edge cases: one line, many lines,
  a line tax under ten cents, a discount, and a refund. `custom_round` has no spec today.
- Job specs follow `spec/jobs/*_job_spec.rb`: one example that it enqueues, one that `perform`
  calls the service, and one that an error marks the `Job` row `error` and re-raises. New jobs
  need all three.
