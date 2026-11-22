-- One row per seller: revenue, revenue decile (Q9), reviews and late rate (Q10).
WITH seller_orders AS (
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
SELECT *,
       NTILE(10) OVER (ORDER BY revenue DESC) AS revenue_decile
FROM seller_stats
ORDER BY revenue DESC
