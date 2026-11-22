-- 02_add_foreign_keys.sql
-- Run after loading. Each constraint proves a join is safe; if one fails,
-- the error names the rows that break it, which becomes a cleaning note.
-- products -> category_translation is left out on purpose: a few categories
-- have no English name (handled in the cleaning step).

ALTER TABLE orders
    ADD CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id) REFERENCES customers (customer_id);

ALTER TABLE order_items
    ADD CONSTRAINT fk_items_order   FOREIGN KEY (order_id)   REFERENCES orders (order_id),
    ADD CONSTRAINT fk_items_product FOREIGN KEY (product_id) REFERENCES products (product_id),
    ADD CONSTRAINT fk_items_seller  FOREIGN KEY (seller_id)  REFERENCES sellers (seller_id);

ALTER TABLE order_payments
    ADD CONSTRAINT fk_payments_order FOREIGN KEY (order_id) REFERENCES orders (order_id);

ALTER TABLE order_reviews
    ADD CONSTRAINT fk_reviews_order FOREIGN KEY (order_id) REFERENCES orders (order_id);

-- Indexes on the join keys that are not already primary keys
CREATE INDEX idx_orders_customer   ON orders (customer_id);
CREATE INDEX idx_customers_unique  ON customers (customer_unique_id);
CREATE INDEX idx_items_product     ON order_items (product_id);
CREATE INDEX idx_items_seller      ON order_items (seller_id);
CREATE INDEX idx_reviews_order     ON order_reviews (order_id);
