# 16 — Final Sweep: Deep-Code Findings

> [!IMPORTANT]
> This document captures **10 additional data structures** found during the third and final exhaustive code sweep. These were buried deep inside `main-dashboard-v34.js` and were not caught by previous audits because they use non-standard variable naming conventions.

---

## K. `employeeSectorTimeframeData` — Per-Employee Activity Timelines

**File:** [main-dashboard-v34.js](file:///c:/Users/paulk/OneDrive/Desktop/WHITEBOX%20GIFTWORKS%20PROJECT/dashboard/main-dashboard-v34.js), Lines 57072–58896

**~1,824 lines** of hardcoded per-employee, per-sector, per-timeframe activity timeline data.

### Structure
```javascript
const employeeSectorTimeframeData = {
    "Tom Collins": {
        "prospects": {
            "last5": [
                { type: "Email", date: "Jan 10", grade: "C", count: 2,
                  notes: "Prospect outreach. Receptive but cautious.",
                  rep: "Tom Collins" },
                { type: "Call", date: "Feb 12", grade: "F", count: 1,
                  notes: "Follow-up conversation. Moderate pricing friction.",
                  rep: "Tom Collins" },
                // ...
            ],
            "last10": [...],
            "last20": [...],
            "all": [...]
        },
        "customers": {
            "last5": [...],
            // ...
        }
    }
    // Additional employees...
};
```

**Employee contained:** Tom Collins (only explicitly keyed employee found — structure supports dynamic lookup)

### Consumer Function
- **`getEmployeeGraphHistory(empName, sector, timeframe)`** (Line 58928): Returns the matching timeline array for a given employee, sector (prospects/customers), and timeframe window.

### Migration Note
Replace with SQL query: `SELECT * FROM activities WHERE rep_id = ? AND contact_type = ? ORDER BY created_at DESC LIMIT ?`

---

## L. `calendarEventsDB` — Per-Entity Gift Calendar Schedule

**File:** `main-dashboard-v34.js`, Lines 116195–118970

A massive hardcoded object mapping entity names (clients, employees, owner) to scheduled gift `send` and `receive` arrays.

### Entities Found

| Entity Name | Type | Lines |
|:------------|:-----|:------|
| Apex Global Retail | Client | 116211 |
| Stripe Canada | Client | 117699 |
| Paul K. | Owner | 117779 |
| Sarah Lansky | Employee | 117939 |
| Emily Davis | Employee | 118099 |
| Marcus Dupond | Employee | 118243 |
| Jane Smith | Employee | 118387 |
| Tom Collins | Employee | 118531 |

### Entry Structure
```javascript
"Apex Global Retail": {
    send: [
        { day: 5, box: "Premium Box", recipient: "Apex Executive Suite",
          reason: "Strategic Partner Q2 Milestone Appreciation",
          status: "scheduled", date: "June 5, 2026" },
        { day: 15, box: "Sweet Box", recipient: "Customer Success Team",
          reason: "Quarterly Service Excellence Appreciation",
          status: "scheduled", date: "June 15, 2026" }
    ],
    receive: [
        { day: 1, box: "Sweet Box", sender: "WhiteBox Team",
          reason: "CEO Monthly Welcome and Operational Health Box",
          status: "scheduled", date: "June 1, 2026" }
    ]
}
```

### Migration Note
Replace with `calendar_events` table query filtered by entity and month.

---

## M. `activeB2BOrders` — Active Gift Orders Queue

**File:** `main-dashboard-v34.js`, Lines 77075+

Hardcoded object containing active B2B gift orders displayed in the Gifting Dispatch panel.

### Known Order Keys
- `order-chevron` → Chevron Logistics

### Fields Per Order
| Field | Example |
|:------|:--------|
| `orderId` | `'order-chevron'` |
| `recipientName` | `'Chevron Logistics'` |
| `recipientScale` | `'team'` |
| Additional fields | box type, dispatch date, status, finalized flag |

### Migration Note
Replace with `gifts` table query where `status = 'pending'`.

---

## N. `categorySpends` — Budget Category Allocation

**File:** `main-dashboard-v34.js`, Lines 76594–76674

```javascript
const categorySpends = {
    reach: 2840,
    retain: 4150,
    reward: 1580,
    remember: 850
};
```

These are the hardcoded spend amounts for the 4R gifting categories (Reach, Retain, Reward, Remember) displayed in the Spend Breakdown donut chart.

**Total:** $9,420

### Migration Note
Replace with `SELECT category, SUM(amount) FROM gifts GROUP BY category`.

---

## O. `mockSectors` — Default Sector Timeline Fallback

**File:** `main-dashboard-v34.js`, Lines 59024+

When `employeeSectorTimeframeData` doesn't contain an employee, `mockSectors` provides a generic fallback with sector-level activity timelines for prospects and customers.

### Migration Note
Same as `getClientHistory()` fallback — eliminate when real data is available.

---

## P. `bonusRep4` through `bonusRep10` — 7 Phantom Employees

**File:** `main-dashboard-v34.js`, Lines 196371–196467

**7 additional mock employees** that only appear in the Owner/Executive overview leaderboard when the system needs to display a full 10-person leaderboard. These employees are NOT in `employeesData`.

| Rank | Name | Composite | Touchpoints | Prospects | Clients | Health |
|:-----|:-----|:----------|:------------|:----------|:--------|:-------|
| 4 | Jack R. | 76 | 28 | 4 | 2 | 80 |
| 5 | Anna L. | 72 | 19 | 2 | 1 | 78 |
| 6 | Jane Smith | 68 | 12 | 3 | 1 | 74 |
| 7 | David K. | 65 | 10 | 6 | 1 | 72 |
| 8 | Elena M. | 61 | 8 | 4 | 1 | 70 |
| 9 | Robert P. | 58 | 7 | 3 | 0 | 68 |
| 10 | Lisa T. | 52 | 5 | 2 | 0 | 65 |

### Related Data
```javascript
const mockReps = ['Sarah Lansky', 'Tom Collins', 'Marcus Dupond',
    'Jack R.', 'Anna L.', 'Gregory Sterling'];
```
(Line 198786) — Used to attribute actions in the Activity Log panel.

### Migration Note
Eliminate phantom reps — leaderboard reads from `profiles` table. Row count equals actual employee count.

---

## Q. `activeAuditsDB` — Cosmo AI Audit Narratives

**File:** `main-dashboard-v34.js`, Lines 227125–227301

Hardcoded AI-generated narrative strings for the Cosmo AI Audit panel, keyed by entity name.

| Entity | Narrative Summary |
|:-------|:-----------------|
| Dwight Schrute | Active, 14 touches, 0% conversion rate. Sync session recommended. |
| Sarah Lansky | Resolved 14 at-risk warnings in 4 days. Wellness reward recommended. |
| Vanguard Health | 34 days neglected. Reassign to Paul K. (CEO). |
| Vanguard Logistics | Duplicate of Vanguard Health narrative. |
| Nova Financial | Q3 contract renewal approaching. 91% health. Gifting sync advised. |
| Nova Healthcare | Duplicate of Nova Financial narrative. |
| Chevron Logistics | 42 days, zero manual touches. Premium box required. |
| Chevron Solutions | Duplicate of Chevron Logistics narrative. |
| Apex Solutions | Health decayed to 82%. Physical intro converts 2.8x faster. |
| Apex Global Retail | Duplicate of Apex Solutions narrative. |

> [!NOTE]
> Several entities have duplicate entries with slight name variations (e.g., "Vanguard Health" / "Vanguard Logistics", "Nova Financial" / "Nova Healthcare"). This appears to be intentional fuzzy matching to ensure the AI panel renders regardless of which name variant the user clicks.

### Migration Note
Replace with Supabase Edge Function that generates real AI narratives from activity/health data.

---

## R. `auditNameMapping` — Entity Navigation Routing Map

**File:** `main-dashboard-v34.js`, Lines 227349+

Maps entity names to their tab and type for Cosmo AI panel navigation.

```javascript
const auditNameMapping = {
    "Dwight Schrute": { mappedName: "Dwight Schrute", tab: "employees", type: "employee" },
    "Sarah Lansky": { mappedName: "Sarah Lansky", tab: "employees", type: "employee" },
    "Vanguard Health": { mappedName: "Vanguard Health", tab: "customers", type: "customer" },
    "Nova Financial": { mappedName: "Nova Financial", tab: "customers", type: "customer" },
    "Chevron Logistics": { mappedName: "Chevron Logistics", tab: "customers", type: "customer" },
    "Apex Global Retail": { mappedName: "Apex Global Retail", tab: "customers", type: "customer" },
    // ...additional entries
};
```

### Migration Note
Derive from `contacts.type` and `profiles.role` columns — no separate mapping table needed.

---

## S. `mockTargets` + `mockActions` — Activity Log Generator

**File:** `main-dashboard-v34.js`, Lines 198788–198825

Two objects used to generate fake activity log rows in the overview panel.

### `mockTargets`
| Sector | Names |
|:-------|:------|
| prospects | OmniCorp Tech, Chevron Solutions, Apex Global Retail, Nova Financial, Summit Capital, TechFlow Inc |
| customers | Acme Industrial Corp, Globex International, Initech Software, Wayne Enterprises, Stark Industries, Tyrell Corporation |
| employees | Michael Scott, Dwight Schrute, Pam Beesly, Jim Halpert, Angela Martin, Ryan Howard |

### `mockActions`
| Sector | Example Actions |
|:-------|:---------------|
| prospects | "Completed Initial Outreach Call", "Conducted live product demo and sandbox walk-through", "Sent customized proposal and pricing catalog" |
| customers | "Completed Quarterly Business Review & Strategic Alignment sync", "Appreciation call for account anniversary milestone" |
| employees | "Conducted weekly 1-on-1 alignment & coaching sync", "Completed Quarterly Performance Review & Goal Setting assessment" |

### Migration Note
Replace with real `activities` table query ordered by `created_at DESC LIMIT n`.

---

## T. `liveActivityFeed` — Real-Time Activity Feed Entries

**File:** `main-dashboard-v34.js`, Lines 159057–159201

8 hardcoded activity feed entries displayed in the Owner/Executive overview "Live Activity" ticker.

| # | Icon | Text | Time |
|:--|:-----|:-----|:-----|
| 1 | 📞 | **Sarah Lansky** logged a call with Stripe Canada | 3m ago |
| 2 | 🎁 | Gift dispatched to **Chevron Logistics** | 12m ago |
| 3 | ✅ | **Apex Global Retail** converted to Customer | 1h ago |
| 4 | ⚠️ | **Vanguard Health** entered Red Alert zone | 2h ago |
| 5 | 📧 | **Marcus Dupond** emailed Vanguard Logistics | 4h ago |
| 6 | 🎁 | AI Gift recommendation approved for **Apex Global Retail** | 5h ago |
| 7 | 📞 | **Tom Collins** logged a video sync with Nova Healthcare | 1d ago |
| 8 | ➕ | New prospect **Starlight Ventures** added | 2d ago |

> [!NOTE]
> Entry #8 introduces a **previously unseen entity name**: `Starlight Ventures`. This company does NOT appear anywhere else in the codebase. It exists solely as a feed decoration.

### Migration Note
Replace with real-time `activities` query ordered by `created_at DESC LIMIT 8`.

---

## Updated Complete Master File Index

| # | Data Source | File | Line | Section |
|:--|:------------|:-----|:-----|:--------|
| 1 | `employeeSectorTimeframeData` | `main-dashboard-v34.js` | 57072–58896 | **16K** |
| 2 | `calendarEventsDB` (send/receive schedules) | `main-dashboard-v34.js` | 116195–118970 | **16L** |
| 3 | `activeB2BOrders` | `main-dashboard-v34.js` | 77075+ | **16M** |
| 4 | `categorySpends` (4R budget) | `main-dashboard-v34.js` | 76594–76674 | **16N** |
| 5 | `mockSectors` fallback | `main-dashboard-v34.js` | 59024+ | **16O** |
| 6 | `bonusRep4–bonusRep10` (7 phantom employees) | `main-dashboard-v34.js` | 196371–196467 | **16P** |
| 7 | `activeAuditsDB` (Cosmo AI narratives) | `main-dashboard-v34.js` | 227125–227301 | **16Q** |
| 8 | `auditNameMapping` (navigation routing) | `main-dashboard-v34.js` | 227349+ | **16R** |
| 9 | `mockTargets` + `mockActions` (activity log gen) | `main-dashboard-v34.js` | 198786–198825 | **16S** |
| 10 | `liveActivityFeed` (8 feed entries) | `main-dashboard-v34.js` | 159057–159201 | **16T** |
