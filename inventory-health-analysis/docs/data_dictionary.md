# Data dictionary

## Raw tables (DuckDB, built by notebook 01)

| Table | Grain | Columns |
|---|---|---|
| `sales_daily` | item × store × day (11,767,600 rows) | item_id, store_id, date, units |
| `items` | item (1,612) | item_id, dept_id, cat_id |
| `stores` | store (10) | store_id, state_id |
| `calendar` | day (730) | date, wm_yr_wk (Walmart week, starts Saturday), weekday, wday, month, year, event_name_1, event_type_1, event_name_2, event_type_2, snap_CA, snap_TX, snap_WI |
| `prices` | item × store × week | store_id, item_id, wm_yr_wk, sell_price (no row = not listed that week) |

## Analysis tables (SQL scripts)

| Table | Script | Grain | Key columns |
|---|---|---|---|
| `v_store_days` (view) | 01 | store × day | store_units, store_open (false when sales < 10% of the store's average) |
| `v_sales_daily` (view) | 01 | item × store × day | adds dept, state, weekday, events, snap_day, store_open, sell_price, on_shelf, revenue |
| `mart_item_store_week` | 03 | item × store × week | week_start, days_in_week, units, revenue, days_listed, zero_sale_days_listed, avg_price |
| `abc_xyz` | 04 | item × store | revenue_52w, units_52w, avg_weekly_units, cv_weekly_units, weeks_listed, abc, xyz |
| `abc_xyz_matrix` | 04 | segment (9) | item_stores, revenue_52w, pct_of_revenue, planning_rule |
| `stockout_runs` | 05 | zero-sale run | run_start, run_end, run_days, baseline_daily_units, chance_if_in_stock, est_lost_units, est_lost_revenue, likely_cause, ongoing_at_data_end |
| `stockout_network` | 06 | likely stockout run | stores_out_together, network_gap (3+ stores) |
| `slow_dead_stock` | 07 | item × store | units_13w, units_26w, revenue_52w, last_sale_date, days_since_last_sale, current_price, stock_status |
| `demand_drivers` | 08 | event or SNAP × department | driver_type, driver, driver_group, days, avg_uplift |
| `reorder_points` | 09 | A-item × store × lead time | lead_time_days, avg_daily_demand, sd_daily_demand, safety_stock_units, reorder_point_units |

## Output tables (script 10, exported to `data/processed/` by notebook 03)

| File | Rows | Used by | Notes |
|---|---|---|---|
| `dash_kpis.csv` | 1 | README, memo | Headline numbers for the last 52 weeks |
| `dash_item_store_summary.csv` | 16,120 | Excel, Power BI | One row per item-store: segment, stock status, stockouts, lost sales, network losses, out_of_stock_now, demand statistics, reorder points at 3/7/14 days |
| `dash_stockouts_52w.csv` | 6,642 | Power BI | Every likely stockout of the last 52 weeks, with segment and stores_out_together |
| `dash_weekly_sales.csv` | 4,160 | Power BI | Units and revenue by store, department and full week |
| `dash_lost_sales_by_store.csv` | 40 | Reference | Revenue, stockouts and lost revenue by store and department |
| `dash_slow_dead.csv` | 332 | Reference | Slow, dead and delisted lines |
| `abc_xyz_matrix.csv` | 9 | Power BI | Segment dimension with planning rules |
| `reorder_points.csv` | 18,504 | Power BI | A-item reorder points at 3, 7 and 14 days |
| `demand_drivers.csv` | 124 | Power BI | Event and SNAP uplift by department |
| `dim_item.csv`, `dim_store.csv`, `dim_date.csv` | 1,612 / 10 / 730 | Power BI | Dimensions |
| `forecast_accuracy.csv` | 4 | README | WAPE by XYZ class for three forecasting methods |
| `stockout_test_sensitivity.csv` | 4 | README | Stockouts and lost revenue at four chance bars |

## Definitions

- **Listed:** the item has a shelf price that week in that store.
- **Last 52 weeks:** the 52 full Walmart weeks to 20 May 2016 for revenue; runs starting after 24 May 2015 for stockouts.
- **Likely stockout:** a run of 2+ zero-sale days (item listed, store open, after the item's first sale) whose Poisson chance under the 8-week baseline is below 1 in 100,000, lasting 28 days or less.
- **Network gap:** a likely stockout during which the same item was also out in at least two other stores (3+ stores in total).
- **Est. lost revenue:** baseline daily units × days out × average shelf price during the gap.
