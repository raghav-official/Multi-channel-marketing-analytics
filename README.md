<img width="1300" height="727" alt="Multi channel marketing overview" src="https://github.com/user-attachments/assets/519a1199-aa77-417e-842f-2df4d5eff21f" />
# Multi-Channel Marketing Performance & Budget Optimization

An end-to-end marketing analytics project simulating 2 years of performance data across 6 acquisition channels, analyzed through a full Excel → SQL → Power BI pipeline.

![Dashboard Overview](screenshots/01-overview.png)

## The business questions

1. How are our marketing channels performing?
2. Which channels are bringing customers?
3. Where are we losing customers in the funnel?
4. Which channels are actually profitable?
5. If we have ₹50L next month, how should we distribute it?
6. What happens if we increase or decrease the budget?

## Tools used

- Excel — raw data, data dictionary, channel benchmarks, budget optimization model
- SQL Server — relational schema, views, and business-question queries
- Power BI — 5-page interactive dashboard with DAX measures and a live what-if simulator

## The dataset

Simulated (non-confidential) data — 2 years (Jan 2024–Dec 2025), weekly grain, 6 channels × 3–4 named campaigns each (2,184 rows). Full funnel tracked per row: Impressions → Clicks → Leads → MQLs → SQLs → Customers → Revenue, with realistic seasonality (festive-season spikes, monsoon slowdown). Methodology and all assumption ranges are documented in the Excel file's Channel Benchmarks sheet.

## Dashboard

<details>
<summary><b>See all 5 pages</b></summary>

### 1. Marketing Overview
![Overview](screenshots/01-overview.png)

### 2. Funnel Analysis
![Funnel Analysis](screenshots/02-funnel.png)

### 3. Channel Analysis
![Channel Analysis](screenshots/03-channel-analysis.png)

### 4. Budget Optimization
![Budget Optimization](screenshots/04-budget-optimization.png)

### 5. What-If Budget Simulator
![What-If Simulator](screenshots/05-whatif-simulator.png)

</details>

## Key findings

- Blended ROAS across all channels: 2.15x
- Email is the standout performer (23.8x ROAS) — low cost, high-intent existing audience
- Google Ads is the solid workhorse (1.8x ROAS) — largest scalable paid channel
- Meta and YouTube underperform on last-click ROAS (below 1x) - likely stronger as upper-funnel/awareness channels than direct-response
- LinkedIn has the highest CAC (~₹18,000) but also the highest average order value — justified for enterprise deals, not a pure efficiency play
- Reallocating the same ₹50L monthly budget toward the response-curve-optimized mix projects a ~51% revenue improvement

## How to explore this project

1. Excel: open `Marketing_Data.xlsx` - start with the README sheet, then Campaign Performance for raw data
2. SQL: run `marketing_analytics_FINAL.sql` in SQL Server Management Studio (imports `campaign_performance.csv` as a staging step - instructions are commented inline in the script)
3. Power BI: open the `.pbix` file in Power BI Desktop, or view the screenshots above for a quick look
