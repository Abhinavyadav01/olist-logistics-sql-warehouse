CREATE SCHEMA IF NOT EXISTS gold;

-- ============================================
-- DIM: customers
-- What's happening: simple pass-through of clean customer data
-- This is the "who" dimension
-- ============================================
CREATE TABLE gold.dim_customers AS
SELECT
    customer_id,
    customer_unique_id,
    customer_city,
    customer_state
FROM silver.customers;

-- ============================================
-- DIM: sellers
-- The "who fulfilled it" dimension
-- ============================================
CREATE TABLE gold.dim_sellers AS
SELECT
    seller_id,
    seller_city,
    seller_state
FROM silver.sellers;

-- ============================================
-- DIM: products
-- The "what was ordered" dimension
-- ============================================
CREATE TABLE gold.dim_products AS
SELECT
    product_id,
    category,
    weight_g
FROM silver.products;

-- ============================================
-- DIM: date
-- What's happening: extracting date parts from order timestamps
-- This powers all time-based analysis (monthly trends, YoY, etc.)
-- DISTINCT because many orders share the same date
-- ============================================
CREATE TABLE gold.dim_date AS
SELECT DISTINCT
    DATE(purchase_ts)                       AS order_date,
    EXTRACT(YEAR FROM purchase_ts)::INT     AS year,
    EXTRACT(MONTH FROM purchase_ts)::INT    AS month,
    EXTRACT(QUARTER FROM purchase_ts)::INT  AS quarter,
    TO_CHAR(purchase_ts, 'Month')           AS month_name,
    EXTRACT(DOW FROM purchase_ts)::INT      AS day_of_week
FROM silver.orders
WHERE purchase_ts IS NOT NULL;

-- ============================================
-- FACT: fact_logistics
-- This is the CENTER of your star schema
-- What's happening:
-- 1. Joining orders + items + payments + reviews into one wide table
-- 2. Calculating ALL logistics time metrics on the fly:
--    - approval_hours: how fast did Olist approve the order?
--    - dispatch_days: how long before seller handed to courier?
--    - transit_days: how long courier took to deliver?
--    - total_delivery_days: end-to-end from purchase to doorstep
--    - promised_delivery_days: what was promised to customer
-- 3. Flagging each order: On Time / Late / Not Delivered
--    This SLA flag is the core of your entire analysis
-- WHERE order_item_id = 1: takes only first item per order
--    avoids duplicate rows when one order has multiple items
-- ============================================
CREATE TABLE gold.fact_logistics AS
SELECT
    o.order_id,
    o.customer_id,
    i.seller_id,
    i.product_id,
    DATE(o.purchase_ts)                             AS order_date,
    o.order_status,
    i.price                                         AS product_price,
    i.freight_value,
    (i.price + i.freight_value)                     AS total_order_value,
    p.total_payment,
    r.avg_review_score,

    -- Time from order placed → approved by Olist
    ROUND(EXTRACT(EPOCH FROM (o.approved_ts - o.purchase_ts))
          / 3600, 2)                                AS approval_hours,

    -- Time from approval → handed to courier
    ROUND(EXTRACT(EPOCH FROM (o.carrier_pickup_ts - o.approved_ts))
          / 86400, 2)                               AS dispatch_days,

    -- Time from courier pickup → delivered to customer
    ROUND(EXTRACT(EPOCH FROM (o.delivered_ts - o.carrier_pickup_ts))
          / 86400, 2)                               AS transit_days,

    -- Total end-to-end delivery time
    ROUND(EXTRACT(EPOCH FROM (o.delivered_ts - o.purchase_ts))
          / 86400, 2)                               AS total_delivery_days,

    -- What was promised to customer
    ROUND(EXTRACT(EPOCH FROM (o.estimated_delivery_ts - o.purchase_ts))
          / 86400, 2)                               AS promised_delivery_days,

    -- THE KEY FLAG: was this order on time?
    CASE
        WHEN o.delivered_ts IS NULL                          THEN 'Not Delivered'
        WHEN o.delivered_ts <= o.estimated_delivery_ts       THEN 'On Time'
        ELSE                                                      'Late'
    END                                             AS delivery_status

FROM silver.orders o
LEFT JOIN silver.order_items i  ON o.order_id = i.order_id
                                AND i.order_item_id = 1
LEFT JOIN silver.payments p     ON o.order_id = p.order_id
LEFT JOIN silver.reviews r      ON o.order_id = r.order_id;


-- Should be close to ~99,000 rows
SELECT COUNT(*) FROM gold.fact_logistics;

-- Spot check: see actual computed logistics columns
SELECT
    order_id,
    order_date,
    total_order_value,
    total_delivery_days,
    promised_delivery_days,
    delivery_status,
    avg_review_score
FROM gold.fact_logistics
LIMIT 10;

-- Quick SLA summary — first real business insight
SELECT
    delivery_status,
    COUNT(*)                                        AS orders,
    ROUND(COUNT(*)*100.0 / SUM(COUNT(*)) OVER(), 2) AS pct,
    ROUND(AVG(total_delivery_days)::NUMERIC, 1)     AS avg_days
FROM gold.fact_logistics
GROUP BY delivery_status;