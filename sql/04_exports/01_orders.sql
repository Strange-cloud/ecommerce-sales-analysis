-- One row per clean order: everything the overview, delivery and customer pages need.
WITH items AS (
    SELECT order_id,
           COUNT(*)           AS items,
           SUM(price)         AS order_value,
           SUM(freight_value) AS freight
    FROM clean_order_items
    GROUP BY order_id
),
payments AS (                                   -- main payment method = the largest payment
    SELECT order_id,
           (ARRAY_AGG(payment_type ORDER BY payment_value DESC))[1] AS payment_type,
           MAX(payment_installments)                                AS installments
    FROM clean_payments
    GROUP BY order_id
),
per_customer AS (                               -- RFM segment, same rules as Q6
    SELECT o.customer_unique_id,
           DATE '2018-09-01' - MAX(o.purchased_at)::DATE AS days_since_last,
           COUNT(DISTINCT o.order_id)                    AS orders,
           SUM(i.price)                                  AS total_spent
    FROM clean_orders o
    JOIN clean_order_items i ON i.order_id = o.order_id
    GROUP BY o.customer_unique_id
),
segments AS (
    SELECT customer_unique_id,
           CASE
               WHEN orders > 1 AND m_score >= 4   THEN 'Loyal big spenders'
               WHEN orders > 1                    THEN 'Repeat buyers'
               WHEN m_score >= 4 AND r_score >= 4 THEN 'New big spenders'
               WHEN m_score >= 4                  THEN 'Lapsed big spenders'
               WHEN r_score >= 4                  THEN 'New small spenders'
               ELSE                                    'Lapsed small spenders'
           END AS segment
    FROM (
        SELECT *,
               NTILE(5) OVER (ORDER BY days_since_last DESC) AS r_score,
               NTILE(5) OVER (ORDER BY total_spent)          AS m_score
        FROM per_customer
    ) scored
)
SELECT o.order_id,
       o.customer_unique_id,
       o.customer_state,
       o.purchase_month,
       o.purchased_at::DATE                         AS purchase_date,
       i.items,
       i.order_value,
       i.freight,
       ROUND(o.days_to_deliver::NUMERIC, 1)         AS days_to_deliver,
       CASE WHEN o.is_late THEN 'Late'
            WHEN NOT o.is_late THEN 'On time' END   AS delivery_status,
       CASE WHEN o.is_late THEN 1
            WHEN NOT o.is_late THEN 0 END           AS late_flag,
       r.review_score,
       p.payment_type,
       p.installments,
       s.segment
FROM clean_orders o
JOIN items i              ON i.order_id = o.order_id
LEFT JOIN clean_reviews r ON r.order_id = o.order_id
LEFT JOIN payments p      ON p.order_id = o.order_id
LEFT JOIN segments s      ON s.customer_unique_id = o.customer_unique_id
ORDER BY o.purchased_at
