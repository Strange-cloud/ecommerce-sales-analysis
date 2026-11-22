-- One row per cohort (first-purchase month) per month since first purchase.
-- Same logic as Q5, without the final averaging, for the Tableau heatmap.
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
)
SELECT cohort_month,
       months_since_first,
       COUNT(*)                                                         AS customers,
       FIRST_VALUE(COUNT(*)) OVER (PARTITION BY cohort_month
                                   ORDER BY months_since_first)         AS cohort_size,
       ROUND(100.0 * COUNT(*) / FIRST_VALUE(COUNT(*)) OVER (
             PARTITION BY cohort_month ORDER BY months_since_first), 2) AS retention_pct
FROM activity
GROUP BY cohort_month, months_since_first
ORDER BY cohort_month, months_since_first
