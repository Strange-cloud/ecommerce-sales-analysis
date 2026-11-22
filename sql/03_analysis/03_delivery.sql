-- 03_delivery.sql
-- Delivery and review questions. Uses clean_orders (is_late, days_to_deliver)
-- and clean_reviews (one review per order). Orders with no delivery date are
-- left out of delivery measures (cleaning rule 6).


-- ---------------------------------------------------------------------------
-- Q7. What share of orders arrived after the promised date, by state?
-- Finding: ~6.8% of orders arrive late (avg 12.5 days). SP: 4.5% late, 8.7 days.
--          Northeast: 12.8% late, 20 days (AL worst: 21.5%, 24.5 days),
--          supporting the Q3 shipping explanation. RJ is the outlier: 12.1%
--          late despite being near sellers = ~23% of all late orders.
--          Late != slow: AM averages 26 days but is only 2.8% late (padded promise).
-- ---------------------------------------------------------------------------
-- By state
SELECT customer_state,
       COUNT(*)                                                    AS orders,
       ROUND(100.0 * COUNT(*) FILTER (WHERE is_late) / COUNT(*), 1) AS late_pct,
       ROUND(AVG(days_to_deliver), 1)                              AS avg_days
FROM clean_orders
WHERE is_late IS NOT NULL
GROUP BY customer_state
HAVING COUNT(*) >= 100
ORDER BY late_pct DESC;

-- Overall benchmark
SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE is_late) / COUNT(*), 1) AS late_pct,
       ROUND(AVG(days_to_deliver), 1)                              AS avg_days
FROM clean_orders
WHERE is_late IS NOT NULL;


-- ---------------------------------------------------------------------------
-- Q8. Do late deliveries get lower review scores?
-- Finding: Late orders average 2.27 stars vs 4.29 on time; 62.4% of late orders
--          get a 1-2 star review vs 9.2% (6.8x). Late orders are 6.7% of orders
--          but ~33% of all bad reviews: delivery is the biggest driver of
--          unhappy customers.
-- ---------------------------------------------------------------------------
SELECT CASE WHEN o.is_late THEN 'Late' ELSE 'On time' END   AS delivery,
       COUNT(*)                                             AS orders,
       ROUND(AVG(r.review_score), 2)                        AS avg_review,
       ROUND(100.0 * COUNT(*) FILTER (WHERE r.review_score <= 2) / COUNT(*), 1) AS pct_bad_reviews
FROM clean_orders o
JOIN clean_reviews r ON r.order_id = o.order_id
WHERE o.is_late IS NOT NULL
GROUP BY CASE WHEN o.is_late THEN 'Late' ELSE 'On time' END;