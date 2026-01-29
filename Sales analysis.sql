#EDA analysis using time frame .
# purpose:To define a fixed analysis windows so that analysis remain consistent,reproducible and comparable over time
WITH params AS (
  SELECT
    DATE('2023-01-01') AS start_date,
    DATE('2024-12-31') AS end_date
),
# Product price Normalization
# purpose:Standardize product pricing.
-- I take MAX price assuming latest or highest valid price per product
product_price AS (
  SELECT
    product_id,
    MAX(cost_price) AS cost_price,
    MAX(retail_price) AS retail_price
  FROM `Project.EDA1`
  GROUP BY product_id
),
# Break order_date into year,month,week for time series analysis

base_sales AS (
  SELECT
    EXTRACT(YEAR FROM s.order_date) AS year,
    EXTRACT(MONTH FROM s.order_date) AS month,
    EXTRACT(WEEK FROM s.order_date) AS week,
    s.order_id,
    s.product_id,
    s.quantity,
    s.total_sales_amount,
    CASE
  WHEN EXTRACT(DAYOFWEEK FROM order_date) IN (1,7)
  THEN 'Weekend'
  ELSE 'Weekday'
END AS day_type

  FROM `Project.EDA` s
  WHERE s.order_date BETWEEN (SELECT start_date FROM params)
   AND (SELECT end_date FROM params)
),
#Purpose:
-- 1.To Track MoM & YoY growth
-- 2.To Identify profitable vs loss-making periods
-- 3.To Support forecasting and budget planning
month_year_eda AS (
  SELECT
    b.year,
    b.month,
    COUNT(DISTINCT b.order_id) AS total_orders,
    ROUND(SUM(b.total_sales_amount), 2) AS revenue,
    ROUND(SUM(p.cost_price * b.quantity), 2) AS total_cost,
    ROUND(SUM(p.retail_price * b.quantity), 2) AS total_retail_price
  FROM base_sales b
  LEFT JOIN product_price p
    ON b.product_id = p.product_id
  GROUP BY b.year, b.month
),
#Purpose: To Present Margin control, pricing strategy, profit optimizatio financial KPIs.
yoy_mom_analysis AS (
  SELECT
    year,
    month,
    total_orders,
    revenue,
    total_cost,
    total_retail_price,
    total_retail_price - total_cost AS gross_profit,

    -- =========================
    -- MoM (within same year)
    -- =========================
    LAG(revenue) OVER (
      PARTITION BY year
      ORDER BY month
    ) AS prev_month_revenue,

    LAG(total_retail_price - total_cost) OVER (
      PARTITION BY year
      ORDER BY month
    ) AS prev_month_gross_profit,

    -- =========================
    -- YoY (same month last year)
    -- =========================
    LAG(revenue) OVER (
      PARTITION BY month
      ORDER BY year
    ) AS prev_year_revenue,

    LAG(total_retail_price - total_cost) OVER (
      PARTITION BY month
      ORDER BY year
    ) AS prev_year_gross_profit

  FROM month_year_eda
)

SELECT
  year,
  month,
  total_orders,
  revenue,
  gross_profit,

  -- =========================
  -- MoM Growth %
  -- =========================
  CASE
    WHEN prev_month_revenue IS NULL OR prev_month_revenue = 0 THEN NULL
    ELSE ROUND(
      SAFE_DIVIDE(revenue - prev_month_revenue, prev_month_revenue) * 100,
      2
    )
  END AS mom_revenue_growth_pct,

  CASE
    WHEN prev_month_gross_profit IS NULL OR prev_month_gross_profit = 0 THEN NULL
    ELSE ROUND(
      SAFE_DIVIDE(
        gross_profit - prev_month_gross_profit,
        prev_month_gross_profit
      ) * 100,
      2
    )
  END AS mom_gross_profit_growth_pct,

  -- =========================
  -- YoY Growth %
  -- =========================
  CASE
    WHEN prev_year_revenue IS NULL OR prev_year_revenue = 0 THEN NULL
    ELSE ROUND(
      SAFE_DIVIDE(revenue - prev_year_revenue, prev_year_revenue) * 100,
      2
    )
  END AS yoy_revenue_growth_pct,

  CASE
    WHEN prev_year_gross_profit IS NULL OR prev_year_gross_profit = 0 THEN NULL
    ELSE ROUND(
      SAFE_DIVIDE(
        gross_profit - prev_year_gross_profit,
        prev_year_gross_profit
      ) * 100,
      2
    )
  END AS yoy_gross_profit_growth_pct

FROM yoy_mom_analysis
ORDER BY year, month;

  


