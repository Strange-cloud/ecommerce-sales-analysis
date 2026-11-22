-- 01_create_tables.sql
-- One table per Olist CSV file. Column names match the CSV headers exactly
-- (including Olist's own "lenght" spelling in products) so the load is a straight COPY.
-- Zip code prefixes are TEXT, not numbers, so leading zeros are kept.
-- Primary keys only where the data guarantees uniqueness; foreign keys are added
-- after loading (02_add_foreign_keys.sql) so a bad row shows up as a clear error.

DROP TABLE IF EXISTS order_reviews, order_payments, order_items, orders,
    customers, sellers, products, category_translation, geolocation CASCADE;

CREATE TABLE customers (
    customer_id              TEXT PRIMARY KEY,   -- new id for every order
    customer_unique_id       TEXT NOT NULL,      -- the real person: use this for repeat buyers
    customer_zip_code_prefix TEXT,
    customer_city            TEXT,
    customer_state           CHAR(2)
);

CREATE TABLE geolocation (
    geolocation_zip_code_prefix TEXT,
    geolocation_lat             NUMERIC,
    geolocation_lng             NUMERIC,
    geolocation_city            TEXT,
    geolocation_state           CHAR(2)
);

CREATE TABLE sellers (
    seller_id              TEXT PRIMARY KEY,
    seller_zip_code_prefix TEXT,
    seller_city            TEXT,
    seller_state           CHAR(2)
);

CREATE TABLE products (
    product_id                 TEXT PRIMARY KEY,
    product_category_name      TEXT,
    product_name_lenght        INTEGER,
    product_description_lenght INTEGER,
    product_photos_qty         INTEGER,
    product_weight_g           INTEGER,
    product_length_cm          INTEGER,
    product_height_cm          INTEGER,
    product_width_cm           INTEGER
);

CREATE TABLE category_translation (
    product_category_name         TEXT PRIMARY KEY,
    product_category_name_english TEXT
);

CREATE TABLE orders (
    order_id                      TEXT PRIMARY KEY,
    customer_id                   TEXT NOT NULL,
    order_status                  TEXT,
    order_purchase_timestamp      TIMESTAMP,
    order_approved_at             TIMESTAMP,
    order_delivered_carrier_date  TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP
);

CREATE TABLE order_items (
    order_id            TEXT NOT NULL,
    order_item_id       INTEGER NOT NULL,        -- 1, 2, 3... within an order
    product_id          TEXT NOT NULL,
    seller_id           TEXT NOT NULL,
    shipping_limit_date TIMESTAMP,
    price               NUMERIC(10, 2),
    freight_value       NUMERIC(10, 2),
    PRIMARY KEY (order_id, order_item_id)
);

CREATE TABLE order_payments (
    order_id             TEXT NOT NULL,
    payment_sequential   INTEGER NOT NULL,
    payment_type         TEXT,
    payment_installments INTEGER,
    payment_value        NUMERIC(10, 2),
    PRIMARY KEY (order_id, payment_sequential)
);

-- review_id is NOT unique in the source data, so this table has no primary key.
CREATE TABLE order_reviews (
    review_id               TEXT,
    order_id                TEXT NOT NULL,
    review_score            SMALLINT,
    review_comment_title    TEXT,
    review_comment_message  TEXT,
    review_creation_date    TIMESTAMP,
    review_answer_timestamp TIMESTAMP
);
