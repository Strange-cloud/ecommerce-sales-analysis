-- 02_clean_views.sql
-- Cleaning views. Each one applies the rules in data_cleaning.md (rule numbers in
-- brackets) and leaves the raw tables untouched. All analysis queries read from
-- these views, never from the raw tables.


-- ---------------------------------------------------------------------------
-- 1. clean_orders: one row per delivered order in the analysis window
--    (WORKED EXAMPLE: read this one closely before writing the others)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW clean_orders AS
SELECT
    o.order_id,
    c.customer_unique_id,                                        -- [1] the real person
    c.customer_state,
    o.order_purchase_timestamp                         AS purchased_at,
    DATE_TRUNC('month', o.order_purchase_timestamp)::DATE AS purchase_month,
    o.order_delivered_customer_date                    AS delivered_at,
    o.order_estimated_delivery_date                    AS promised_at,

    -- [6] delivery time only when there is a delivery date
    EXTRACT(EPOCH FROM o.order_delivered_customer_date - o.order_purchase_timestamp)
        / 86400.0                                      AS days_to_deliver,

    -- late = delivered after the promised date; unknown when no delivery date
    CASE
        WHEN o.order_delivered_customer_date IS NULL THEN NULL
        WHEN o.order_delivered_customer_date::DATE > o.order_estimated_delivery_date::DATE THEN TRUE
        ELSE FALSE
    END                                                AS is_late,

    -- [8] days until handed to the carrier, blank when the timestamp is impossible
    CASE
        WHEN o.order_delivered_carrier_date >= o.order_purchase_timestamp
        THEN EXTRACT(EPOCH FROM o.order_delivered_carrier_date - o.order_purchase_timestamp) / 86400.0
    END                                                AS days_to_ship
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered'                                         -- [3]
  AND o.order_purchase_timestamp >= DATE '2017-01-01'                      -- [2]
  AND o.order_purchase_timestamp <  DATE '2018-09-01';


-- ---------------------------------------------------------------------------
-- 2. clean_order_items: YOUR TURN
--    One row per item in a clean order, with the English category name.
--
--    Columns: order_id, order_item_id, product_id, category, seller_id,
--             seller_state, price, freight_value
--
--    Rules:
--      - only items whose order is in clean_orders (hint: JOIN clean_orders)
--      - [10] no category        -> 'unknown'
--      - [11] two missing names  -> pc_gamer -> 'pc_gamer',
--             portateis_cozinha_e_preparadores_de_alimentos -> 'portable_kitchen_appliances'
--
--    Hints: LEFT JOIN products and category_translation (an inner join would drop
--    items whose category has no translation). COALESCE(a, b, c) returns the first
--    value that is not NULL, and a CASE expression can supply the two hand translations.
--
--    Check when done: SELECT COUNT(*) FROM clean_order_items;
--    should be a bit over 100,000, and this should return 0 rows:
--    SELECT * FROM clean_order_items WHERE category IS NULL;
-- ---------------------------------------------------------------------------


-- ---------------------------------------------------------------------------
-- 3. clean_reviews: YOUR TURN
--    One review per clean order: the most recent one.             [9]
--
--    Columns: order_id, review_score, review_answer_timestamp
--
--    Hint: ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY review_answer_timestamp DESC)
--    numbers each order's reviews newest first; keep only row number 1.
--    Do it in a CTE or subquery, because you can't filter on a window function in
--    the same SELECT's WHERE.
--
--    Check when done: this should return 0 rows:
--    SELECT order_id FROM clean_reviews GROUP BY order_id HAVING COUNT(*) > 1;
-- ---------------------------------------------------------------------------


-- ---------------------------------------------------------------------------
-- 4. clean_payments: YOUR TURN
--    Payments for clean orders, without the 'not_defined' type.   [12]
--
--    Columns: order_id, payment_sequential, payment_type,
--             payment_installments, payment_value
--
--    Check when done: this should return no 'not_defined' row:
--    SELECT payment_type, COUNT(*) FROM clean_payments GROUP BY payment_type;
-- ---------------------------------------------------------------------------
