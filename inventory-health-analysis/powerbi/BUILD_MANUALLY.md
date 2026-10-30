# Build the dashboard by hand (fallback, about 45 minutes)

Use this only if `InventoryHealth.pbip` will not open in your Power BI Desktop. It rebuilds the same model and pages from the CSV files in `data/processed/`.

## 1. Load the data

**Home → Get data → Text/CSV**, then **Transform data** for each file:

| Power BI table | File | Power Query steps |
|---|---|---|
| Store | `dim_store.csv` | Rename `store_id` → Store, `state_id` → State |
| Department | `dim_item.csv` | Keep `dept_id`, `cat_id` · Remove duplicates · Rename → Department, Category |
| Segment | `abc_xyz_matrix.csv` | Keep `segment`, `abc`, `xyz`, `planning_rule` · Rename → Segment, ABC, XYZ, Planning rule |
| Date | `dim_date.csv` | Rename `date` → Date, `week_start` → Week start |
| Item Store | `dash_item_store_summary.csv` | Rename `item_id` → Item; give numeric columns readable names |
| Stockouts | `dash_stockouts_52w.csv` | Rename `item_id` → Item, `run_start` → Gap start, `run_days` → Days out, `est_lost_revenue` → Est lost revenue, `stores_out_together` → Stores out together, `network_gap` → Network gap, `ongoing_at_data_end` → Still open |
| Weekly Sales | `dash_weekly_sales.csv` | Rename `revenue` → Revenue, `units` → Units |
| Reorder Points | `reorder_points.csv` | **Add column** `segment` = `[abc] & [xyz]` · Rename `lead_time_days` → Lead time (days), `safety_stock_units` → Safety stock (units), `reorder_point_units` → Reorder point (units) |
| Demand Drivers | `demand_drivers.csv` | Rename `avg_uplift` → Avg uplift |

Set data types when Power Query asks (dates as Date, money and units as Decimal number, flags as True/False). Then **Close & Apply**.

## 2. Model

- **Relationships** (Model view, many-to-one, single direction):
  `store_id` in Item Store, Stockouts, Weekly Sales and Reorder Points → Store[Store];
  `dept_id` in all five fact tables → Department[Department];
  `segment` in Item Store, Stockouts and Reorder Points → Segment[Segment];
  Stockouts[Gap start] → Date[Date]; Weekly Sales[week_start] → Date[Date].
- **Date table:** select Date → Table tools → Mark as date table → Date.
- **Hide** the `_id`, `abc`, `xyz` and `segment` columns in the fact tables, so report authors use the dimensions.
- **Measures:** Home → Enter data → name the table *Key Measures* → Load. Add each measure from `measures.dax` (New measure, paste, set the format shown in the comment). Hide the empty column.
- **Theme:** View → Themes → Browse for themes → `InventoryHealth.Report/StaticResources/RegisteredResources/InventoryHealthTheme.json`.

## 3. Pages (16:9)

**Overview**
- Six cards: Revenue (52w), Lost revenue (est.), Lost revenue %, Likely stockouts, Network gap share, Out of stock now
- Line chart: X = Date[Week start], Y = Weekly revenue, Legend = Department[Category]
- Bar chart: Y-axis = Store[Store], X = Lost revenue %, sorted descending, data labels on
- Bar chart: Department[Department] by Lost revenue %
- Column chart: X = Stockouts[Stores out together], Y = Lost revenue (est.), sorted by the axis
- Drop-down slicers: Store[Store], Department[Department]

**Range health**
- Matrix: Rows = Segment[ABC], Columns = Segment[XYZ], Values = Revenue share
- Table: Segment[Segment], Segment[Planning rule], Item-store lines, Revenue share, Lost revenue %
- Cards: Dead lines, Slow lines
- Table: Store[Store], Item Store[Item], Stock status, Units 13w, Days since last sale, Revenue 52w, Shelf price; filter Stock status is not Active

**Stockouts & reorder**
- Table: Store[Store], Stockouts[Item], Segment[Segment], Gap start, Days out, Normal daily units, Est lost revenue, Stores out together; sort by Est lost revenue descending
- Bar chart: Segment[Segment] by Lost revenue %
- Table: Store[Store], Reorder Points[Item], Segment[Segment], Lead time (days), Avg daily demand, Safety stock (units), Reorder point (units)
- Slicers: Reorder Points[Lead time (days)] (single select), Stockouts[Network gap], Store[Store]

Check the Overview cards against the table in [README.md](README.md), then save as `InventoryHealth.pbix`.
