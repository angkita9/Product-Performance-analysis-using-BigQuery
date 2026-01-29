## product performance 
-- purpose:Year ,month,region,weekday_weekend wise product's gross margin and rank it accordingly
WITH product_rank AS (
    SELECT DISTINCT
        product_id,
        product_name,
        ROUND((retail_price - cost_price) / retail_price * 100, 2) AS gross_profit
    FROM `Project.EDA1`
),

ranked_product AS (
    SELECT
        product_id,
        product_name,
        gross_profit,
        DENSE_RANK() OVER (ORDER BY gross_profit DESC) AS profit_rank
    FROM product_rank
),

sales_enriched AS (
    SELECT DISTINCT
        product_id,
        region,
        EXTRACT(YEAR FROM order_date) AS year,
        EXTRACT(MONTH FROM order_date) AS month,
        CASE
            WHEN EXTRACT(DAYOFWEEK FROM order_date) IN (1, 7)
                THEN 'Weekend'
            ELSE 'Weekday'
        END AS day_type
    FROM `Project.EDA`
)

SELECT
    se.year,
    se.month,
    se.day_type AS weekend_weekday,
    se.region,
    rp.product_name,
    rp.gross_profit,
    rp.profit_rank
FROM sales_enriched se
JOIN ranked_product rp
    ON se.product_id = rp.product_id
ORDER BY
    se.year,
    se.month,
    rp.profit_rank;
