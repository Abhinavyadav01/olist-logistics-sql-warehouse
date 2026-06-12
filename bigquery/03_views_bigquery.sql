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

-- Advanced fact table for Dashboarding
CREATE OR REPLACE VIEW `olist-logistics-warehouse.olist_gold.vw_fact_analytics` AS
SELECT
  order_id,
  customer_id,
  seller_id,
  product_id,
  order_date,
  FORMAT_DATE('%Y-%m', order_date) AS year_month,
  EXTRACT(YEAR FROM order_date) AS year,
  EXTRACT(MONTH FROM order_date) AS month_num,
  FORMAT_DATE('%b %Y', order_date) AS month_label,
  order_status,
  delivery_status,
  product_price,
  freight_value,
  total_order_value,
  total_payment,
  avg_review_score,
  total_delivery_days,
  promised_delivery_days,
  CASE
    WHEN delivery_status = 'Late'
    THEN total_delivery_days - promised_delivery_days
    ELSE NULL
  END AS delay_days,
  CASE
    WHEN total_delivery_days - promised_delivery_days BETWEEN 1 AND 3 THEN '1-3 Days Late'
    WHEN total_delivery_days - promised_delivery_days BETWEEN 4 AND 7 THEN '4-7 Days Late'
    WHEN total_delivery_days - promised_delivery_days BETWEEN 8 AND 14 THEN '8-14 Days Late'
    WHEN total_delivery_days - promised_delivery_days > 14 THEN '14+ Days Late'
    WHEN delivery_status = 'On Time' THEN 'On Time'
    ELSE 'Not Delivered'
  END AS delay_bucket,
  CASE WHEN delivery_status = 'Late' THEN 1 ELSE 0 END AS late_flag,
  CASE WHEN delivery_status = 'On Time' THEN 1 ELSE 0 END AS on_time_flag
FROM `olist-logistics-warehouse.olist_gold.fact_logistics`
WHERE order_date IS NOT NULL;