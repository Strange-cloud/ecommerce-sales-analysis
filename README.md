# E-Commerce Sales & Customer Analysis (SQL + Tableau)

An analysis of about 96,000 delivered orders from Olist, a Brazilian online marketplace (Jan 2017 – Aug 2018). I loaded the raw data into PostgreSQL, cleaned it with documented rules, answered 12 business questions in SQL, and built a three-page interactive dashboard in Tableau.

**[View the interactive dashboard on Tableau Public →](https://public.tableau.com/app/profile/chris.mcleod6376/viz/OlistEcommerceAnalysis_17954093813740/Overview)**

**Tools:** PostgreSQL 18 (CTEs, window functions, cohort and RFM analysis) · Python (pandas, psycopg2) · Tableau

## The short version

Olist more than doubled its revenue, but almost all of that growth came from **new** customers. Only 3% of customers ever order a second time, and late deliveries are the single biggest cause of bad reviews. The biggest opportunities are winning back past big spenders and fixing delivery in a few problem regions.

## Key findings

### Sales
- **Revenue grew 141%** (Jan–Aug 2018 vs the same months of 2017). That growth came from more orders (+140%), not bigger ones: the average order stayed flat at about **R$137**.
- **November 2017 (Black Friday) was the peak month.** Growth then **plateaued through 2018**.
- **The top 10 categories bring in 62.5% of revenue.** Health & beauty leads at 9.3%.
- **São Paulo state is 42% of orders but has the lowest average order (R$125).** Far north and northeast states spend 50–75% more per order. Shipping costs likely make only bigger purchases worthwhile there.

### Customers
- **Only 3.0% of 93,104 customers ordered more than once.**
- **Cohort retention:** about 0.5% of a month's new customers return the next month, falling to about 0.25% by month 3. The first 30–60 days are the window to win a second order.
- **RFM segments:** "Lapsed big spenders" are 20,721 one-time buyers who spent an average of R$268 and haven't returned. They account for **42% of revenue**.

### Delivery & reviews
- **6.8% of orders arrive late.** The average delivery takes 12.5 days.
- **Late orders average 2.27 stars vs 4.29 on time.** 62% of late orders get a 1–2 star review, compared with 9% of on-time orders. Late orders are under 7% of orders but **about a third of all bad reviews**.
- **The northeast has the highest late rates** (Alagoas 21.5%, Maranhão 17.5%). **Rio de Janeiro** has the **most** late orders: it is 12% late despite being close to most sellers, which makes it about 23% of all late orders.

### Sellers & payments
- **The top 10% of sellers (295 of 2,945) bring in 67% of revenue.**
- **15 high-volume sellers (100+ orders) average under 3.8 stars.** Eight of them also deliver late more often than average, which points to shipping problems. The other seven deliver on time but still rate badly, which points to product or service problems.
- **Credit card covers 77% of orders and boleto (bank slip) 20%.** Average order value rises with installments: from R$83 paid in full to R$301 at 7+ installments.

## Recommendations

1. **Run a win-back campaign for lapsed big spenders.** They hold 42% of revenue and have bought once. Even a small return rate is worth a lot.
2. **Add a second-order offer within 30–60 days of the first purchase.** Retention drops sharply after month 1, so this window matters most.
3. **Fix delivery where it's worst.** Audit carriers and promised dates for Rio de Janeiro (most late orders) and the northeast (highest late rates). Fewer late orders means fewer bad reviews.
4. **Work with the 15 low-rated, high-volume sellers.** Send the late shippers to logistics support and the on-time-but-low-rated ones to product and service quality review.
5. **Test installment options on higher-priced items.** Bigger orders go with more installments. An A/B test would show whether offering installments actually causes larger purchases.

## Dashboard

| Page | What it shows |
| --- | --- |
| **Overview** | Revenue, orders, average order and review KPIs; monthly revenue trend; top 10 categories; revenue by state. Filters for date, state and category. |
| **Customers** | Customer count, repeat rate and orders per customer; cohort retention heatmap; revenue by customer segment. |
| **Delivery** | Late rate, delivery time and reviews (on time vs late); late rate by state map; review score by delivery status. |

## How I approached it

1. **Load:** a Python script loads the 9 raw CSVs into PostgreSQL, adds foreign keys and checks every row count against the source files.
2. **Clean:** I profiled the data first, then wrote 13 cleaning rules into SQL views so the raw tables are never changed. Every rule, the rows it affects and the reason for it are in [`data_cleaning.md`](data_cleaning.md). Examples: counting real customers with `customer_unique_id`, keeping only delivered orders, and trimming the partial months at each end of the data.
3. **Analyze:** I wrote 12 questions in 5 themes, each in its own SQL file with the finding written underneath. They use CTEs, window functions (`LAG`, `NTILE`, `ROW_NUMBER`, running totals), cohort retention and RFM segmentation.
4. **Export & check:** export queries write tidy CSVs for Tableau, and the script checks the totals against the SQL results (revenue R$13,181,027; 96,211 orders; 93,104 customers).
5. **Visualize:** three Tableau dashboards with shared filters, published to Tableau Public.

## Repo layout

| Folder | Contents |
| --- | --- |
| `sql/01_setup/` | Create tables, add keys, row-count check |
| `sql/02_cleaning/` | Data profile and cleaning views |
| `sql/03_analysis/` | The 12 questions, one file per theme: sales, customers, delivery, sellers, payments |
| `sql/04_exports/` | Queries that build the CSVs for Tableau |
| `scripts/` | `load_data.py` (load into PostgreSQL) and `export_for_tableau.py` (export and check) |
| `exports/` | The exported CSVs |
| `Tableau/` | The Tableau workbook |

## Reproduce it

1. Install PostgreSQL and Python 3 (`pip install pandas psycopg2-binary`).
2. Download the dataset from [Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) and put the zip in `data/raw/`.
3. Run `python scripts/load_data.py`. It asks for your postgres password, which is never saved.
4. Run `sql/02_cleaning/02_clean_views.sql`, then the files in `sql/03_analysis/`.
5. Run `python scripts/export_for_tableau.py` and open the workbook in `Tableau/`.

## Limitations

- **Repeat rate is understated for 2018 buyers.** They had less time to come back before the data ends.
- **"Lapsed" is relative.** It means the older 60% of customers by last purchase date in this dataset, not a fixed rule like "no order in 6 months".
- **A few delivered orders have no delivery date.** They're left out of the late/on-time comparison (cleaning rule 6).
- **The installment finding is a correlation, not a proven cause.**

## Data

[Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce), licensed CC BY-NC-SA 4.0. Thanks to Olist for releasing it.

| Table | Rows |
| --- | ---: |
| geolocation | 1,000,163 |
| order_items | 112,650 |
| order_payments | 103,886 |
| customers | 99,441 |
| orders | 99,441 |
| order_reviews | 99,224 |
| products | 32,951 |
| sellers | 3,095 |
| category_translation | 71 |
