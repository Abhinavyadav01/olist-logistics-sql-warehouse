-- Bronze = raw, untouched data
CREATE SCHEMA IF NOT EXISTS bronze;

-- Timestamps stored as VARCHAR because we'll cast them properly in Silver
CREATE TABLE IF NOT EXISTS bronze.raw_orders (
    order_id                        VARCHAR(50),
    customer_id                     VARCHAR(50),
    order_status                    VARCHAR(20),
    order_purchase_timestamp        VARCHAR(30),
    order_approved_at               VARCHAR(30),
    order_delivered_carrier_date    VARCHAR(30),
    order_delivered_customer_date   VARCHAR(30),
    order_estimated_delivery_date   VARCHAR(30)
);

-- An order can have multiple items, each with its own price and freight
CREATE TABLE IF NOT EXISTS bronze.raw_order_items (
    order_id            VARCHAR(50),
    order_item_id       INT,
    product_id          VARCHAR(50),
    seller_id           VARCHAR(50),
    shipping_limit_date VARCHAR(30),
    price               NUMERIC(10,2),
    freight_value       NUMERIC(10,2)
);

-- Customers: who placed the order
CREATE TABLE IF NOT EXISTS bronze.raw_customers (
    customer_id              VARCHAR(50),
    customer_unique_id       VARCHAR(50),
    customer_zip_code_prefix VARCHAR(10),
    customer_city            VARCHAR(100),
    customer_state           VARCHAR(5)
);

-- Sellers: who fulfilled the order
CREATE TABLE IF NOT EXISTS bronze.raw_sellers (
    seller_id               VARCHAR(50),
    seller_zip_code_prefix  VARCHAR(10),
    seller_city             VARCHAR(100),
    seller_state            VARCHAR(5)
);

-- Products: what was ordered
CREATE TABLE IF NOT EXISTS bronze.raw_products (
    product_id            VARCHAR(50),
    product_category_name VARCHAR(100),
	product_name_length           INT,
    product_description_length    INT,
    product_photos_qty            INT,
    product_weight_g      NUMERIC(10,2),
    product_length_cm     NUMERIC(10,2),
    product_height_cm     NUMERIC(10,2),
    product_width_cm      NUMERIC(10,2)
);

-- Payments: how the order was paid
CREATE TABLE IF NOT EXISTS bronze.raw_payments (
    order_id             VARCHAR(50),
    payment_sequential   INT,
    payment_type         VARCHAR(30),
    payment_installments INT,
    payment_value        NUMERIC(10,2)
);


DROP TABLE IF EXISTS bronze.raw_reviews;
CREATE TABLE bronze.raw_reviews (
    review_id                 VARCHAR(50),
    order_id                  VARCHAR(50),
    review_score              INT,
	review_comment_title      TEXT,
    review_comment_message    TEXT,
    review_creation_date      VARCHAR(30),
    review_answer_timestamp   VARCHAR(30)
);

-- Category translation: product names are in Portuguese, this maps to English
CREATE TABLE IF NOT EXISTS bronze.raw_category_translation (
    product_category_name         VARCHAR(100),
    product_category_name_english VARCHAR(100)
);

-- Load orders 
COPY bronze.raw_orders
FROM 'D:\Projects\Olist\datasets/olist_orders_dataset.csv'
DELIMITER ',' CSV HEADER;

COPY bronze.raw_order_items
FROM 'D:\Projects\Olist\datasets/olist_order_items_dataset.csv'
DELIMITER ',' CSV HEADER;

COPY bronze.raw_customers
FROM 'D:\Projects\Olist\datasets/olist_customers_dataset.csv'
DELIMITER ',' CSV HEADER;

COPY bronze.raw_sellers
FROM 'D:\Projects\Olist\datasets/olist_sellers_dataset.csv'
DELIMITER ',' CSV HEADER;

COPY bronze.raw_products
FROM 'D:\Projects\Olist\datasets/olist_products_dataset.csv'
DELIMITER ',' CSV HEADER;

COPY bronze.raw_payments
FROM 'D:\Projects\Olist\datasets/olist_order_payments_dataset.csv'
DELIMITER ',' CSV HEADER;

-- reviews CSV has some messy text, so we use ESCAPE to handle quotes
COPY bronze.raw_reviews 
FROM 'D:/Projects/Olist/datasets/olist_order_reviews_dataset.csv'
WITH (
    FORMAT csv,
    HEADER true,
    QUOTE '"',
    ESCAPE '"'
);

COPY bronze.raw_category_translation
FROM 'D:\Projects\Olist\datasets/product_category_name_translation.csv'
DELIMITER ',' CSV HEADER;

-- Count check across all bronze tables
SELECT 'raw_orders'              AS table_name, COUNT(*) AS rows FROM bronze.raw_orders
UNION ALL
SELECT 'raw_order_items',                        COUNT(*) FROM bronze.raw_order_items
UNION ALL
SELECT 'raw_customers',                          COUNT(*) FROM bronze.raw_customers
UNION ALL
SELECT 'raw_sellers',                            COUNT(*) FROM bronze.raw_sellers
UNION ALL
SELECT 'raw_products',                           COUNT(*) FROM bronze.raw_products
UNION ALL
SELECT 'raw_payments',                           COUNT(*) FROM bronze.raw_payments
UNION ALL
SELECT 'raw_reviews',                            COUNT(*) FROM bronze.raw_reviews
UNION ALL
SELECT 'raw_category_translation',               COUNT(*) FROM bronze.raw_category_translation;