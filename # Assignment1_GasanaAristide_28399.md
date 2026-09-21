# Assignment 1: Online Retail Order Analysis with SQL Joins, CTEs, and Window Functions

**Name:** Gasana Aristide
**Student ID:** 28399
**DBMS Used:** PostgreSQL

## Summary

This assignment analyzes a small online retail dataset made up of four related tables — `customers`, `orders`, `order_items`, and `products`. The queries progress from basic table joins, to a `LEFT JOIN` for finding unmatched records, to CTE-based aggregations, and finally to window functions (`RANK`, `ROW_NUMBER`, `SUM() OVER`, `LAG()`) for ranking, running totals, and time-between-orders analysis.

## Business Scenario

The dataset represents a small **online store**. Customers place orders, each order contains one or more order items, and each order item references a product with a price and category. The business wants to understand:

- Which customers ordered what, and where they're located
- What products and quantities make up each order
- Which customers have never placed an order (useful for re-engagement marketing)
- Who the top-spending customers are, and how they rank against each other
- How customer order activity accumulates over time (running revenue, days between repeat orders)

These are the kinds of questions a store's marketing and operations teams would ask to identify loyal customers, spot inactive ones, and track revenue trends.

## How to Run

1. Install PostgreSQL (or your chosen DBMS).
2. Run `schema_and_data.sql` to create the tables and insert the sample data.
3. Run `queries.sql` (this file) to execute all queries in order.

## Queries and Explanations

### Query 1: JOIN – Orders with Customer Details

```sql
SELECT o.order_id, c.customer_name, c.city, o.order_date
FROM orders o
INNER JOIN customers c ON c.customer_id = o.customer_id
ORDER BY o.order_id;
```

**Explanation:** Uses an `INNER JOIN` to combine each order with the customer who placed it. An inner join is appropriate here because we only care about orders that have a valid, matching customer — there's no need to show unmatched rows.

**Result:** A flat list of every order together with the customer's name, city, and the date the order was placed.

**Business interpretation:** This gives the business a simple order log — useful for customer service lookups ("which orders did this customer place, and when?") or for seeing geographic spread of orders by city.

---

### Query 2: JOIN – Order Line Items with Product Details

```sql
SELECT oi.order_item_id, oi.order_id,
       p.product_name, p.category, p.price, oi.quantity
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
ORDER BY oi.order_item_id;
```

**Explanation:** Joins `order_items` to `products` to attach human-readable product details (name, category, price) to each line item, rather than just showing raw product IDs and quantities.

**Result:** Every line item across all orders, showing what product was bought, its category and unit price, and how many units were ordered.

**Business interpretation:** This is the detailed "shopping cart contents" view — it lets the business see which products and categories are actually moving, and at what price point, item by item.

---

### Query 3: LEFT JOIN – All Customers, Including Those With No Orders

```sql
SELECT c.customer_id, c.customer_name, o.order_id, o.order_date
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
ORDER BY c.customer_id, o.order_date;
```

**Explanation:** A `LEFT JOIN` keeps every row from `customers`, even when there's no matching row in `orders`. Customers with no orders will show `NULL` for `order_id` and `order_date`. This is the key difference from an `INNER JOIN`, which would silently drop those customers.

**Result:** Every customer appears at least once; customers with orders show one row per order, and customers with zero orders show a single row with `NULL` order fields.

**Business interpretation:** This identifies customers who signed up but have never purchased — a target list for a "welcome back" or first-purchase incentive campaign.

> **Note:** Query 4 below is currently an exact duplicate of Query 3. Consider replacing it with a different query (e.g., a three-way join across customers, orders, and order items) or removing it before submitting.



---

### Query 5: CTE – Customers Who Spent Above the Average

```sql
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
```

**Explanation:** The CTE `customer_totals` first computes each customer's total spend by joining customers through orders and order items to products, then multiplying quantity by price and summing. The outer query filters to only those customers whose total spend exceeds the average total spend across all customers (computed with a subquery on the CTE itself).

**Result:** A list of "above-average" customers ranked from highest to lowest total spend.

**Business interpretation:** These are the store's best customers by revenue — good candidates for a loyalty program, VIP perks, or personalized outreach.

---

### Query 6: CTE + Window Function – Ranking Customers by Spend

```sql
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
```

**Explanation:** Builds on the same `customer_totals` CTE as Query 5, but instead of filtering, it assigns a rank to every customer using `RANK() OVER (ORDER BY total_spend DESC)`. `RANK()` gives tied values the same rank and skips the next rank number accordingly (e.g., 1, 2, 2, 4).

**Result:** Every customer with their total spend and their rank position relative to all other customers.

**Business interpretation:** Gives a clear leaderboard of customers by revenue contribution, useful for sales reporting or deciding tiered rewards (e.g., top 10% get a discount code).

---

### Query 7: Window Function – Numbering Each Customer's Orders

```sql
SELECT customer_id, order_id, order_date,
       ROW_NUMBER() OVER (
         PARTITION BY customer_id
         ORDER BY order_date, order_id
       ) AS order_number
FROM orders
ORDER BY customer_id, order_number;
```

**Explanation:** `ROW_NUMBER()` assigns a unique, sequential number to each row within a partition. Here, `PARTITION BY customer_id` restarts the numbering for each customer, and `ORDER BY order_date, order_id` ensures the numbering follows chronological order (with `order_id` as a tiebreaker for same-day orders).

**Result:** Each order gets a per-customer sequence number: 1 for a customer's first order, 2 for their second, and so on.

**Business interpretation:** This lets the business identify a customer's first order (order_number = 1, useful for measuring "time to first purchase" or acquisition campaigns) versus repeat orders, and supports cohort-style repeat-purchase analysis.

---

### Query 8: CTE + Window Function – Running Total of Revenue Over Time

```sql
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
```

**Explanation:** The CTE first calculates the revenue of each individual order. The outer query then uses `SUM(revenue) OVER (ORDER BY order_date, order_id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)` to produce a cumulative (running) total of revenue as orders occur chronologically — each row adds its own revenue to the sum of all prior rows.

**Result:** Every order alongside its own revenue and the store's cumulative revenue up to and including that order.

**Business interpretation:** This is effectively a revenue growth curve at the order level — useful for tracking how total sales accumulate over the period and for building revenue trend charts.

---

### Query 9: CTE + Window Functions – Days Between a Customer's Repeat Orders

```sql
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
```

**Explanation:** The CTE uses two window functions per customer: `LAG(order_date)` looks back to the date of that customer's previous order (chronologically), and `COUNT(*) OVER (PARTITION BY customer_id)` counts how many total orders that customer has placed. The outer query joins in the customer's name, computes the gap in days between consecutive orders (`order_date - prev_order_date`), and filters with `WHERE order_count > 1` to only show customers who are repeat buyers (a customer with just one order has no "previous" order to compare against).

**Result:** For each repeat customer, every order after their first shows how many days passed since their prior order.

**Business interpretation:** This measures purchase frequency / customer loyalty cycle — the business can use it to time re-engagement emails (e.g., if a customer typically reorders every 30 days but hasn't in 45, send a reminder).

## Challenges and Resolutions

| Challenge | How I resolved it |
|---|---|
| Calculating total spend required joining across three tables (orders, order_items, products) rather than a single table | Used a CTE (`customer_totals`) to pre-aggregate `quantity * price` per customer before filtering/ranking, keeping the final query simple and reusable |
| Finding customers with above-average spend requires the average of an already-aggregated value | Wrapped the aggregation in a CTE and referenced it twice — once for the row-level total and once inside a scalar subquery to compute `AVG(total_spend)` |
| `RANK()` vs `ROW_NUMBER()` produce different results when there are ties | Used `RANK()` for the spend leaderboard (so tied spend amounts share a rank) and `ROW_NUMBER()` for per-customer order numbering (where each order must have a distinct sequence number even if placed on the same date) |
| Computing "days since previous order" requires comparing each row to the row before it, which a plain `GROUP BY` can't do | Used the `LAG()` window function, partitioned by customer and ordered by date, to pull the previous order's date into the same row |
| Customers with only one order have no "previous" order and would show a meaningless `NULL` gap | Added a `COUNT(*) OVER (PARTITION BY customer_id)` window function and filtered with `WHERE order_count > 1` to exclude one-time customers |
| *(Add any additional challenges you personally ran into — e.g., date arithmetic differences between PostgreSQL and other DBMSs, or duplicate query cleanup)* | *...* |
