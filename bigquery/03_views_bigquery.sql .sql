-- Final Report View 1: Seller Logistics Scorecard
CREATE OR REPLACE VIEW `olist-logistics-warehouse.olist_gold.vw_seller_scorecard` AS
SELECT
    fl.seller_id,
    ds.seller_state,
    COUNT(*) AS total_orders,
    ROUND(AVG(fl.total_delivery_days), 1) AS avg_delivery_days,
    ROUND(AVG(fl.freight_value), 2) AS avg_freight,
    SUM(CASE WHEN delivery_status = 'Late' THEN 1 ELSE 0 END) AS late_count,
    ROUND(
        SUM(CASE WHEN delivery_status = 'Late' THEN 1 ELSE 0 END) * 100.0
        / COUNT(*), 2
    ) AS breach_rate_pct,
    ROUND(AVG(fl.avg_review_score), 2) AS avg_review
FROM `olist-logistics-warehouse.olist_gold.fact_logistics` fl
JOIN `olist-logistics-warehouse.olist_gold.dim_sellers` ds
    ON fl.seller_id = ds.seller_id
GROUP BY fl.seller_id, ds.seller_state;


-- Final Report View 2: Monthly Logistics KPI Summary
CREATE OR REPLACE VIEW `olist-logistics-warehouse.olist_gold.vw_monthly_kpis` AS
SELECT
    FORMAT_DATE('%Y-%m', order_date) AS month,
    COUNT(*) AS total_orders,
    ROUND(SUM(total_order_value), 2) AS total_revenue,
    ROUND(AVG(total_delivery_days), 1) AS avg_delivery_days,
    ROUND(
        SUM(CASE WHEN delivery_status = 'On Time' THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0), 2
    ) AS on_time_pct,
    ROUND(AVG(avg_review_score), 2) AS avg_review_score
FROM `olist-logistics-warehouse.olist_gold.fact_logistics`
WHERE delivery_status != 'Not Delivered'
GROUP BY FORMAT_DATE('%Y-%m', order_date)
ORDER BY month;


-- How is each seller performing on logistics?
SELECT * FROM `olist-logistics-warehouse.olist_gold.vw_seller_scorecard` LIMIT 10;

-- How is the platform performing month by month?
SELECT * FROM `olist-logistics-warehouse.olist_gold.vw_monthly_kpis`;