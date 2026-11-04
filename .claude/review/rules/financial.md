# Financial Calculations: Focus Areas

This lane checks the money math that turns a Lightspeed sale into a Google Sheet row and then a
WooCommerce order. Lightspeed already charged the customer; this app copies the amounts. A wrong
cent here becomes a wrong order total, line tax, or inventory report, and nobody re-checks each
row by hand.

**Where the money math lives**

- `LightspeedApiHelper#get_all_unit_prices`: each line's price from `displayableSubtotal`, rounded
  to cents.
- `LightspeedApiHelper#get_all_unit_taxes`: each line's tax from `calcTax1 + calcTax2` through
  `custom_round`; then any gap between the line sum and the sale's tax total is pushed onto line 0.
- `LightspeedApiHelper#custom_round`: rounds down when the third decimal is below 6.
- `LightspeedApiHelper#get_discount`: takes the first present one of `calcLineDiscount`,
  `discountAmount`, or `discountPercent` (an `elsif` chain, never a sum).
- `LSExtract#get_report_line`: `OrderTotal` from `calcTotal`, `ItemSubtotal` as the sum of the
  unit prices, and `SalesTax` from `calcTax1 + calcTax2`.
- `LSExtract#remove_refunds`: nets each negative-total line against the same customer's other
  lines (matched by `EmailAddress`), product code by product code.
- `LSExtract#remove_shipping_product_codes`: takes the special-order shipping SKU
  (`LSExtract::SPECIAL_ORDER_SKU`) out of the line lists and the totals.
- `WooImport#get_row_items`: turns the `|`-joined `UnitPrice` and `ItemSalesTax` cells into Woo
  `total`, `subtotal`, `total_tax`, and `subtotal_tax`.

**Totals must reconcile**

- After any change, every report line must still satisfy: the sum of `UnitPrice` equals
  `ItemSubtotal`, the sum of `ItemSalesTax` equals `SalesTax`, and `OrderTotal` equals
  `ItemSubtotal + SalesTax` within a cent, after shipping and refund adjustments.
  <!-- evidence: PR #24, #25 -->
- Look for: a price, tax, or discount helper changed without the totals built from it; the line-0
  adjustment in `get_all_unit_taxes` removed or moved; the shipping SKU removed from the product
  list but not from `OrderTotal`, `ItemSubtotal`, and `SalesTax`.

**Parallel `|`-joined lists**

- `ProductCode`, `Quantity`, `UnitPrice`, and `ItemSalesTax` are parallel lists joined with `|`.
  Item `i` in one list must be item `i` in the others.
- Look for: an edit in `remove_refunds` or `remove_shipping_product_codes` that removes or adds an
  entry in one list but not the rest, or takes an index from the wrong list
  (`product_codes.index` versus `refunded_product_codes.index`).
  <!-- evidence: PR #24, #25 -->

**Rounding and Floats**

- Amounts are Ruby Floats rounded with `.round(2)` and `format("%.2f", ...)`. Round each value
  once, where it is written to the report, not again inside every loop.
- `custom_round` rebuilds the number from `fractional_part[0..1].to_i`, which drops a leading zero
  (0.07 becomes 0.7, 0.096 becomes 0.91). A PR that touches it, or calls it somewhere new, must fix
  or avoid that and add specs for line taxes under ten cents.
- Look for: `to_i` or `to_f` on parts of a money string; string building of amounts; Float `==`
  where a cent tolerance is needed (`(a - b).abs < 0.005`).

**Refunds and discounts**

- Refund lines are found by `OrderTotal < 0` and matched to sales by email. Every guest sale shares
  the anonymous email (`LSExtract::CUSTOMER_ANONYMOUS_EMAIL`), so a guest refund can match any
  guest's sale. Look for changes that make that matching looser, or that match on a field many
  customers share.
- `get_discount` takes the first discount field present. Look for changes that add two discount
  sources together, or that change how `discountPercent` is scaled (the code multiplies by it
  directly; an older version divided by 100).

**Checklist for a money change**

- [ ] A spec on a fixture sale (in `spec/services/l_s_extract_spec.rb` or
      `spec/services/lightspeed_api_helper_spec.rb`) shows the totals still reconcile
- [ ] Edge cases are covered: one line, many lines, a line tax under ten cents, a discount, a
      refund, and a special-order sale
- [ ] The `|`-joined lists stay the same length and order
- [ ] Amounts sent to Woo come from the sheet row, so a change to report math shows up in both
      the sheet and the order
