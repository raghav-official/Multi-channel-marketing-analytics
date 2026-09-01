-- ============================================================================
-- Multi-Channel Marketing Analytics — SQL Server (T-SQL)
-- Full pipeline: schema -> data load -> views -> business-question queries
-- Source data: campaign_performance.csv
-- ============================================================================

-- ----------------------------------------------------------------------------
-- STEP 1 — Create the database and schema
-- ----------------------------------------------------------------------------

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'marketing_analytics')
BEGIN
    CREATE DATABASE marketing_analytics;
END
GO

USE marketing_analytics;
GO

IF OBJECT_ID('dbo.campaign_performance', 'U') IS NOT NULL DROP TABLE dbo.campaign_performance;
IF OBJECT_ID('dbo.channels', 'U') IS NOT NULL DROP TABLE dbo.channels;
GO

CREATE TABLE dbo.channels (
    channel_id     INT IDENTITY(1,1) PRIMARY KEY,
    channel_name   VARCHAR(50) NOT NULL UNIQUE,
    channel_type   VARCHAR(20) NOT NULL,      -- Paid / Owned
    primary_goal   VARCHAR(30) NOT NULL       -- Acquisition / Retention / Awareness
);
GO

INSERT INTO dbo.channels (channel_name, channel_type, primary_goal) VALUES
    ('Google Ads',   'Paid',  'Acquisition'),
    ('Meta Ads',     'Paid',  'Acquisition'),
    ('LinkedIn Ads', 'Paid',  'Acquisition'),
    ('YouTube',      'Paid',  'Awareness'),
    ('Email',        'Owned', 'Retention'),
    ('Affiliate',    'Paid',  'Acquisition');
GO

CREATE TABLE dbo.campaign_performance (
    record_id      INT IDENTITY(1,1) PRIMARY KEY,
    report_date    DATE NOT NULL,             -- week-starting date
    channel_id     INT NOT NULL,
    campaign_name  VARCHAR(80) NOT NULL,
    spend          DECIMAL(12,2) NOT NULL,
    impressions    INT NOT NULL,
    clicks         INT NOT NULL,
    leads          INT NOT NULL,
    mqls           INT NOT NULL,
    sqls           INT NOT NULL,
    customers      INT NOT NULL,
    revenue        DECIMAL(12,2) NOT NULL,
    CONSTRAINT FK_campaign_channel FOREIGN KEY (channel_id) REFERENCES dbo.channels(channel_id)
);
GO

CREATE INDEX idx_date ON dbo.campaign_performance (report_date);
CREATE INDEX idx_channel ON dbo.campaign_performance (channel_id);
GO

-- ----------------------------------------------------------------------------
-- STEP 2 — Load the data
-- ----------------------------------------------------------------------------
-- MANUAL STEP (one-time, do this in SSMS before running the rest of this file):
--   1. Right-click 'marketing_analytics' database -> Tasks -> Import Flat File
--   2. Select campaign_performance.csv
--   3. Name the new table 'campaign_performance_staging'
--   4. On the "Modify Columns" screen, set Impressions/Clicks/Leads/MQLs/SQLs/
--      Customers to 'int' (not tinyint/smallint) and Spend/Revenue to 'float'
--      or 'decimal', then Finish.
-- Once that staging table exists, run everything below.

-- Move staging data into the real table, converting Channel (text) to channel_id
INSERT INTO dbo.campaign_performance
    (report_date, channel_id, campaign_name, spend, impressions, clicks, leads, mqls, sqls, customers, revenue)
SELECT
    s.Date            AS report_date,
    c.channel_id,
    s.Campaign        AS campaign_name,
    s.Spend           AS spend,
    s.Impressions     AS impressions,
    s.Clicks          AS clicks,
    s.Leads           AS leads,
    s.MQLs            AS mqls,
    s.SQLs            AS sqls,
    s.Customers       AS customers,
    s.Revenue         AS revenue
FROM dbo.campaign_performance_staging s
JOIN dbo.channels c ON c.channel_name = s.Channel;
GO

-- Confirm the load worked (should show 2184 for both)
SELECT COUNT(*) AS StagingRowCount FROM dbo.campaign_performance_staging;
SELECT COUNT(*) AS RealTableRowCount FROM dbo.campaign_performance;
GO

-- Clean up the staging table now that the real table is populated
DROP TABLE IF EXISTS dbo.campaign_performance_staging;
GO

-- ----------------------------------------------------------------------------
-- STEP 3 — Core analysis views
-- ----------------------------------------------------------------------------

CREATE OR ALTER VIEW dbo.vw_channel_summary AS
SELECT
    c.channel_name,
    SUM(p.spend)                                             AS total_spend,
    SUM(p.revenue)                                           AS total_revenue,
    SUM(p.customers)                                         AS total_customers,
    SUM(p.leads)                                             AS total_leads,
    ROUND(SUM(p.revenue) / NULLIF(SUM(p.spend), 0), 2)       AS roas,
    ROUND(SUM(p.spend)   / NULLIF(SUM(p.customers), 0), 2)   AS cac,
    ROUND(SUM(p.spend)   / NULLIF(SUM(p.leads), 0), 2)       AS cpl,
    ROUND(CAST(SUM(p.clicks) AS FLOAT) / NULLIF(SUM(p.impressions), 0) * 100, 2) AS ctr_pct,
    ROUND(CAST(SUM(p.customers) AS FLOAT) / NULLIF(SUM(p.leads), 0) * 100, 2)    AS lead_to_customer_pct
FROM dbo.campaign_performance p
JOIN dbo.channels c ON c.channel_id = p.channel_id
GROUP BY c.channel_name;
GO

CREATE OR ALTER VIEW dbo.vw_monthly_trend AS
SELECT
    DATEFROMPARTS(YEAR(p.report_date), MONTH(p.report_date), 1) AS report_month,
    c.channel_name,
    SUM(p.spend)      AS spend,
    SUM(p.revenue)    AS revenue,
    SUM(p.customers)  AS customers,
    ROUND(SUM(p.revenue) / NULLIF(SUM(p.spend), 0), 2) AS roas
FROM dbo.campaign_performance p
JOIN dbo.channels c ON c.channel_id = p.channel_id
GROUP BY DATEFROMPARTS(YEAR(p.report_date), MONTH(p.report_date), 1), c.channel_name;
GO

CREATE OR ALTER VIEW dbo.vw_funnel AS
SELECT
    c.channel_name,
    SUM(p.impressions) AS impressions,
    SUM(p.clicks)       AS clicks,
    SUM(p.leads)        AS leads,
    SUM(p.mqls)          AS mqls,
    SUM(p.sqls)          AS sqls,
    SUM(p.customers)    AS customers
FROM dbo.campaign_performance p
JOIN dbo.channels c ON c.channel_id = p.channel_id
GROUP BY c.channel_name;
GO

-- ----------------------------------------------------------------------------
-- STEP 4 — Answer-the-business-question queries
-- ----------------------------------------------------------------------------

-- Q1. Which channel generated the most revenue?
SELECT channel_name, total_revenue
FROM dbo.vw_channel_summary
ORDER BY total_revenue DESC;

-- Q2. Which channels are actually profitable (ROAS > 1)?
SELECT channel_name, roas,
       CASE WHEN roas > 1 THEN 'Profitable' ELSE 'Unprofitable (last-click)' END AS profitability
FROM dbo.vw_channel_summary
ORDER BY roas DESC;

-- Q3. Where are we losing customers in the funnel? (stage-over-stage drop-off)
SELECT
    channel_name,
    impressions, clicks, leads, mqls, sqls, customers,
    ROUND(CAST(clicks AS FLOAT)    / NULLIF(impressions,0) * 100, 2) AS pct_impr_to_click,
    ROUND(CAST(leads AS FLOAT)     / NULLIF(clicks,0)       * 100, 2) AS pct_click_to_lead,
    ROUND(CAST(mqls AS FLOAT)      / NULLIF(leads,0)        * 100, 2) AS pct_lead_to_mql,
    ROUND(CAST(sqls AS FLOAT)      / NULLIF(mqls,0)         * 100, 2) AS pct_mql_to_sql,
    ROUND(CAST(customers AS FLOAT) / NULLIF(sqls,0)         * 100, 2) AS pct_sql_to_customer
FROM dbo.vw_funnel
ORDER BY pct_sql_to_customer ASC;

-- Q4. CAC vs ROAS ranking (which channels are efficient AND profitable?)
SELECT channel_name, cac, roas
FROM dbo.vw_channel_summary
ORDER BY roas DESC, cac ASC;

-- Q5. Monthly revenue trend (for the executive overview line chart)
SELECT report_month, SUM(revenue) AS revenue, SUM(spend) AS spend
FROM dbo.vw_monthly_trend
GROUP BY report_month
ORDER BY report_month;

-- Q6. Best single campaign by ROAS (min. spend threshold to avoid noise)
SELECT TOP 10
    c.channel_name,
    p.campaign_name,
    SUM(p.spend)   AS total_spend,
    SUM(p.revenue) AS total_revenue,
    ROUND(SUM(p.revenue) / NULLIF(SUM(p.spend), 0), 2) AS roas
FROM dbo.campaign_performance p
JOIN dbo.channels c ON c.channel_id = p.channel_id
GROUP BY c.channel_name, p.campaign_name
HAVING SUM(p.spend) > 100000
ORDER BY roas DESC;

-- Q7. Month-over-month revenue growth
SELECT
    report_month,
    revenue,
    LAG(revenue) OVER (ORDER BY report_month) AS prev_month_revenue,
    ROUND((revenue - LAG(revenue) OVER (ORDER BY report_month))
          / NULLIF(LAG(revenue) OVER (ORDER BY report_month), 0) * 100, 2) AS mom_growth_pct
FROM (
    SELECT report_month, SUM(revenue) AS revenue
    FROM dbo.vw_monthly_trend
    GROUP BY report_month
) x
ORDER BY report_month;

-- View all raw campaign data
SELECT * FROM dbo.campaign_performance;
