SELECT o.order_id, c.customer_name, c.city, o.order_date
FROM orders o
INNER JOIN customers c ON c.customer_id = o.customer_id
ORDER BY o.order_id;

SELECT oi.order_item_id, oi.order_id,
       p.product_name, p.category, p.price, oi.quantity
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
ORDER BY oi.order_item_id;

SELECT c.customer_id, c.customer_name, o.order_id, o.order_date
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
ORDER BY c.customer_id, o.order_date;


SELECT c.customer_id, c.customer_name, o.order_id, o.order_date
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
ORDER BY c.customer_id, o.order_date;

WITH customer_totals AS (
  SELECT c.customer_id,
         c.customer_name,
         SUM(oi.quantity * p.price) AS total_spend
  FROM customers c
  JOIN orders o       ON o.customer_id = c.customer_id
  JOIN order_items oi ON oi.order_id   = o.order_id
  JOIN products p     ON p.product_id  = oi.product_id
  GROUP BY c.customer_id, c.customer_name
)
SELECT customer_id, customer_name, total_spend
FROM customer_totals
WHERE total_spend > (SELECT AVG(total_spend) FROM customer_totals)
ORDER BY total_spend DESC;

WITH customer_totals AS (
  SELECT c.customer_id, c.customer_name,
         SUM(oi.quantity * p.price) AS total_spend
  FROM customers c
  JOIN orders o       ON o.customer_id = c.customer_id
  JOIN order_items oi ON oi.order_id   = o.order_id
  JOIN products p     ON p.product_id  = oi.product_id
  GROUP BY c.customer_id, c.customer_name
)
SELECT customer_id, customer_name, total_spend,
       RANK() OVER (ORDER BY total_spend DESC) AS spend_rank
FROM customer_totals
ORDER BY spend_rank;


SELECT customer_id, order_id, order_date,
       ROW_NUMBER() OVER (
         PARTITION BY customer_id
         ORDER BY order_date, order_id
       ) AS order_number
FROM orders
ORDER BY customer_id, order_number;


WITH order_revenue AS (
  SELECT o.order_id, o.order_date,
         SUM(oi.quantity * p.price) AS revenue
  FROM orders o
  JOIN order_items oi ON oi.order_id  = o.order_id
  JOIN products p     ON p.product_id = oi.product_id
  GROUP BY o.order_id, o.order_date
)
SELECT order_id, order_date, revenue,
       SUM(revenue) OVER (
         ORDER BY order_date, order_id
         ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ) AS running_total
FROM order_revenue
ORDER BY order_date, order_id;

WITH ordered AS (
  SELECT customer_id, order_id, order_date,
         LAG(order_date) OVER (
           PARTITION BY customer_id
           ORDER BY order_date, order_id
         ) AS prev_order_date,
         COUNT(*) OVER (PARTITION BY customer_id) AS order_count
  FROM orders
)
SELECT o.customer_id, c.customer_name, o.order_id, o.order_date,
       o.prev_order_date,
       o.order_date - o.prev_order_date AS days_since_prev
FROM ordered o
JOIN customers c ON c.customer_id = o.customer_id
WHERE o.order_count > 1
ORDER BY o.customer_id, o.order_date, o.order_id;
