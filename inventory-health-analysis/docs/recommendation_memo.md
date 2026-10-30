# Memo: cutting sales lost to empty shelves

**To:** Head of Inventory Planning · **From:** Farah Norhisham, Data Analyst · **Re:** Household and Hobbies, 10 stores, 52 weeks to 22 May 2016

## Bottom line

We lost an estimated **$360K of sales (1.8% of revenue)** to 6,642 likely stockouts last year. A third of it came from supply-side gaps that hit several stores at once. I recommend three changes, starting next week: a network-gap alert to buyers, a CA_3 replenishment review, and variability-based reorder points for our top sellers.

## What the data shows

1. **The loss is real but conservative.** A stockout is flagged only when a zero-sales run would have under a 1-in-100,000 chance if the item were on the shelf. Even a ten-times stricter test keeps $291K.
2. **A third is a supply problem.** Gaps where the same item was out in 3+ stores at once caused $121K (34%) of the loss. One household item went to zero in all 10 stores for two weeks in late August 2015.
3. **One store stands out.** CA_3, our busiest store, loses 2.6% of revenue, against 1.8% for the chain; its Household 1 department alone lost $64K.
4. **There is no quick fix.** The 50 costliest gaps hold only 10% of the loss. The average gap lasts 9 days, which points to a missing weekly routine, not a few bad events.
5. **Erratic top sellers lose most.** AZ lines lose 4.0% of their revenue and AY lines 2.9%, against 1.3% for steady AX lines. Simple forecasts are out by 71% on erratic lines, so they need buffer stock rather than tighter forecasts.

## Recommendations

| Action | Owner | Start | Expected effect |
|---|---|---|---|
| Alert the buyer within 48 hours when an item goes to zero in 3+ stores; escalate to the supplier | Buyer | Week 1 | Targets the $121K of network-gap losses |
| Review CA_3 order frequency and Household 1 shelf capacity | Store operations, planning | Week 2 | About $28K a year if CA_3 reaches the chain average |
| Set reorder points from demand variability for 6,168 A-item lines, AY and AZ first (Excel planner) | Inventory planning | Weeks 2–4 | Up to about $100K a year if AY and AZ lose no more than AX |
| Run a weekly exception list (47 lines were out of stock on the last day) | Inventory planning | Week 1 | Shorter gaps; fewer lost days |
| Clear 27 dead lines, review 305 slow ones, move CZ lines to order-on-demand | Category management | Month 2 | Frees shelf space and cash |

The effects overlap, so they should not be added together.

## Risks and what I would check next

- **No stock records:** compare the flagged gaps with stock-on-hand for one store before rolling out.
- **Lead times are assumed** (3, 7 and 14 days): ask buyers for actual supplier lead times and update the planner.
- **Long gaps** (2,635 runs over 28 days, up to $845K) are excluded as possible range changes; category managers should confirm which were real stockouts.

*Data: M5 Forecasting – Accuracy (Walmart, Kaggle). Method, code and dashboard: see the repository README.*
