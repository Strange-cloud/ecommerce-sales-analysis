-- 01_data_profile.sql
-- Data quality check for every table, returned as ONE result table so it is
-- easy to read and share. Each row is a check: what was tested and how many
-- rows it found. Nothing here changes the data.
--
-- Read the "value" column like this: for "rows" checks, 0 is good and anything
-- else is something to decide on in the cleaning step.

WITH
-- Orders: status mix and date problems
order_checks AS (
    SELECT 'orders' AS area, 'status: ' || order_status AS check_name,
           COUNT(*)::TEXT AS value
    FROM orders
    GROUP BY order_status

    UNION ALL
    SELECT 'orders', 'first purchase date', MIN(order_purchase_timestamp)::DATE::TEXT FROM orders
    UNION ALL
    SELECT 'orders', 'last purchase date',  MAX(order_purchase_timestamp)::DATE::TEXT FROM orders

    UNION ALL
    SELECT 'orders', 'rows: delivered but no delivery date', COUNT(*)::TEXT
    FROM orders
    WHERE order_status = 'delivered' AND order_delivered_customer_date IS NULL

    UNION ALL
    SELECT 'orders', 'rows: has delivery date but status is not delivered', COUNT(*)::TEXT
    FROM orders
    WHERE order_status <> 'delivered' AND order_delivered_customer_date IS NOT NULL

    UNION ALL
    SELECT 'orders', 'rows: delivered before it was purchased', COUNT(*)::TEXT
    FROM orders
    WHERE order_delivered_customer_date < order_purchase_timestamp

    UNION ALL
    SELECT 'orders', 'rows: handed to carrier before purchase', COUNT(*)::TEXT
    FROM orders
    WHERE order_delivered_carrier_date < order_purchase_timestamp

    UNION ALL
    SELECT 'orders', 'rows: no approval date', COUNT(*)::TEXT
    FROM orders
    WHERE order_approved_at IS NULL

    UNION ALL
    SELECT 'orders', 'rows: no items in order_items', COUNT(*)::TEXT
    FROM orders o
    WHERE NOT EXISTS (SELECT 1 FROM order_items i WHERE i.order_id = o.order_id)

    UNION ALL
    SELECT 'orders', 'rows: no payment record', COUNT(*)::TEXT
    FROM orders o
    WHERE NOT EXISTS (SELECT 1 FROM order_payments p WHERE p.order_id = o.order_id)
),

-- Orders per month, to spot months with too little data to trust
month_checks AS (
    SELECT 'orders by month' AS area,
           TO_CHAR(DATE_TRUNC('month', order_purchase_timestamp), 'YYYY-MM') AS check_name,
           COUNT(*)::TEXT AS value
    FROM orders
    GROUP BY DATE_TRUNC('month', order_purchase_timestamp)
),

-- Customers: one id per order vs. one per real person
customer_checks AS (
    SELECT 'customers' AS area, 'customer_id values (one per order)' AS check_name,
           COUNT(DISTINCT customer_id)::TEXT AS value
    FROM customers
    UNION ALL
    SELECT 'customers', 'customer_unique_id values (real people)', COUNT(DISTINCT customer_unique_id)::TEXT
    FROM customers
),

-- Products and categories
product_checks AS (
    SELECT 'products' AS area, 'rows: no category' AS check_name, COUNT(*)::TEXT AS value
    FROM products
    WHERE product_category_name IS NULL

    UNION ALL
    SELECT 'products', 'rows: no weight or size', COUNT(*)::TEXT
    FROM products
    WHERE product_weight_g IS NULL OR product_length_cm IS NULL

    UNION ALL
    SELECT 'products', 'categories with no English name: ' || COALESCE(STRING_AGG(DISTINCT p.product_category_name, ', '), 'none'),
           COUNT(DISTINCT p.product_category_name)::TEXT
    FROM products p
    LEFT JOIN category_translation t USING (product_category_name)
    WHERE p.product_category_name IS NOT NULL AND t.product_category_name IS NULL
),

-- Order items and payments
money_checks AS (
    SELECT 'order_items' AS area, 'rows: price of zero or less' AS check_name, COUNT(*)::TEXT AS value
    FROM order_items
    WHERE price <= 0

    UNION ALL
    SELECT 'order_payments', 'payment type: ' || payment_type, COUNT(*)::TEXT
    FROM order_payments
    GROUP BY payment_type

    UNION ALL
    SELECT 'order_payments', 'rows: payment value of zero', COUNT(*)::TEXT
    FROM order_payments
    WHERE payment_value = 0

    UNION ALL
    -- Does what the customer paid match items + shipping? Off by more than 1 real counts.
    SELECT 'order_payments', 'orders where payments differ from items + freight by > 1', COUNT(*)::TEXT
    FROM (
        SELECT order_id, SUM(price + freight_value) AS item_total
        FROM order_items GROUP BY order_id
    ) i
    JOIN (
        SELECT order_id, SUM(payment_value) AS paid
        FROM order_payments GROUP BY order_id
    ) p USING (order_id)
    WHERE ABS(i.item_total - p.paid) > 1
),

-- Reviews: duplicates
review_checks AS (
    SELECT 'order_reviews' AS area, 'review_id values used more than once' AS check_name,
           COUNT(*)::TEXT AS value
    FROM (SELECT review_id FROM order_reviews GROUP BY review_id HAVING COUNT(*) > 1) d

    UNION ALL
    SELECT 'order_reviews', 'orders with more than one review', COUNT(*)::TEXT
    FROM (SELECT order_id FROM order_reviews GROUP BY order_id HAVING COUNT(*) > 1) d

    UNION ALL
    SELECT 'order_reviews', 'rows: review score outside 1 to 5', COUNT(*)::TEXT
    FROM order_reviews
    WHERE review_score NOT BETWEEN 1 AND 5
),

-- Geolocation: many rows per zip prefix
geo_checks AS (
    SELECT 'geolocation' AS area, 'distinct zip prefixes (table has 1,000,163 rows)' AS check_name,
           COUNT(DISTINCT geolocation_zip_code_prefix)::TEXT AS value
    FROM geolocation
)

SELECT area, check_name, value
FROM (
    SELECT * FROM order_checks
    UNION ALL SELECT * FROM customer_checks
    UNION ALL SELECT * FROM product_checks
    UNION ALL SELECT * FROM money_checks
    UNION ALL SELECT * FROM review_checks
    UNION ALL SELECT * FROM geo_checks
    UNION ALL SELECT * FROM month_checks
) all_checks
ORDER BY area = 'orders by month', area, check_name;   -- monthly counts go last
