-- 02_clean_views.sql
-- Cleaning views. Each one applies the rules in data_cleaning.md (rule numbers in
-- brackets) and leaves the raw tables untouched. All analysis queries read from
-- these views, never from the raw tables.


-- ---------------------------------------------------------------------------
-- 1. clean_orders: one row per delivered order in the analysis window
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
-- 2. clean_order_items: one row per item in a clean order, English category
--    [10] no category -> 'unknown'   [11] two categories translated by hand
--    LEFT JOINs so an item is never dropped for a missing category.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW clean_order_items AS
SELECT
    i.order_id,
    i.order_item_id,
    i.product_id,
    COALESCE(
        t.product_category_name_english,
        CASE p.product_category_name
            WHEN 'pc_gamer' THEN 'pc_gamer'
            WHEN 'portateis_cozinha_e_preparadores_de_alimentos' THEN 'portable_kitchen_appliances'
        END,
        'unknown'
    ) AS category,
    i.seller_id,
    s.seller_state,
    i.price,
    i.freight_value
FROM order_items i
JOIN clean_orders o ON o.order_id = i.order_id
LEFT JOIN products p ON p.product_id = i.product_id
LEFT JOIN category_translation t ON t.product_category_name = p.product_category_name
JOIN sellers s ON s.seller_id = i.seller_id;


-- ---------------------------------------------------------------------------
-- 3. clean_reviews: one review per clean order, the most recent one    [9]
--    ROW_NUMBER numbers each order's reviews newest first; the CTE is needed
--    because WHERE runs before window functions are calculated.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW clean_reviews AS
WITH ranked AS (
    SELECT order_id, review_score, review_answer_timestamp,
           ROW_NUMBER() OVER (
               PARTITION BY order_id
               ORDER BY review_answer_timestamp DESC
           ) AS review_rank
    FROM order_reviews
)
SELECT r.order_id, r.review_score, r.review_answer_timestamp
FROM ranked r
JOIN clean_orders o ON o.order_id = r.order_id
WHERE r.review_rank = 1;


-- ---------------------------------------------------------------------------
-- 4. clean_payments: payments for clean orders, without 'not_defined'   [12]
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW clean_payments AS
SELECT p.order_id,
       p.payment_sequential,
       p.payment_type,
       p.payment_installments,
       p.payment_value
FROM order_payments p
JOIN clean_orders o ON o.order_id = p.order_id
WHERE p.payment_type <> 'not_defined';


-- ---------------------------------------------------------------------------
-- Checks (run one at a time after creating the views)
-- ---------------------------------------------------------------------------

-- Items whose category needed fixing: 1,535 no category, 8 pc_gamer, 14 portateis...
SELECT p.product_category_name, COUNT(*) AS items
FROM order_items i
JOIN clean_orders o ON o.order_id = i.order_id
LEFT JOIN products p ON p.product_id = i.product_id
LEFT JOIN category_translation t ON t.product_category_name = p.product_category_name
WHERE t.product_category_name_english IS NULL
GROUP BY p.product_category_name;

SELECT COUNT(*) FROM clean_order_items;                          -- 109,880
SELECT * FROM clean_order_items WHERE category IS NULL;          -- 0 rows
SELECT order_id FROM clean_reviews GROUP BY order_id HAVING COUNT(*) > 1;   -- 0 rows
SELECT payment_type, COUNT(*) FROM clean_payments GROUP BY payment_type;    -- 4 types, no not_defined
