-- 04_sellers.sql
-- Seller questions. Seller revenue = item price from clean_order_items;
-- seller reviews come from clean_reviews (one review per order).


-- ---------------------------------------------------------------------------
-- Q9. What share of revenue comes from the top 10% of sellers?
-- Finding:Top 10% of sellers (295 of 2,945) = 67% of revenue; top 20% = 82%.
--          Bottom 50% = 3.3% combined. Avg top-decile seller R$30K vs R$46 for
--          the bottom decile: high dependence on a small group of sellers.
-- ---------------------------------------------------------------------------
WITH seller_revenue AS (
    SELECT seller_id, SUM(price) AS revenue
    FROM clean_order_items
    GROUP BY seller_id
),
ranked AS (
    SELECT seller_id, revenue,
           NTILE(10) OVER (ORDER BY revenue DESC) AS decile    -- 1 = top 10% of sellers
    FROM seller_revenue
)
SELECT decile,
       COUNT(*)                                                    AS sellers,
       SUM(revenue)                                                AS revenue,
       ROUND(100.0 * SUM(revenue) / SUM(SUM(revenue)) OVER (), 1)  AS pct_of_revenue,
       ROUND(100.0 * SUM(SUM(revenue)) OVER (ORDER BY decile)
                   / SUM(SUM(revenue)) OVER (), 1)                 AS cumulative_pct
FROM ranked
GROUP BY decile
ORDER BY decile;


-- ---------------------------------------------------------------------------
-- Q10. Which sellers have high sales but poor reviews?
-- Finding:15 sellers with 100+ orders average under 3.8 stars (marketplace
--          avg 4.16). The largest, 7c67e144 (SP, R$187K, ~1.4% of revenue),
--          averages 3.50 with 25% bad reviews: top priority. Worst: 1ca7077d
--          at 2.39 stars (60% bad). 8 of 15 have above-average late rates
--          (shipping problem); 7 deliver on time but still rate badly
--          (product/service problem): same symptom, different fixes.
-- ---------------------------------------------------------------------------
WITH seller_orders AS (            -- one row per seller per order (avoids double-counting reviews)
    SELECT seller_id, seller_state, order_id, SUM(price) AS revenue
    FROM clean_order_items
    GROUP BY seller_id, seller_state, order_id
),
seller_stats AS (
    SELECT so.seller_id,
           so.seller_state,
           COUNT(*)                                                     AS orders,
           SUM(so.revenue)                                              AS revenue,
           ROUND(AVG(r.review_score), 2)                                AS avg_review,
           ROUND(100.0 * COUNT(*) FILTER (WHERE r.review_score <= 2)
                       / NULLIF(COUNT(r.review_score), 0), 1)           AS pct_bad_reviews,
           ROUND(100.0 * COUNT(*) FILTER (WHERE o.is_late)
                       / NULLIF(COUNT(o.is_late), 0), 1)                AS late_pct
    FROM seller_orders so
    JOIN clean_orders o       ON o.order_id = so.order_id
    LEFT JOIN clean_reviews r ON r.order_id = so.order_id
    GROUP BY so.seller_id, so.seller_state
)
SELECT *
FROM seller_stats
WHERE orders >= 100          -- big enough to matter
  AND avg_review < 3.8       -- clearly below the 4.16 marketplace average
ORDER BY revenue DESC
LIMIT 15;