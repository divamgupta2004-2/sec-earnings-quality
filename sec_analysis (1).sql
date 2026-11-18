-- SEC earnings-quality project — canonical SQL (2026-10-31)
-- Run each block separately: highlight from its first keyword through its final semicolon, then run.
-- Never run the whole file at once.

-- Step 1: clear any existing view (safe whether it exists or not)
DROP VIEW IF EXISTS company_financials;

-- Step 2: rebuild the view — consolidated facts only (segments IS NULL),
-- latest 10-K / 10-K/A filing wins per company per tag
CREATE VIEW company_financials AS
WITH latest AS (
  SELECT
    s.cik, s.name, s.sic, n.tag, n.value,
    ROW_NUMBER() OVER (PARTITION BY s.cik, n.tag ORDER BY s.filed DESC) AS rn
  FROM num n
  JOIN sub s ON s.adsh = n.adsh
  WHERE s.form IN ('10-K', '10-K/A')
    AND n.segments IS NULL
    AND n.tag IN ('RevenueFromContractWithCustomerExcludingAssessedTax',
                  'RevenueFromContractWithCustomerIncludingAssessedTax',
                  'Revenues',
                  'RevenueFromContractsWithCustomers',
                  'RevenueFromSaleOfGoods',
                  'RegulatedAndUnregulatedOperatingRevenue',
                  'RevenuesNetOfInterestExpense',
                  'NetIncomeLoss', 'GrossProfit',
                  'NetCashProvidedByUsedInOperatingActivities', 'Assets')
)
SELECT
  cik, name, sic,
  MAX(CASE WHEN tag IN ('RevenueFromContractWithCustomerExcludingAssessedTax',
                        'RevenueFromContractWithCustomerIncludingAssessedTax',
                        'Revenues',
                        'RevenueFromContractsWithCustomers',
                        'RevenueFromSaleOfGoods',
                        'RegulatedAndUnregulatedOperatingRevenue',
                        'RevenuesNetOfInterestExpense') THEN value END) AS revenue,
  MAX(CASE WHEN tag = 'NetIncomeLoss' THEN value END) AS net_income,
  MAX(CASE WHEN tag = 'GrossProfit' THEN value END) AS gross_profit,
  MAX(CASE WHEN tag = 'NetCashProvidedByUsedInOperatingActivities' THEN value END) AS op_cash_flow,
  MAX(CASE WHEN tag = 'Assets' THEN value END) AS assets
FROM latest
WHERE rn = 1
GROUP BY cik, name, sic;

-- Step 3 (after Write Changes + confirming the view appears under Database Structure):
-- proof query — the view exists and has rows
SELECT COUNT(*) FROM company_financials;

-- Step 4: coverage checks
SELECT COUNT(*) FROM company_financials WHERE revenue IS NOT NULL;
SELECT COUNT(*) FROM company_financials WHERE net_income IS NOT NULL;
SELECT COUNT(*) FROM company_financials WHERE op_cash_flow IS NOT NULL;
SELECT COUNT(*) FROM company_financials WHERE assets IS NOT NULL;

-- Analysis 1 (revised): profitability by sector — aggregate margin
SELECT
  sic/100 AS division,
  COUNT(*) AS companies,
  ROUND(SUM(net_income) * 1.0 / NULLIF(SUM(revenue), 0), 4) AS sector_margin
FROM company_financials
WHERE revenue IS NOT NULL AND revenue != 0 AND sic IS NOT NULL
GROUP BY division
HAVING COUNT(*) >= 10
ORDER BY sector_margin DESC;

-- Analysis 2: top 20 companies by revenue, with margin and cash conversion
SELECT name, revenue, net_income,
  ROUND(net_income * 1.0 / NULLIF(revenue, 0), 4) AS net_margin,
  op_cash_flow,
  CASE WHEN net_income > 0 THEN ROUND(op_cash_flow * 1.0 / net_income, 2) END AS cash_conversion
FROM company_financials
WHERE revenue IS NOT NULL
ORDER BY revenue DESC
LIMIT 20;

-- Analysis 3: high-revenue, low-profit quadrant (margin under 5%, biggest first)
SELECT name, sic/100 AS division, revenue, net_income,
  ROUND(net_income * 1.0 / NULLIF(revenue, 0), 4) AS net_margin,
  op_cash_flow
FROM company_financials
WHERE revenue IS NOT NULL AND revenue != 0
  AND net_income * 1.0 / revenue < 0.05
ORDER BY revenue DESC
LIMIT 30;

-- Analysis 4: scale trend — revenue quartiles vs aggregate margin
WITH quartiles AS (
  SELECT revenue, net_income,
    NTILE(4) OVER (ORDER BY revenue) AS q
  FROM company_financials
  WHERE revenue IS NOT NULL AND revenue != 0
)
SELECT q AS revenue_quartile, COUNT(*) AS companies,
  ROUND(SUM(net_income) * 1.0 / NULLIF(SUM(revenue), 0), 4) AS quartile_margin
FROM quartiles
GROUP BY q
ORDER BY q;

-- Analysis 5: profitable on paper, weak cash — cash conversion under 0.5, biggest profits first
SELECT name, sic/100 AS division, net_income, op_cash_flow,
  ROUND(op_cash_flow * 1.0 / net_income, 2) AS cash_conversion
FROM company_financials
WHERE net_income > 0 AND op_cash_flow IS NOT NULL
  AND op_cash_flow * 1.0 / net_income < 0.5
ORDER BY net_income DESC
LIMIT 20;

-- Analysis 6: unprofitable share by sector
SELECT sic/100 AS division, COUNT(*) AS companies,
  SUM(CASE WHEN net_income < 0 THEN 1 ELSE 0 END) AS unprofitable,
  ROUND(SUM(CASE WHEN net_income < 0 THEN 1 ELSE 0 END) * 1.0 / COUNT(*), 3) AS unprofitable_share
FROM company_financials
WHERE net_income IS NOT NULL AND sic IS NOT NULL
GROUP BY division
HAVING COUNT(*) >= 10
ORDER BY unprofitable_share DESC;
