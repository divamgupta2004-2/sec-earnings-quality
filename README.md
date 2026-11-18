# SEC Earnings-Quality Screen — Q3 2026

Which public companies actually turn revenue into profit — and where do reported profits fail to turn into cash?

**Interactive dashboard:** [Tableau Public — SEC Earnings Quality Q3 2026](https://public.tableau.com/app/profile/divam.gupta1213/viz/SECEarningsQualityQ32026/Sheet2)

**Stack:** SQL (SQLite / DB Browser) · Tableau Public · SEC EDGAR Financial Statements Data Sets

## Data and method
- **Source:** SEC Financial Statements Data Sets, 2026 Q3 quarter zip (SUB, NUM, TAG tables; 6,516 filings; 3,905,397 facts).
- **Scope:** 10-K and 10-K/A filings only. Latest filing wins per company per tag, so amendments correct originals.
- **Cleaned view:** `company_financials` — one row per company, 373 companies (344 10-K filers plus amendment-only companies).
- **Coverage:** revenue 291, net income 354, operating cash flow 356, assets 369.
- **Tag mapping (from discovery, not assumption):** revenue = largest reported revenue tag per company across the contract-with-customer tags and `Revenues` (the contract tag dominates: 113,901 facts vs 51,296 for `Revenues`); profit = `NetIncomeLoss`; operating cash flow = `NetCashProvidedByUsedInOperatingActivities`; assets = `Assets`. MAX across revenue tags avoids double-counting companies that report more than one.
- **Consolidated facts only:** `segments IS NULL` filter. Segment-level rows were distorting margins (the first sector run showed every division negative, one at -352) and were removed.
- **Margins are aggregate:** total sector profit divided by total sector revenue (dollar-weighted), not averages of company ratios, which tiny-revenue companies distort.

## Findings
1. **Scale predicts profitability — monotonically.** Revenue-quartile aggregate margins: smallest quartile -564%, Q2 -13.6%, Q3 -1.6%, largest quartile +12.2%. The largest quartile is the only profitable one in aggregate. (271 companies with nonzero revenue; 20 report exactly zero revenue.)
2. **Sector margins (divisions with 10+ companies, aggregate):** business services +30.7% (46 companies), instruments +16.5% (17), machinery +14.2% (20), chemicals/pharma +12.3% (27), food +7.2% (10), electronics -4.1% (25, the only negative).
3. **Count vs dollars in pharma:** 68.2% of pharma companies are unprofitable, yet pharma's aggregate margin is +12.3% — a few large profitable firms outweigh dozens of small loss-making biotechs in dollars. Same pattern in business services: 60% unprofitable, yet +30.7% aggregate margin. "Most companies lose money" and "the sector makes money" are both true.
4. **Unprofitability concentrates in R&D and exploration:** mining 91.7% unprofitable (11 of 12), pharma 68.2% (30 of 44), instruments 66.7% (12 of 18), business services 60.0% (33 of 55). Banks are lowest at 21.4% (3 of 14).
5. **Thin-margin giants are a business model, not distress.** The high-revenue, low-profit quadrant is wholesale and food distribution by design: Cardinal Health 0.38% margin on $227B revenue, Sysco 2.48%, Performance Food 0.75%.
6. **Paper profits — profitable but cash-weak:** Super Micro, $1.15B net income but -$2.49B operating cash flow (conversion -2.16); Nutanix converts only 45% of $1.51B profit. The reverse also appears: United Natural Foods loses $1.12B yet generates $2.53B in operating cash. Profit and cash diverge in both directions. Note on Nutanix: ~$1.2B of its $1.51B profit is a one-time tax benefit (release of a valuation allowance on deferred tax assets), so the low conversion partly reflects non-cash profit, not just weak collections — the flag still stands, but the cause matters.
7. **The quality archetype:** Microsoft — $245B revenue, 36.0% margin, 1.35 cash conversion. Caution on conversion alone: Cardinal Health's 4.42 conversion reflects tiny profit against large cash flow (thin-margin arithmetic), not superior quality — read conversion alongside margin.

## The screen
- **Quality:** large + profitable + cash conversion near or above 1 (Microsoft-type).
- **Investigate the model:** large + thin or negative margin (distribution-type) — understand the model before judging it.
- **Red flag:** profitable + conversion well under 0.5 or negative (Super Micro-type) — dig into receivables, inventory, and working capital.
- **Exclude or adjust:** funds (e.g., Golub Capital's -70.28 conversion is a fund-accounting artifact, not a flag) and pre-revenue firms (judge on burn and runway, not margins).

## Limitations
- Single quarter (2026 Q3). Q3 10-K filers are disproportionately June year-end companies (hence Microsoft, P&G, Nike in the sample) — not a random cross-section of the market.
- Finance firms and pre-revenue firms are structurally underrepresented in margin analysis (different income concepts, or no revenue line). 80 companies have no revenue tag; they cluster in pharma/biotech (likely pre-revenue), finance, and mining.
- One year of data; no trend over time.
- Revenue is the largest reported revenue tag per company (documented assumption); segment-level facts excluded.
- 4 companies have no SIC code and drop out of sector analysis; some companies lack a net income tag (e.g., Parker-Hannifin: revenue present, net income NULL).

## Reproducibility
SQL: `sec_analysis.sql` in this repo (view build plus all six analyses). Data: SEC Financial Statements Data Sets, 2026 Q3, from https://www.sec.gov/dera/data/financial-statement-data-sets.html

To rerun: download the 2026 Q3 zip, import `sub.txt`, `num.txt`, `tag.txt` into SQLite (tab-separated, headers on), create the `idx_num_tag` and `idx_num_adsh` indexes, then run `sec_analysis.sql` top to bottom. The raw data files are not in this repo (the NUM table alone is ~875 MB); the `.gitignore` keeps the database and source files out.
