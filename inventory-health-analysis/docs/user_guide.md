# User guide: Excel planner and Power BI dashboard

## Which tool for which job

| You want to… | Use |
|---|---|
| See how much we lose and where, filter by store or department | Power BI · Overview |
| Decide whether to order an item today, and how much | Excel · Planner |
| Find this week's costliest or still-open gaps | Excel · Out of stock now · or Power BI · Stockouts & reorder |
| Review slow and dead lines | Excel · Range review · or Power BI · Range health |

## Excel planner (`excel/Inventory_Replenishment_Planner.xlsx`)

1. Open the **Planner** sheet. Yellow cells with blue text are inputs; everything else is a formula.
2. Pick a **store**, then an **item**. The item list only shows that store's A-items (the top 80% of its revenue).
3. Enter the **supplier lead time**, the **service level** (95% means running out in 1 replenishment cycle in 20), today's **stock on hand** and how many days each order should **cover**.
4. Read the decision: **REORDER NOW** (red) when stock is at or below the reorder point, with the suggested order quantity; otherwise **OK** (green).
5. The **what-if grid** shows how the reorder point moves with lead time and service level; the chart shows the item's last 26 weeks of sales.

Example: CA_3 · HOUSEHOLD_1_106 sells 16.6 units a day (standard deviation 9.4). At a 7-day lead time and 95% service, the reorder point is 158 units. With 20 on hand (1.2 days of cover) the planner says reorder 372 units.

## Power BI dashboard (`powerbi/InventoryHealth.pbip`)

- **Overview:** six headline cards, weekly revenue, lost revenue % by store and department, and lost revenue by the number of stores out at once. Use the store and department slicers on the right.
- **Range health:** the ABC–XYZ matrix, the planning rule for each segment, and the slow and dead lines to review.
- **Stockouts & reorder:** the watchlist sorted by lost revenue, lost % by segment, and reorder points. Pick one lead time in the slicer; filter network gaps to see supply-side problems only.

Setup and refresh steps: [powerbi/README.md](../powerbi/README.md).

## Definitions shown on both

- **Likely stockout:** zero sales for 2+ days while the item was listed and the store open, with under a 1-in-100,000 chance if it had been on the shelf. Gaps over 28 days are excluded as possible range changes.
- **Est. lost revenue:** normal daily units × days out × shelf price. It is an estimate; validate against stock records before acting on single lines.
- **Network gap:** the same item out in 3 or more stores at once. Escalate to the buyer and supplier.
- **Reorder point:** average daily demand × lead time + safety stock, where safety stock = z × standard deviation of daily demand × √lead time.
