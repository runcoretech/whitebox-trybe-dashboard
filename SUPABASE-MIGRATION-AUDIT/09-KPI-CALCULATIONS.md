# 09 — KPI Calculations & Metrics

## A. Dashboard KPI Cards

### Gifts Sent & Spend Outlay KPI

**File:** [main-dashboard-v34.js](file:///c:/Users/paulk/OneDrive/Desktop/WHITEBOX%20GIFTWORKS%20PROJECT/dashboard/main-dashboard-v34.js)

| Role | Gifts Sent Default | Spend Outlay Default | DOM Elements |
|:-----|:-------------------|:---------------------|:-------------|
| Owner | `142` | `$4,850.00` | `.kpi-gifts-sent-count`, `.kpi-gifts-spend-value` |
| Executive (HR) | `142` | `$4,850.00` | Same elements |
| Manager | `23` | `$1,654.00` | Same elements |
| Rep | `23` | `$1,654.00` | Same elements |

**How These Are Read:**
The KPI values are rendered into the DOM via hardcoded HTML, then scraped dynamically by other components:
```javascript
// Spend ledger reads KPI to determine how many rows to generate
const giftsSent = parseInt(document.querySelector('.kpi-gifts-sent-count').textContent);
const spendOutlay = parseFloat(document.querySelector('.kpi-gifts-spend-value').textContent.replace(/[$,]/g, ''));
```

### Additional KPI Cards (Hardcoded in HTML)

These are rendered in the `dashboard/index.html` KPI row:

| KPI Card | Owner/Exec Value | Manager/Rep Value | Description |
|:---------|:-----------------|:------------------|:------------|
| Total Gifts Sent | 142 | 23 | Count of all dispatched gifts |
| Spend Outlay | $4,850.00 | $1,654.00 | Total dollar value of gifts |
| Active Customers | 6 | varies by role filter | Count of active client accounts |
| Active Prospects | 6 | varies by role filter | Count of active prospect accounts |
| Neglected Accounts | computed | computed | Count where `inactiveDays >= decayCritical` |
| Recovery Queue | computed | computed | Count of accounts in recovery board |

### Neglected Accounts / Recovery Queue Computation

**Lines ~121045, 121133, 121214:**
```javascript
const recoveryQueue = allActive.filter(a =>
    a.inactiveDays >= (window.rmosSettings ? window.rmosSettings.decayCritical : 60)
    || (window.recoveryBoardClients && window.recoveryBoardClients.includes(a.name))
).length;
```

This counts accounts where inactivity exceeds the critical threshold (default 60 days) OR accounts manually added to the recovery board.

## B. SVG Graph Generation

**File:** [main-theme-v34.js](file:///c:/Users/paulk/OneDrive/Desktop/WHITEBOX%20GIFTWORKS%20PROJECT/public-website/main-theme-v34.js)

Generates line curves and bar columns dynamically via SVG templates:
- `maxTotal` is extracted from data array reductions
- Heights and offsets calculated using `(value / maxTotal) * graphHeight`
- Data comes from the same `clientGraphData` / `employeeSectorTimeframeData` arrays

## C. Conversion Rate Dial

**File:** `main-dashboard-v34.js`, around Line 51321

The circular dial "Conversion Rate" widget displays a hardcoded percentage derived from the grade of the currently selected client:

| Grade | Implied Conversion Rate |
|:------|:----------------------|
| A | ~95–98% |
| C | ~64–74% |
| F | ~30–38% |

## D. Spend Ledger Totals Balancing

**File:** [spend-ledger-modal.js](file:///c:/Users/paulk/OneDrive/Desktop/WHITEBOX%20GIFTWORKS%20PROJECT/dashboard/spend-ledger-modal.js)

The spend ledger modal ensures totals **always balance perfectly** with the KPI card:

1. Reads active KPI "Gifts Sent" count and "Spend Outlay" value from the DOM
2. Scrapes existing visible rows in `#spend-ledger-rows`
3. Computes `remainingSpend = totalOutlay - scrapedTotal`
4. Computes `itemsToGenerate = giftsSent - scrapedCount`
5. Generates filler rows with `avgRemainingOutlay = remainingSpend / itemsToGenerate`
6. Applies variance `[-15, 5, 20, -10, -5, 10, -5]` that sums to 0, ensuring perfect balance

This means the ledger total ALWAYS matches the KPI card — even though the individual rows are generated at runtime.

## E. Composite Performance Score

Used in the employees leaderboard, this is a pre-calculated number per employee:

```
composite = weighted_average(touchpoints, health, prospects, clients)
```

Currently hardcoded per employee per timeframe (e.g., Sarah Lansky = 98, Marcus Dupond = 91, Tom Collins = 84).

## F. Health Score Ring

The circular health ring in client/employee detail panels:

```javascript
const healthScoreInt = parseInt(health) || 90;
const strokeDashOffset = 251.2 * (1 - healthScoreInt / 100);

// Color thresholds
if (healthScoreInt >= 80) detailHealthFill.style.stroke = '#10b981'; // green
else if (healthScoreInt >= 60) detailHealthFill.style.stroke = '#f59e0b'; // amber
else detailHealthFill.style.stroke = '#ef4444'; // red
```

---

## Supabase Migration Notes

| Current | Target |
|:--------|:-------|
| Hardcoded KPI values (142, $4,850) | `SELECT COUNT(*), SUM(amount) FROM gifts WHERE status = 'Delivered'` |
| DOM scraping for KPI values | Direct Supabase query, values passed as props |
| Spend ledger filler generation | Eliminated — all rows from `gifts` table |
| Variance array `[-15,5,20,-10,-5,10,-5]` | Eliminated — real amounts |
| Hardcoded composite scores | Computed via weighted SQL formula |
| Health ring thresholds (80/60) | Preserved in client-side rendering, data from DB |
| Recovery queue computation | `SELECT COUNT(*) FROM contacts WHERE last_activity < NOW() - INTERVAL '60 days'` |
