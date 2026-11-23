-- One row per cohort (first-purchase month) per month since first purchase.
-- Same logic as Q5, without the final averaging, for the Tableau heatmap.
-- The grid is complete: a month that has already happened but had no returning
-- customers gets a row with 0, so the heatmap shows 0.00% instead of a blank.
-- Months after the last month of data (Aug 2018) are not included.
WITH first_purchase AS (
    SELECT customer_unique_id, MIN(purchase_month) AS cohort_month
    FROM clean_orders
    GROUP BY customer_unique_id
),
activity AS (
    SELECT DISTINCT
           o.customer_unique_id,
           f.cohort_month,
           (EXTRACT(YEAR  FROM AGE(o.purchase_month, f.cohort_month)) * 12
          + EXTRACT(MONTH FROM AGE(o.purchase_month, f.cohort_month)))::INT AS months_since_first
    FROM clean_orders o
    JOIN first_purchase f ON f.customer_unique_id = o.customer_unique_id
),
counts AS (                                     -- customers active per cohort and month
    SELECT cohort_month, months_since_first, COUNT(*) AS customers
    FROM activity
    GROUP BY cohort_month, months_since_first
),
cohorts AS (                                    -- cohort size = customers in month 0
    SELECT cohort_month, customers AS cohort_size
    FROM counts
    WHERE months_since_first = 0
),
grid AS (                                       -- every month from 0 up to the last month of data
    SELECT c.cohort_month,
           c.cohort_size,
           m AS months_since_first
    FROM cohorts c
    CROSS JOIN LATERAL generate_series(
        0,
        (SELECT (EXTRACT(YEAR  FROM AGE(MAX(purchase_month), c.cohort_month)) * 12
               + EXTRACT(MONTH FROM AGE(MAX(purchase_month), c.cohort_month)))::INT
         FROM clean_orders)
    ) AS m
)
SELECT g.cohort_month,
       g.months_since_first,
       COALESCE(ct.customers, 0)                                  AS customers,
       g.cohort_size,
       ROUND(100.0 * COALESCE(ct.customers, 0) / g.cohort_size, 2) AS retention_pct
FROM grid g
LEFT JOIN counts ct
       ON ct.cohort_month       = g.cohort_month
      AND ct.months_since_first = g.months_since_first
ORDER BY g.cohort_month, g.months_since_first
