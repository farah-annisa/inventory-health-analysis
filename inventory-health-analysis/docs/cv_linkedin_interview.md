# CV lines, LinkedIn post and interview story

This is a self-directed project on public data. Put it under **Projects**, not Experience, and call the money figures estimates.

## CV lines

**Data analyst version**
> **Inventory Health & Replenishment Analysis** · Python, SQL, Excel, Power BI · github.com/Farah-Annisa/inventory-health-analysis
> - Analysed 11.8M rows of daily Walmart sales (16,120 item-store lines) in SQL and Python; estimated $360K (1.8% of revenue) lost to 6,642 likely stockouts in one year.
> - Showed that 34% of the loss came from gaps hitting 3+ stores at once, a supplier issue rather than a store one, with a SQL self-join over overlapping date ranges.
> - Built a Power BI dashboard (star schema, 17 DAX measures) and an Excel reorder-point planner with what-if analysis for 6,168 top-selling lines.

**Business analyst version**
> **Inventory Replenishment Review Redesign** · requirements, process mapping, KPI design, SQL, Power BI · github.com/Farah-Annisa/inventory-health-analysis
> - Defined KPIs, 7 user stories with acceptance criteria and an as-is/to-be weekly review for inventory planners and buyers.
> - Quantified $360K of estimated lost sales and prioritised 5 actions with owners, including a supplier alert targeting $121K of losses.

## LinkedIn post

> Empty shelves don't show up in sales reports. Zeros do.
>
> I analysed two years of daily sales for 16,120 Walmart item-store lines (public M5 data on Kaggle) to find where sales were lost to stockouts.
>
> What I found:
> • An estimated $360K of sales lost in one year, 1.8% of revenue
> • 34% of it came from gaps that hit 3 or more stores at the same time, which points to suppliers, not stores
> • The busiest store lost 2.6% of revenue against a 1.8% average
>
> How: SQL (gaps-and-islands plus a Poisson test) to find zero-sale runs that were near-impossible if the item was on the shelf, Python for the checks and charts, a Power BI dashboard for managers, and an Excel reorder-point planner for buyers.
>
> One lesson: the 50 worst gaps held only 10% of the loss. The fix is a weekly routine, not firefighting.
>
> Code, dashboard and write-up: github.com/Farah-Annisa/inventory-health-analysis
>
> #DataAnalytics #SQL #PowerBI #Excel #Python #SupplyChain #Retail

Attach one image: `images/03_network_gaps.png` or a Power BI screenshot.

## Interview story (90 seconds)

1. **Problem.** "Retailers lose sales when shelves are empty, but sales data only shows zeros, not why."
2. **What I did.** "I loaded two years of daily Walmart sales into DuckDB, found runs of zero sales with SQL, and tested each run against the item's normal sales: if it would sell 5 a day, three empty days in a row almost never happen by chance."
3. **Judgment call.** "Testing every gap at a 1% bar would flag thousands by luck, so I used 1 in 100,000 and showed the result at four bars. I also left out days inside stockouts when estimating demand, because empty shelves record zero sales."
4. **Result.** "About $360K lost in a year. A third came from gaps in 3+ stores at once, so I recommended a supplier alert, not more store training. I built a Power BI dashboard and an Excel planner that tells a buyer when to reorder and how much."
5. **Link to my experience.** "At PNB I cut weekly sales-performance reporting from three days to one by automating it. This project applies the same discipline to stock."

**Rehearse these follow-ups**
- *Why this scope?* Non-food lines are closest to a home-improvement retailer, and two years keeps it fast.
- *What would you change with real company data?* Validate flags against stock-on-hand, add supplier lead times and promotions.
- *Which number do you trust least?* Lost revenue: it depends on the Poisson baseline, which is why it is labelled an estimate and shown at four test levels.
- *Why DuckDB?* Free, runs locally, standard SQL; the same queries port to SQL Server or BigQuery with small changes.
- *Show me.* Open the Excel planner, pick CA_3 · HOUSEHOLD_1_106 and change the lead time.

## Recruiter follow-up (for roles you already applied to)

> Subject: [Role] application · inventory analysis project
>
> Hi [Name], I applied for the [role] position on [date]. Since then I built an inventory-health analysis on public Walmart data: an estimated $360K of lost sales found, a third traced to supplier-side gaps, plus a Power BI dashboard and an Excel reorder planner. It mirrors the role's work on [reorder points / stock availability / dashboards]. Project: github.com/Farah-Annisa/inventory-health-analysis. I would welcome the chance to discuss it.
>
> Best regards,
> Farah Norhisham · [phone] · linkedin.com/in/farahannisa-norhisham
