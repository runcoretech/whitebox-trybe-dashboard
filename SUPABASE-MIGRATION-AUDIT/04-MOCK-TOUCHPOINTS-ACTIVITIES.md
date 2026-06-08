# 04 — Mock Touchpoints & Activity Data

## Data Location

**File:** [main-dashboard-v34.js](file:///c:/Users/paulk/OneDrive/Desktop/WHITEBOX%20GIFTWORKS%20PROJECT/dashboard/main-dashboard-v34.js)  
**Variables:** `clientGraphData` and `employeeSectorTimeframeData` (starts at ~line 55872)

## A. `clientGraphData` — Per-Client Touchpoint Timelines

This is a massive object keyed by organization name. Each entry contains an array of touchpoint objects forming the client's timeline history.

### Structure Per Touchpoint Entry

| Field | Type | Example | Description |
|:------|:-----|:--------|:------------|
| `type` | string | `"Call"`, `"Email"`, `"Meeting"`, `"Proposal"`, `"Gift"` | Activity type |
| `date` | string | `"Feb 15"` | Date of activity |
| `grade` | string | `"A"` | Quality grade assigned |
| `count` | number | `3` | Number of contacts reached |
| `notes` | string | `"Discussed Q2 renewal..."` | Free-text description |
| `rep` | string | `"Tom Collins"` | Rep who performed the activity |

### Known Clients With Timeline Data

Based on code inspection, the following organizations have timeline entries in `clientGraphData`:

- Apex Global Retail
- Chevron Solutions
- Initech Software
- Wayne Enterprises
- Stark Industries
- Tyrell Corporation
- Apex Systems
- Zenith Corp
- Vanguard Health
- OmniCorp
- Chevron Logistics
- TechFlow Inc
- Pinnacle Brands
- Orion Biotech
- Nova Financial / Nova Healthcare
- BlueStar Retail
- Peak Financial

### Example Entry

```javascript
"Apex Global Retail": [
    { type: "Call", date: "May 20", grade: "A", count: 2,
      notes: "Discussed Q2 renewal pipeline with procurement VP.", rep: "Sarah Lansky" },
    { type: "Email", date: "May 15", grade: "A", count: 3,
      notes: "Follow-up on signed agreement. Shared fulfillment timeline.", rep: "Sarah Lansky" },
    { type: "Gift", date: "Feb 15", grade: "A", count: 3,
      notes: "System auto-delivery: Dispatched Premium Box containing premium corporate confectioneries.",
      rep: "Milestone Automation" },
    // ... more entries
]
```

## B. `employeeSectorTimeframeData` — Per-Employee Activity Aggregates

This object provides activity data organized by employee name, sector, and timeframe. Used by the employee detail panel charts.

### Structure

```javascript
employeeSectorTimeframeData = {
    "Tom Collins": {
        "healthcare": { "week": {...}, "month": {...}, "quarter": {...} },
        "technology": { "week": {...}, "month": {...}, "quarter": {...} }
    },
    "Sarah Lansky": { ... },
    // etc.
}
```

## C. Hardcoded Health Scores in Detail Panel

**File:** `main-dashboard-v34.js`

When a client detail panel opens, health scores are hardcoded by grade:

| Grade | Health Score | Line References |
|:------|:------------|:---------------|
| A | `98%` | Lines 55104, 73850, 75682 |
| F | `38%` | Line 55216 |
| C (default) | `74%` | Line 55344 |

These are set via:
```javascript
if (selectedGrade === 'A') detailHealthScore.textContent = '98%';
else if (selectedGrade === 'F') detailHealthScore.textContent = '38%';
else detailHealthScore.textContent = '74%';
```

## D. `getInactivityStatus()` — Hardcoded Thresholds

**File:** `main-dashboard-v34.js`, Line 121418

```javascript
function getInactivityStatus(days) {
    if (days >= 60) return 'red';    // Critical neglect
    if (days >= 30) return 'orange'; // Warning
    return 'green';                   // Healthy
}
```

These defaults (30/60) are overridable via `window.rmosSettings.decayWarning` and `window.rmosSettings.decayCritical` from the Settings panel (see Section 11).

## E. `recordBelongsToRep()` — Role-Based Record Ownership

**File:** `main-dashboard-v34.js`, Lines 81251 and 101306

This function determines whether a touchpoint record belongs to the active representative. It's used throughout the dashboard to filter gifts, dispatches, and timeline entries.

```javascript
function recordBelongsToRep(item, activeRepName = 'Tom Collins') {
    // Checks if item.client or item.rep matches the current user or their managed reports
}
```

> [!NOTE]
> Default fallback is `'Tom Collins'` — the rep-level demo user.

---

## Supabase Migration Notes

| Current | Target |
|:--------|:-------|
| `clientGraphData` nested JS object | `activities` table with `contact_id`, `rep_id`, `type`, `grade`, `notes`, `logged_at` |
| `employeeSectorTimeframeData` nested object | SQL aggregate views grouped by `rep_id`, sector, and date range |
| Hardcoded health scores (98%, 38%, 74%) | Computed from `activities` table: weighted touchpoint recency + grade quality |
| `getInactivityStatus(days)` hardcoded thresholds | `workspace_settings` table with configurable thresholds, computed from `MAX(activities.logged_at)` |
| `recordBelongsToRep()` string matching | RLS policies: `assigned_rep_id = auth.uid()` or manager hierarchy join |
