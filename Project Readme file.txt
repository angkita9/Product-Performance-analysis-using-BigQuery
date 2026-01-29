📖 Project Overview
This repository contains two comprehensive SQL analytical projects built on Google BigQuery that analyze sales performance, product profitability, and business trends across multiple dimensions. The projects demonstrate advanced SQL skills including CTEs, window functions, data aggregation, time-series analysis, and performance ranking.

These analyses are designed to provide actionable business insights for revenue optimization, product strategy, and performance tracking.

📌 Purpose:
Analyzes product profitability across year, month, region, and weekday/weekend segments, ranking products by gross margin performance.

🔑 Key Features:
.Calculates gross profit margin per product using retail and cost prices
.Ranks products using DENSE_RANK() based on profitability
.Segments sales data by:
.Year & Month
.Region
.Weekday vs Weekend
.Uses CASE statements for day-type classification
.Joins enriched sales data with ranked product information

📈 Business Insights Provided:
Which products are most profitable?
How does profitability vary by region and time?
Are products performing better on weekends or weekdays?

🛠️ SQL Techniques Used:
.Common Table Expressions (CTEs)
.Window Functions (DENSE_RANK)
.Conditional Logic (CASE WHEN)
.Joins enriched sales data with ranked product information
.Date Functions (EXTRACT, DAYOFWEEK)
.Table Joins

📜 Complete SQL Code:
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

---Sales_analysis.sql

📌 Purpose:
Performs time-series analysis within a fixed date window to ensure consistent, reproducible, and comparable business performance tracking.

🔑 Key Features:
.Defines parameterized date ranges for consistent analysis
.Standardizes product pricing using MAX aggregation
.Breaks down order dates into Year, Month, Week, and Day Type
.Calculates MoM (Month-over-Month) and YoY (Year-over-Year) growth metrics
.Tracks financial KPIs: revenue, cost, gross profit, order volume

📈 Business Insights Provided:
.Monthly and yearly revenue trends
.Profitability analysis across periods
.Growth performance (MoM & YoY)
.Weekend vs weekday sales patterns
.Supports forecasting and budget planning

🛠️ SQL Techniques Used:
.Parameterized CTEs
.Aggregate Functions with GROUP BY
.Window Functions with LAG() for period comparisons
.SAFE_DIVIDE for safe percentage calculations
.Complex nested CTEs for modular analysis

📜 Complete SQL Code:

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

Product Profitability Analysis
-- 1. Calculate Gross Profit Margin per Product
ROUND((retail_price - cost_price) / retail_price * 100, 2) AS gross_profit

-- 2. Rank Products by Profitability
DENSE_RANK() OVER (ORDER BY gross_profit DESC) AS profit_rank

-- 3. Classify Weekday vs Weekend
CASE
    WHEN EXTRACT(DAYOFWEEK FROM order_date) IN (1, 7)
        THEN 'Weekend'
    ELSE 'Weekday'
END AS day_type
Time-Series Analysis Components
-- 1. Parameterized Date Range
WITH params AS (
  SELECT
    DATE('2023-01-01') AS start_date,
    DATE('2024-12-31') AS end_date
)

-- 2. Date Dimension Extraction
EXTRACT(YEAR FROM s.order_date) AS year,
EXTRACT(MONTH FROM s.order_date) AS month,
EXTRACT(WEEK FROM s.order_date) AS week

-- 3. MoM Comparison using LAG()
LAG(revenue) OVER (
  PARTITION BY year
  ORDER BY month
) AS prev_month_revenue

-- 4. YoY Comparison using LAG()
LAG(revenue) OVER (
  PARTITION BY month
  ORDER BY year
) AS prev_year_revenue

-- 5. Safe Percentage Calculation
SAFE_DIVIDE(revenue - prev_month_revenue, prev_month_revenue) * 100

Financial KPI Calculations
-- 1. Revenue Calculation
ROUND(SUM(b.total_sales_amount), 2) AS revenue

-- 2. Cost Calculation
ROUND(SUM(p.cost_price * b.quantity), 2) AS total_cost

-- 3. Gross Profit
total_retail_price - total_cost AS gross_profit

-- 4. Growth Percentage
CASE
    WHEN prev_month_revenue IS NULL OR prev_month_revenue = 0 THEN NULL
    ELSE ROUND(
      SAFE_DIVIDE(revenue - prev_month_revenue, prev_month_revenue) * 100,
      2
    )
END AS mom_revenue_growth_pct
