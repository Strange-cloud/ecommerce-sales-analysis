-- 02_customers.sql
-- Customer questions. Customers are counted with customer_unique_id (the real
-- person), never customer_id, which changes with every order (cleaning rule 1).


-- ---------------------------------------------------------------------------
-- Q4. What share of customers ever buy a second time?
-- Finding: Only 3.0% of 93,104 customers ordered more than once (97% bought
--          once). Growth has relied almost entirely on new customers.
--          Caveat: 2018 buyers had little time to return before the data ends.
-- ---------------------------------------------------------------------------
-- Repeat rate
WITH per_customer AS (
    SELECT customer_unique_id, COUNT(*) AS orders
    FROM clean_orders
    GROUP BY customer_unique_id
)
SELECT COUNT(*)                                                         AS customers,
       COUNT(*) FILTER (WHERE orders > 1)                               AS repeat_customers,
       ROUND(100.0 * COUNT(*) FILTER (WHERE orders > 1) / COUNT(*), 1)  AS repeat_rate_pct
FROM per_customer;

-- Breakdown: customers by number of orders
WITH per_customer AS (
    SELECT customer_unique_id, COUNT(*) AS orders
    FROM clean_orders
    GROUP BY customer_unique_id
)
SELECT orders AS orders_per_customer,
       COUNT(*) AS customers
FROM per_customer
GROUP BY orders
ORDER BY orders;


-- ---------------------------------------------------------------------------
-- Q5. Of customers who first bought in a given month, how many came back
--     in later months? (cohort retention)
-- Finding: Only ~0.5% of a cohort returns the month after their first purchase;
--          it falls to ~0.25% by month 3 and then holds steady. The first
--          30-60 days are the window to win a second order.
-- ---------------------------------------------------------------------------
WITH first_purchase AS (            -- 1. each customer's first month = their cohort
    SELECT customer_unique_id, MIN(purchase_month) AS cohort_month
    FROM clean_orders
    GROUP BY customer_unique_id
),
activity AS (                       -- 2. every month each customer bought, as "months since first"
    SELECT DISTINCT
           o.customer_unique_id,
           f.cohort_month,
           (EXTRACT(YEAR  FROM AGE(o.purchase_month, f.cohort_month)) * 12
          + EXTRACT(MONTH FROM AGE(o.purchase_month, f.cohort_month)))::INT AS months_since_first
    FROM clean_orders o
    JOIN first_purchase f ON f.customer_unique_id = o.customer_unique_id
),
cohorts AS (                        -- 3. % of each cohort active N months later
    SELECT cohort_month,
           months_since_first,
           COUNT(*) AS customers,
           ROUND(100.0 * COUNT(*) / FIRST_VALUE(COUNT(*)) OVER (
                 PARTITION BY cohort_month ORDER BY months_since_first), 2) AS retention_pct
    FROM activity
    GROUP BY cohort_month, months_since_first
)
SELECT months_since_first,          -- 4. summary: average across all cohorts
       COUNT(*)                      AS cohorts,
       SUM(customers)                AS customers_returning,
       ROUND(AVG(retention_pct), 2)  AS avg_retention_pct
FROM cohorts
WHERE months_since_first BETWEEN 1 AND 6
GROUP BY months_since_first
ORDER BY months_since_first;


-- ---------------------------------------------------------------------------
-- Q6. Which customers are most valuable? (RFM: recency, frequency, monetary)
-- Finding: Big spenders (top 40% by spend) = 76% of revenue. "Lapsed big
--          spenders" (20,721 one-time buyers, avg R$268) hold 42% of revenue:
--          the win-back target. "New big spenders" (14,395) are the group to
--          reach within 60 days. Only 2,125 loyal big spenders (avg R$318).
-- Note: Frequency barely varies (97% one-time), so RFM uses R and M quintiles
--       plus a repeat-buyer flag.
-- ---------------------------------------------------------------------------
WITH per_customer AS (
    SELECT o.customer_unique_id,
           DATE '2018-09-01' - MAX(o.purchased_at)::DATE  AS days_since_last,
           COUNT(DISTINCT o.order_id)                     AS orders,
           SUM(i.price)                                   AS total_spent
    FROM clean_orders o
    JOIN clean_order_items i ON i.order_id = o.order_id
    GROUP BY o.customer_unique_id
),
scored AS (
    SELECT *,
           NTILE(5) OVER (ORDER BY days_since_last DESC) AS r_score,   -- 5 = most recent
           NTILE(5) OVER (ORDER BY total_spent)          AS m_score    -- 5 = biggest spenders
    FROM per_customer
),
segmented AS (
    SELECT *,
           CASE
               WHEN orders > 1 AND m_score >= 4   THEN 'Loyal big spenders'
               WHEN orders > 1                    THEN 'Repeat buyers'
               WHEN m_score >= 4 AND r_score >= 4 THEN 'New big spenders'
               WHEN m_score >= 4                  THEN 'Lapsed big spenders'
               WHEN r_score >= 4                  THEN 'New small spenders'
               ELSE                                    'Lapsed small spenders'
           END AS segment
    FROM scored
)
SELECT segment,
       COUNT(*)                                                           AS customers,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)                 AS pct_customers,
       SUM(total_spent)                                                   AS revenue,
       ROUND(100.0 * SUM(total_spent) / SUM(SUM(total_spent)) OVER (), 1) AS pct_revenue,
       ROUND(AVG(total_spent), 2)                                         AS avg_spent
FROM segmented
GROUP BY segment
ORDER BY revenue DESC;