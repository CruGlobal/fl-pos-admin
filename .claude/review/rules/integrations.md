# External Integrations: Focus Areas

This lane checks the contracts with the four outside systems this app talks to: Lightspeed,
Google Sheets, WooCommerce, and Salesforce. None of them are under our control, their payloads
change shape, and a mistake usually shows up a day later as a missing sheet tab, a wrong order, or
a job stuck in `error`.

**Lightspeed R-Series (`lightspeed_pos` gem, marketplacer fork)**

- `LightspeedApiHelper` builds the client with `LightspeedTokenHolder` and uses
  `accounts.all.first`. Sales come from `@ls_account.sales.all(params: ...)` with
  `load_relations: "all"`, `completed: "true"`, `voided: "false"`, and
  `completeTime: "><,start,end"`.
- Payload shapes vary. A sale can have no `SaleLines`, no `Customer`, no `ShipTo`, or a `Contact`
  with no `Addresses` or `Emails`, and a list of one comes back as a single Hash instead of an
  Array (hence the `is_a?(Array)` wrapping in `get_address_object`, `get_email_addresses`, and
  `get_shipping_address`). Guard every optional key before calling a method on it, and wrap single
  objects into arrays. The same goes for the cached token and Salesforce query results.
  <!-- evidence: PR #16, #19, #40, #48 -->
- Sales are stripped with `strip_to_named_fields` and a schema keep-list before anything uses
  them. A field the code reads must be in `LightspeedSaleSchema` or `LightspeedInventorySchema`, or
  it is `nil` after stripping. Flag new reads of fields the schema drops.
- A shop's `Contact["custom"]` is its event code everywhere else in the app. Shops whose code
  starts with `"P-"` are hidden from the event list in `JobsController#get_event_options`.

**Lightspeed OAuth token**

- The token JSON lives in `Rails.cache` under `lightspeed_auth`. `LightspeedTokenHolder#initialize`
  reads it, and `LightspeedauthController#index` and `#refresh_oauth_token` write it. A new token
  can only be made through the browser flow (`/lightspeedinit`, then `/lightspeedauth`). Read and
  write it only through `Rails.cache`, in every environment. Flag new environment branches or file
  paths for the token. The dev and test `File.write` to `lightspeed_auth.json` in
  `LightspeedauthController` is a known exception that review already asked to remove.
  <!-- evidence: PR #16, #24 -->
- Look for: parsing the cached value without checking that it is present; a refresh path that
  drops the new `refresh_token` (losing it means a person must sign in again); a
  `Lightspeed::Error::Unauthorized` not handled where a user is waiting (see the
  `light_speed_error` page).

**Google Sheets (the hand-off to WooCommerce)**

- One spreadsheet (`ENV["GOOGLE_SHEET_ID"]`) with one tab per event code. `LSExtract#put_sheet`
  writes 29 columns, `A` to `AC`, under a header row, then a "Status" row. `PollSheet` scans each
  tab's columns A and B for `Status` / `READY FOR WOO IMPORT`. `WooImport` reads the tab back and
  finds columns by header name in `build_column_hash`.
- The header names, the report keys in `LSExtract#get_report_line`, and the `@columns["..."]`
  lookups in `WooImport` are one contract. A rename or a new column in one place must change all
  three, plus the `A1:AC` ranges if the column count changes. `@columns["X"]` for a missing header
  is `nil`, and `row[nil]` raises.
- People type the status strings (`IN REVIEW`, `READY FOR WOO IMPORT`, `PROCESSING`,
  `IMPORTED TO WOO`, `ERROR`) into the sheet. Do not rename them without a plan for tabs that
  already exist.

**WooCommerce (`woocommerce_api` gem, patched in `config/initializers/woocommerce_api_patch.rb`)**

- Orders are created with `woo.post("orders", order)`. In `WooImport#get_create_object`, payload
  keys are Woo REST field names as symbols (`:billing`, `:shipping`, `:shipping_lines`,
  `:line_items`, `:meta_data`); `@columns[...]` is only for reading sheet cells. Mixing the two up
  once put the shipping data under a `nil` key, so Woo never got it.
  <!-- evidence: PR #29 -->
- The `event_transaction` meta value (`"#{EventCode}-#{SaleID}"`) is what lets Woo reject a
  duplicate with `duplicate_lightspeed_order`. Keep it stable.
- `WooRefresh` pages through `products` with `per_page: 100` and the `x-wp-totalpages` header.
  `get_page` returns `nil` on a non-200 response, which the loop does not check.
- The patch file replaces the gem's OAuth URL and query building. Flag `woocommerce_api` upgrades
  that do not re-check it.

**Salesforce (`restforce`, `salesforce_bulk_api`)**

- `SFImport` writes `Product_Sale__c` rows (`Product_Code__c`, `Quantity__c`, `Source_Code__c`,
  `Agent__c`, `Upsert_Key__c`). `LSExtract#get_event_address` reads `Event_Details__c` and
  `Conference_Location__r` with SOQL. The Salesforce admin owns these field names; a rename here
  needs a matching change on their side.

**Checklist for an integration change**

- [ ] Optional payload keys are guarded, and single objects are wrapped into arrays
- [ ] Every newly read Lightspeed field is in the schema keep-list
- [ ] The sheet headers, report keys, and Woo column lookups still match
- [ ] Specs stub the client (no real calls; `WebMock.allow_net_connect!` lets them through)
- [ ] Tokens and full response bodies are not logged
