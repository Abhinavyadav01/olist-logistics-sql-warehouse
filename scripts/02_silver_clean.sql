CREATE SCHEMA IF NOT EXISTS silver;

-- ============================================
-- SILVER: orders
-- What's happening: casting all timestamp strings to real TIMESTAMP type
-- NULLIF handles cases where the timestamp string is empty
-- We only keep rows where both order_id and customer_id exist
-- ============================================

CREATE TABLE silver.orders AS
SELECT
    order_id,
    customer_id,
    order_status,
    -- Cast VARCHAR → TIMESTAMP. If value is bad/empty, it becomes NULL
    NULLIF(order_purchase_timestamp, '')::TIMESTAMP       AS purchase_ts,
    NULLIF(order_approved_at, '')::TIMESTAMP              AS approved_ts,
    NULLIF(order_delivered_carrier_date, '')::TIMESTAMP   AS carrier_pickup_ts,
    NULLIF(order_delivered_customer_date, '')::TIMESTAMP  AS delivered_ts,
    NULLIF(order_estimated_delivery_date, '')::TIMESTAMP  AS estimated_delivery_ts
FROM bronze.raw_orders
WHERE order_id IS NOT NULL
  AND customer_id IS NOT NULL;

-- ============================================
-- SILVER: order_items
-- What's happening: removing rows with zero or null prices
-- Those are data errors — can't analyze revenue on free items
-- ============================================
CREATE TABLE silver.order_items AS
SELECT
    order_id,
    order_item_id,
    product_id,
    seller_id,
    NULLIF(shipping_limit_date, '')::TIMESTAMP AS shipping_limit_ts,
    price,
    freight_value
FROM bronze.raw_order_items
WHERE order_id IS NOT NULL
  AND price > 0;

-- ============================================
-- SILVER: customers
-- What's happening: standardizing city and state formatting
-- TRIM removes leading/trailing spaces, LOWER normalizes city names
-- UPPER standardizes state codes (SP, RJ, etc.)
-- ============================================
CREATE TABLE silver.customers AS
SELECT
    customer_id,
    customer_unique_id,
    TRIM(LOWER(customer_city))  AS customer_city,
    UPPER(customer_state)       AS customer_state
FROM bronze.raw_customers
WHERE customer_id IS NOT NULL;

-- ============================================
-- SILVER: sellers
-- Same as customers
-- ============================================
CREATE TABLE silver.sellers AS
SELECT
    seller_id,
    TRIM(LOWER(seller_city))    AS seller_city,
    UPPER(seller_state)         AS seller_state
FROM bronze.raw_sellers
WHERE seller_id IS NOT NULL;

-- ============================================
-- SILVER: products
-- What's happening: joining English category names from translation table
-- COALESCE handles products with no category → labels them 'uncategorized'
-- ============================================
CREATE TABLE silver.products AS
SELECT
    p.product_id,
    COALESCE(t.product_category_name_english, 'uncategorized') AS category,
    COALESCE(p.product_weight_g, 0)   AS weight_g,
    COALESCE(p.product_length_cm, 0)  AS length_cm
FROM bronze.raw_products p
LEFT JOIN bronze.raw_category_translation t
    ON p.product_category_name = t.product_category_name;

-- ============================================
-- SILVER: payments
-- What's happening: payments table has multiple rows per order
-- (one row per payment method used)
-- We collapse them: SUM all payment values, take the dominant payment type
-- Result: exactly one row per order
-- ============================================
CREATE TABLE silver.payments AS
SELECT
    order_id,
    SUM(payment_value)        AS total_payment,
    MAX(payment_type)         AS payment_type,
    MAX(payment_installments) AS installments
FROM bronze.raw_payments
WHERE order_id IS NOT NULL
GROUP BY order_id;

-- ============================================
-- SILVER: reviews
-- What's happening: one order can have multiple reviews (edge case)
-- AVG collapses them to one score per order
-- Filter: only keep valid scores 1-5
-- ============================================
CREATE TABLE silver.reviews AS
SELECT
    order_id,
    ROUND(AVG(review_score)::NUMERIC, 1) AS avg_review_score
FROM bronze.raw_reviews
WHERE review_score BETWEEN 1 AND 5
GROUP BY order_id;

-- Check Silver row counts vs Bronze
-- Silver should be slightly less (we dropped nulls/bad rows)
SELECT 'silver.orders'    AS layer, COUNT(*) FROM silver.orders
UNION ALL
SELECT 'silver.order_items',         COUNT(*) FROM silver.order_items
UNION ALL
SELECT 'silver.customers',           COUNT(*) FROM silver.customers
UNION ALL
SELECT 'silver.sellers',             COUNT(*) FROM silver.sellers
UNION ALL
SELECT 'silver.products',            COUNT(*) FROM silver.products
UNION ALL
SELECT 'silver.payments',            COUNT(*) FROM silver.payments
UNION ALL
SELECT 'silver.reviews',             COUNT(*) FROM silver.reviews;

-- Should show real timestamps, not text strings
SELECT order_id, purchase_ts, delivered_ts, estimated_delivery_ts
FROM silver.orders
LIMIT 5;