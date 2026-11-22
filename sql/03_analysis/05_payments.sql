-- 05_payments.sql
-- Payment questions. Uses clean_payments ('not_defined' removed, cleaning rule 12).
-- Order value comes from item prices (clean_order_items), not payments, because
-- payments include installment interest and vouchers (cleaning rule 4).


-- ---------------------------------------------------------------------------
-- Q11. What is the mix of payment types, and how does it relate to order value?
-- Finding:Credit card = 77% of orders, boleto (bank slip) = 19.9%: one in five
--          customers pays without a card, so boleto is essential. Avg payment:
--          card R$162, boleto R$144, debit R$140, voucher R$63 (usually partial).
--          Shares sum to 102.2%: ~2% of orders split across two methods.
-- ---------------------------------------------------------------------------
SELECT payment_type,
       COUNT(DISTINCT order_id)                                        AS orders,
       ROUND(100.0 * COUNT(DISTINCT order_id)
                   / (SELECT COUNT(DISTINCT order_id) FROM clean_payments), 1) AS pct_of_orders,
       ROUND(AVG(payment_value), 2)                                    AS avg_payment
FROM clean_payments
GROUP BY payment_type
ORDER BY orders DESC;


-- ---------------------------------------------------------------------------
-- Q12. Do customers who pay in installments spend more per order?
-- Finding: Avg order value rises with installments: R$83 paid in full,
--          R$114 (2-3), R$157 (4-6), R$301 (7+), 3.6x. 66.8% of card orders
--          use installments. Installment options may unlock bigger purchases
--          (correlation, not proven cause: worth an A/B test).
-- ---------------------------------------------------------------------------
WITH order_value AS (                       -- what each order cost (items only)
    SELECT order_id, SUM(price) AS order_value
    FROM clean_order_items
    GROUP BY order_id
),
card_orders AS (                            -- installments used on each card order
    SELECT order_id, MAX(payment_installments) AS installments
    FROM clean_payments
    WHERE payment_type = 'credit_card'
    GROUP BY order_id
)
SELECT CASE
           WHEN c.installments <= 1 THEN '1 (paid in full)'
           WHEN c.installments <= 3 THEN '2-3'
           WHEN c.installments <= 6 THEN '4-6'
           ELSE                          '7 or more'
       END                                                   AS installments,
       COUNT(*)                                              AS orders,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)    AS pct_of_card_orders,
       ROUND(AVG(v.order_value), 2)                          AS avg_order_value
FROM card_orders c
JOIN order_value v ON v.order_id = c.order_id
GROUP BY 1
ORDER BY MIN(c.installments);