-- ============================================
-- EDA 1: Dataset overview
-- ============================================
SELECT
    COUNT(*)                                AS total_orders,
    COUNT(DISTINCT customer_id)             AS unique_customers,
    COUNT(DISTINCT seller_id)               AS unique_sellers,
    ROUND(AVG(total_order_value)::NUMERIC, 2) AS avg_order_value,
    MIN(order_date)                         AS earliest_order,
    MAX(order_date)                         AS latest_order
FROM gold.fact_logistics;

-- ============================================
-- EDA 2: Order status distribution
-- ============================================
SELECT
    order_status,
    COUNT(*)                                AS total,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pct
FROM gold.fact_logistics
GROUP BY order_status
ORDER BY total DESC;

-- ============================================
-- EDA 3: Delivery status breakdown
-- ============================================
SELECT
    delivery_status,
    COUNT(*)    AS orders,
    ROUND(AVG(total_delivery_days)::NUMERIC, 1) AS avg_delivery_days
FROM gold.fact_logistics
WHERE delivery_status != 'Not Delivered'
GROUP BY delivery_status;

-- ============================================
-- EDA 4: Top 10 product categories by order volume
-- ============================================
SELECT
    dp.category,
    COUNT(*)                AS total_orders,
    ROUND(SUM(fl.total_order_value)::NUMERIC, 2) AS total_revenue
FROM gold.fact_logistics fl
JOIN gold.dim_products dp ON fl.product_id = dp.product_id
GROUP BY dp.category
ORDER BY total_orders DESC
LIMIT 10;

-- ============================================
-- EDA 5: Average delivery days by seller state
-- ============================================
SELECT
    ds.seller_state,
    ROUND(AVG(fl.total_delivery_days)::NUMERIC, 1) AS avg_delivery_days,
    COUNT(*) AS orders
FROM gold.fact_logistics fl
JOIN gold.dim_sellers ds ON fl.seller_id = ds.seller_id
WHERE fl.total_delivery_days IS NOT NULL
GROUP BY ds.seller_state
ORDER BY avg_delivery_days DESC;