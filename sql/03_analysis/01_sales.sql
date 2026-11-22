-- 01_sales.sql
-- Sales questions. Every query reads the cleaning views (clean_orders,
-- clean_order_items), so the rules in data_cleaning.md apply automatically:
-- delivered orders only, Jan 2017 to Aug 2018, revenue = item price (R$).


-- ---------------------------------------------------------------------------
-- Q1. How did monthly revenue and order count change, and what was the
--     month-over-month growth?
-- Finding: Revenue grew 141% (Jan-Aug 2018 vs 2017), driven by order volume
--          (+140%) while average order value stayed flat (~R$137). Nov 2017
--          (Black Friday) was the peak month; growth plateaued through 2018.
-- ---------------------------------------------------------------------------
WITH monthly AS (
    SELECT o.purchase_month,
           COUNT(DISTINCT o.order_id)                            AS orders,
           SUM(i.price)                                          AS revenue,
           ROUND(SUM(i.price) / COUNT(DISTINCT o.order_id), 2)   AS avg_order_value
    FROM clean_orders o
    JOIN clean_order_items i ON i.order_id = o.order_id
    GROUP BY o.purchase_month
)
SELECT purchase_month,
       orders,
       revenue,
       avg_order_value,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY purchase_month))
                   / LAG(revenue) OVER (ORDER BY purchase_month), 1) AS revenue_growth_pct
FROM monthly
ORDER BY purchase_month;


-- ---------------------------------------------------------------------------
-- Q2. Which product categories bring in the most revenue?
-- Finding: Top 10 categories = 62.5% of revenue. Health & beauty leads (9.3%).
--          Watches & gifts is #2 on price (R$199/item) with 38% fewer items;
--          bed, bath & table sells the most items but at R$93 each.
-- ---------------------------------------------------------------------------
SELECT category,
       SUM(price)                                              AS revenue,
       COUNT(*)                                                AS items_sold,
       ROUND(100.0 * SUM(price) / SUM(SUM(price)) OVER (), 1)  AS pct_of_revenue
FROM clean_order_items
GROUP BY category
ORDER BY revenue DESC
LIMIT 10;


-- ---------------------------------------------------------------------------
-- Q3. How does average order value differ by state?
-- Finding: SP is 42% of orders but has the lowest average order (R$125).
--          SP+RJ+MG = 66.6% of orders. Far north/northeast states spend
--          50-75% more per order (PB R$218, AL R$199), likely because shipping
--          costs make only bigger purchases worthwhile there (tested in Q7-Q8).
--          (HAVING >= 100 orders excludes AC, AP, RR: 187 orders.)
-- ---------------------------------------------------------------------------
SELECT o.customer_state,
       COUNT(DISTINCT o.order_id)                            AS orders,
       SUM(i.price)                                          AS revenue,
       ROUND(SUM(i.price) / COUNT(DISTINCT o.order_id), 2)   AS avg_order_value
FROM clean_orders o
JOIN clean_order_items i ON i.order_id = o.order_id
GROUP BY o.customer_state
HAVING COUNT(DISTINCT o.order_id) >= 100
ORDER BY orders DESC;
