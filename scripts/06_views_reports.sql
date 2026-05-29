-- Final Report View 1: Seller Logistics Scorecard
CREATE VIEW gold.vw_seller_scorecard AS
SELECT
    fl.seller_id,
    ds.seller_state,
    COUNT(*)                                        AS total_orders,
    ROUND(AVG(fl.total_delivery_days)::NUMERIC, 1)  AS avg_delivery_days,
    ROUND(AVG(fl.freight_value)::NUMERIC, 2)        AS avg_freight,
    SUM(CASE WHEN delivery_status = 'Late' THEN 1 ELSE 0 END) AS late_count,
    ROUND(
        SUM(CASE WHEN delivery_status = 'Late' THEN 1 ELSE 0 END)*100.0
        / COUNT(*)
    ::NUMERIC, 2)                                   AS breach_rate_pct,
    ROUND(AVG(fl.avg_review_score)::NUMERIC, 2)     AS avg_review
FROM gold.fact_logistics fl
JOIN gold.dim_sellers ds ON fl.seller_id = ds.seller_id
GROUP BY fl.seller_id, ds.seller_state;

-- How is each seller performing on logistics?
SELECT * FROM gold.vw_seller_scorecard

-- Final Report View 2: Monthly Logistics KPI Summary
CREATE VIEW gold.vw_monthly_kpis AS
SELECT
    TO_CHAR(order_date, 'YYYY-MM')                  AS month,
    COUNT(*)                                        AS total_orders,
    ROUND(SUM(total_order_value)::NUMERIC, 2)       AS total_revenue,
    ROUND(AVG(total_delivery_days)::NUMERIC, 1)     AS avg_delivery_days,
    ROUND(
        SUM(CASE WHEN delivery_status = 'On Time' THEN 1 ELSE 0 END)*100.0
        / NULLIF(COUNT(*), 0)
    ::NUMERIC, 2)                                   AS on_time_pct,
    ROUND(AVG(avg_review_score)::NUMERIC, 2)        AS avg_review_score
FROM gold.fact_logistics
WHERE delivery_status != 'Not Delivered'
GROUP BY TO_CHAR(order_date, 'YYYY-MM')
ORDER BY month;

-- How is the platform performing month by month?
SELECT * FROM gold.vw_monthly_kpis