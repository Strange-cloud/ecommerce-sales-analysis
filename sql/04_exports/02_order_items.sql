-- One row per item in a clean order, with the order's month and state for filtering.
SELECT i.order_id,
       i.order_item_id,
       o.purchase_month,
       o.customer_state,
       i.category,
       i.seller_id,
       i.seller_state,
       i.price,
       i.freight_value
FROM clean_order_items i
JOIN clean_orders o ON o.order_id = i.order_id
ORDER BY o.purchased_at, i.order_id, i.order_item_id
