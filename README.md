# spree_boxnow

A [Spree Commerce](https://spreecommerce.org) extension that integrates **BoxNow** locker delivery (APM — Automatic Parcel Machine) for Greek e-commerce stores. BoxNow is a last-mile carrier operating exclusively in Greece.

[![Gem Version](https://badge.fury.io/rb/spree_boxnow.svg)](https://badge.fury.io/rb/spree_boxnow)

## Installation

1. Add to your Gemfile:

   ```bash
   bundle add spree_boxnow
   ```

2. Run the install generator (copies migrations, mounts routes):

   ```bash
   bundle exec rails g spree_boxnow:install
   ```

   The generator will ask whether to run `db:migrate` immediately. If you skip it:

   ```bash
   bin/rails db:migrate
   ```

3. Restart your server.

---

## Setup

### 1. Configure BoxNow credentials

Go to **Admin → Integrations → BoxNow** and fill in:

| Field | Description |
|-------|-------------|
| **Client ID** | Provided by BoxNow |
| **Client Secret** | Provided by BoxNow |
| **Partner ID** | Provided by BoxNow |
| **API URL** | BoxNow API base URL (e.g. `https://api-production.boxnow.gr`) |
| **Origin Location ID** | Your warehouse/store APM location ID |
| **Contact Name** | Sender contact name printed on labels |
| **Contact Phone** | Sender phone number |
| **Contact Email** | Sender email address |

OAuth2 tokens are obtained automatically using Client Credentials and cached in `Rails.cache` for 1 hour.

### 2. Set product dimensions

The shipping calculator determines the price tier from the physical dimensions of the items in the order. Every **Variant** must have `height`, `width`, and `depth` set in **centimetres**.

- If any variant in the order is missing dimensions, the BoxNow shipping method will **not appear** at checkout.
- BoxNow supports **one parcel per order** — all items are treated as a single combined package. If the combined package exceeds BoxNow hard limits, the method is hidden.

BoxNow hard limits:

| Dimension | Limit |
|-----------|-------|
| Max weight | 20 kg |
| Max height | 36 cm |
| Max width | 45 cm |
| Max depth | 60 cm |

### 3. Create a BoxNow shipping method

Go to **Admin → Shipping Methods → New**:

1. Name it (e.g. "BoxNow Locker Delivery")
2. Tick the **BoxNow** checkbox so the extension recognises it
3. Select **BoxNow Rate** as the calculator
4. Set the calculator preferences:

| Preference | Default | Description |
|------------|---------|-------------|
| **Small box price** | 0.0 | Price for parcels ≤ 8 cm in height |
| **Medium box price** | 0.0 | Price for parcels ≤ 17 cm in height |
| **Large box price** | 0.0 | Price for parcels ≤ 36 cm in height |
| **Base padding (cm)** | 1.0 | Added to every dimension to account for the physical box being slightly larger than its contents. Set to `0` to disable. |
| **Multi-item factor** | 1.05 | Multiplier applied to all dimensions when an order has more than one item (accounts for imperfect stacking). Set to `1.0` to disable. |

---

## How parcel sizing works

The calculator models the entire order as **one parcel** — there is no multi-box splitting.

For each line item it:
1. Sorts the variant's three dimensions smallest → largest (`s ≤ m ≤ d`)
2. Stacks items along the smallest axis: `parcel_height += s × quantity`
3. Takes `width = max(m)` and `depth = max(d)` across all items

After stacking, padding and the multi-item factor are applied. The resulting three dimensions are then sorted again to allow virtual rotation, and the smallest is compared against the tier thresholds.

| Tier | Height threshold |
|------|-----------------|
| Small | ≤ 8 cm |
| Medium | ≤ 17 cm |
| Large | ≤ 36 cm |

If the package exceeds the large threshold or any hard limit, `nil` is returned and the BoxNow shipping option is hidden from checkout.

---

## Storefront — locker picker

When a customer selects a BoxNow shipping rate at checkout, a locker picker is injected inline. The picker uses the **BoxNow JS widget** which opens a popup map of available APM locations.

On locker selection the widget callback POSTs to `/boxnow/select_locker`, which stores:

- `boxnow.destination_location_id`
- `boxnow.locker_name`
- `boxnow.locker_address`

into `shipment.private_metadata`. Once a voucher is created the locker cannot be changed — further calls to `select_locker` are silently ignored for tracked shipments.

---

## Admin — voucher lifecycle

Prerequisites for an order to be eligible:

- Shipping and billing addresses present
- Payment completed
- Shipment state: **ready**
- A BoxNow locker has been selected by the customer at checkout

### Creating a voucher

1. Open the order in **Spree Admin**.
2. The **"Create Voucher"** option appears in the top-right actions dropdown when the shipment is ready and not yet tracked.
3. Click it — the extension calls the BoxNow API (`POST /api/v1/delivery-requests`) and stores:
   - `shipment.tracking` ← primary parcel ID
   - `shipment.private_metadata['boxnow.vg_child']` ← any child parcel IDs

### Printing a voucher

Once a voucher exists ("Print Voucher" appears in the dropdown):

1. Click **"Print Voucher"** — the extension fetches the PDF label for every parcel ID (primary + children).
2. Multiple PDFs are merged into one using `combine_pdf`.
3. The merged PDF is sent inline in a new browser tab, ready to print.

### Cancelling a voucher

The cancel action is available via `POST admin/boxnow/:order_id/cancel` (guard: shipment must be tracked and not yet shipped). When called it:

1. Calls `POST /api/v1/parcels/{id}:cancel` on the BoxNow API
2. Clears `shipment.tracking` and removes `boxnow.vg_child` from `private_metadata`

> The cancel button in the admin UI is not yet wired up — see [What's not implemented](#whats-not-implemented).

### Retry behaviour

If a voucher creation attempt fails and the admin retries, the extension appends an attempt counter to the order number (`{shipment.number}-2`, `-3`, etc.) to avoid duplicate-order errors from the BoxNow API.

---

## Routes

| Method | Path | Action |
|--------|------|--------|
| `POST` | `/boxnow/select_locker` | Storefront: save locker selection |
| `POST` | `/{admin_path}/boxnow/:order_id/create` | Admin: create voucher |
| `GET` | `/{admin_path}/boxnow/:order_id/print` | Admin: print/download voucher PDF |
| `POST` | `/{admin_path}/boxnow/:order_id/cancel` | Admin: cancel voucher |
| `POST` | `/{admin_path}/boxnow/:order_id/select_locker` | Admin: update locker selection (pre-voucher only) |

---

## What's not implemented

- **Webhook handling** — BoxNow pushes parcel status events to a configurable endpoint. A public route and shipment state updates are not yet implemented. See `docs/BoxNow parcel events webhooks (10-11-23).pdf` for the event payload reference.
- **Cancel voucher UI** — the `CancelVoucher` service and the admin route exist but there is no button in the order dropdown yet.

---

## Developing

```bash
# Install dependencies and set up the dummy app (required before first test run)
bundle install
bundle exec rake test_app

# Run all specs
bundle exec rspec

# Run a single spec
bundle exec rspec spec/feature/home_page_spec.rb
```

Integration tests require these env vars (load via dotenv or export manually):

```
BOXNOW_CLIENT_ID=
BOXNOW_CLIENT_SECRET=
BOXNOW_PARTNER_ID=
BOXNOW_API_URL=
```

When testing a host app's integration you can use the gem's factories:

```ruby
require 'spree_boxnow/factories'
```

---

## Releasing a new version

```bash
bundle exec gem bump -p -t
bundle exec gem release
```

See [gem-release README](https://github.com/svenfuchs/gem-release) for more options.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for instructions on setting up a development environment and submitting pull requests.

Copyright (c) 2026 OlympusOne, released under the MIT License.
