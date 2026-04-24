# Spree Boxnow

This is an Boxnow extension for [Spree Commerce](https://spreecommerce.org), an open‑source e-commerce platform built with Ruby on Rails. It adds the ability to manage Boxnow vouchers.

[![Gem Version](https://badge.fury.io/rb/spree_boxnow.svg)](https://badge.fury.io/rb/spree_boxnow)

## Installation

1. Add this extension to your Gemfile:

   ```bash
   bundle add spree_boxnow
   ```

2. Run the install generator — this copies the migrations and optionally runs them:

   ```bash
   bundle exec rails g spree_boxnow:install
   ```

   The generator will ask whether to run `db:migrate` immediately. If you skip it, run it manually:

   ```bash
   bin/rails db:migrate
   ```

3. Restart your server.

## Setup

### 1. Configure BoxNow credentials

Go to **Admin → Integrations → BoxNow** and fill in:

- **Client ID** — provided by BoxNow
- **Client Secret** — provided by BoxNow
- **Partner ID** — provided by BoxNow
- **API URL** — BoxNow API base URL (e.g. `https://api-production.boxnow.gr`)

### 2. Set product dimensions

The calculator determines the shipping price tier (small / medium / large) from the physical dimensions of the items in the order. Every **Variant** must have `height`, `width`, and `depth` set in **centimetres**. If any dimension is missing the BoxNow shipping method will not appear at checkout for that order.

BoxNow hard limits — orders exceeding these will not be eligible:

| Limit | Value |
|-------|-------|
| Max weight | 20 kg |
| Max height | 36 cm |
| Max width | 45 cm |
| Max depth | 60 cm |

### 3. Create a BoxNow shipping method

Go to **Admin → Shipping Methods → New** and:

1. Name it (e.g. "BoxNow Locker Delivery")
2. Tick the **BoxNow** checkbox so the extension recognises it
3. Select **BoxNow Rate** as the calculator
4. Fill in the calculator preferences:

| Preference | Description |
|------------|-------------|
| **Small box price** | Price for parcels ≤ 8 cm in height |
| **Medium box price** | Price for parcels ≤ 17 cm in height |
| **Large box price** | Price for parcels ≤ 36 cm in height |
| **Base padding (cm)** | Added to every dimension to account for the physical box being slightly larger than its contents. A value of `1.0` means each dimension grows by 1 cm before the tier is evaluated. Set to `0` to disable. |
| **Multi-item factor** | Multiplier applied to all dimensions when an order contains more than one item, to account for imperfect stacking (e.g. `1.05` = 5% overhead). Set to `1.0` to disable. |

The calculator always returns one price — the tier that matches the estimated parcel size. There is no way to disable a specific tier; if an order's package fits a tier, that tier's price is used.

---

## Usage (Creating & Printing Vouchers)

Prerequisites for an order:

- Shipping and billing addresses present
- Payment completed
- Order state: ready (so shipments exist and are ready to ship)

Workflow:

1. Open the order in Spree Admin.
2. If the order meets the prerequisites, the “Create Voucher” option appears in the top‑right dropdown.
3. Click “Create Voucher” (creates one voucher per shipment or split shipment).
4. After successful creation, the “Print Voucher” option becomes available.
5. Click “Print Voucher”: a merged (or single) PDF opens in a new tab for download/printing.

Notes:

- Multiple shipment vouchers are merged into one PDF.
- If no voucher can be created (e.g. order not ready), the button does not appear.
- Errors will return and log details server‑side.

## Developing

1. Create a dummy app:

   ```bash
   bundle update
   bundle exec rake test_app
   ```

2. Add code.

3. Run tests:

   ```bash
   bundle exec rspec
   ```

When testing your application's integration you may use its factories:

```ruby
require 'spree_boxnow/factories'
```

## Testing

Generate the test app:

```bash
bundle exec rake test_app
```

Then run:

```bash
bundle exec rspec
```

## Releasing a new version

```bash
bundle exec gem bump -p -t
bundle exec gem release
```

For more options please see [gem-release README](https://github.com/svenfuchs/gem-release)

## Contributing

If you'd like to contribute, please take a look at the
[instructions](CONTRIBUTING.md) for installing dependencies and crafting a good
pull request.

Copyright (c) 2026 OlympusOne, released under the MIT License.
