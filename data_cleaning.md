# Data cleaning decisions

Every rule below comes from the profiling check in `sql/02_cleaning/01_data_profile.sql`, run on the full dataset after loading. The raw tables are never changed; each rule is applied in a cleaning view (`sql/02_cleaning/02_clean_views.sql`), so it can be read, questioned and undone.

## What the data looks like

- 99,441 orders from 96,096 real customers, placed Sep 4, 2016 to Oct 17, 2018
- 96,478 orders (97%) were delivered; the rest were canceled (625), unavailable (609), shipped but not yet delivered (1,107), or still being processed
- No negative prices and no review scores outside 1 to 5

## Decisions

| # | Issue found | Rows affected | Decision | Why |
|---|---|---:|---|---|
| 1 | Each order has its own `customer_id` | 99,441 ids for 96,096 people | Count customers with `customer_unique_id` | Otherwise every customer looks like a one-time buyer |
| 2 | 2016 has 329 orders (none in Nov); Sep–Oct 2018 have 20 | 349 orders | Analyze purchases from **Jan 1, 2017 to Aug 31, 2018** | Partial months make trends look like a collapse at the end |
| 3 | Not every order completed | 2,963 non-delivered orders | A sale = an order with status **delivered** | Revenue should be money actually earned; canceled and unavailable orders are tracked separately as a cancellation rate |
| 4 | Payments differ from items + freight by more than 1 | 249 orders | Revenue = **item price**; freight reported separately; payments used only for payment-method questions | Installment interest and vouchers change the amount paid |
| 5 | Orders with no items, no payment, or no approval date | 775 / 1 / 160 | No extra rule needed | Almost all are canceled or unavailable, so rule 3 removes them |
| 6 | Delivered orders with no delivery date | 8 | Excluded from delivery-time analysis only | Delivery time can't be measured without a date |
| 7 | Delivery date on an order that is not "delivered" | 6 | Excluded by rule 3 | Status is the source of truth for a sale |
| 8 | Handed to carrier before the purchase time | 166 | Excluded from "days to ship" only | Impossible timestamps would skew shipping speed |
| 9 | Orders with more than one review; reused review ids | 547 orders; 789 ids | Keep **one review per order, the most recent** | One customer opinion per order; reused ids are copies |
| 10 | Products with no category | 610 products | Category = "unknown" | Keeps their sales in the totals |
| 11 | Categories with no English name | 2 categories | `pc_gamer` → "pc_gamer"; `portateis_cozinha_e_preparadores_de_alimentos` → "portable_kitchen_appliances" | Translated by hand |
| 12 | "not_defined" payment type; payments of 0 | 3; 9 | Leave "not_defined" out of payment-mix results | Too few to matter; no meaning to report |
| 13 | About 50 location points per zip prefix | 1,000,163 rows for 19,015 prefixes | Map by **state**; geolocation table not used | State is enough for a sales map and Tableau maps Brazilian states on its own |
