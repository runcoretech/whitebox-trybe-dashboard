# 15 — Addendum: Items Identified During Recheck

> [!IMPORTANT]
> This addendum documents **10 additional mock data sources** that were identified during two thorough rechecks of the entire codebase. These are IN ADDITION to the 14 sections already documented.

---

## A. `analyticsDataSets` — Full Dashboard Analytics Data Per Timeframe

**File:** [main-dashboard-v34.js](file:///c:/Users/paulk/OneDrive/Desktop/WHITEBOX%20GIFTWORKS%20PROJECT/dashboard/main-dashboard-v34.js), Lines 156609–159025  
**Variable:** `analyticsDataSets`

This is a massive hardcoded object (~2,400 lines) containing all dashboard analytics metrics across **7 timeframes**: `live`, `yesterday`, `7d`, `30d`, `90d`, `ytd`, `all`.

### Fields Per Timeframe

| Field | Type | Example (live) | Purpose |
|:------|:-----|:---------------|:--------|
| `clients` | number | `8` | Active customer count |
| `health` | number | `91` | Avg relationship health index |
| `conversion` | number | `34` | Conversion rate % |
| `daysToConvert` | number | `42` | Avg days from prospect to customer |
| `totalProspects` | number | `24` | Total prospects across org |
| `prospects` | number | `12` | Active prospects in pipeline |
| `employees` | number | `3` | Active employees count |
| `touchpoints` | number | `147` | Total touchpoints logged |
| `gifts` | number | `38` | Total gifts dispatched |
| `healthTrend` | array | `[89, 90, 90, 91, 91, 91]` | Health trend line data points |
| `healthLabels` | array | `['8am', '10am', '12pm', ...]` | X-axis labels for health chart |
| `giftingTrend` | array | `[1, 3, 2, 5, 2, 4]` | Gifting trend line data points |
| `giftingLabels` | array | `['8am', '10am', '12pm', ...]` | X-axis labels for gifting chart |
| `funnel` | array | `[12, 9, 6, 4]` | Conversion funnel stages (Prospects → Meetings → Proposals → Customers) |

This object also includes an `employeesLeaderboardDataSets` section nested at the end (Lines 158449–159009), containing per-employee leaderboard entries for each of the 7 timeframes.

### Migration Note
This entire object is replaced by computed SQL views aggregating from `activities`, `gifts`, and `contacts` tables grouped by date range.

---

## B. `recoveryBoardClients` — Default Recovery Board Accounts

**File:** `main-dashboard-v34.js`, Line 143242

```javascript
window.recoveryBoardClients = ["Vanguard Health", "Nova Financial"];
```

This is the default list of accounts pre-loaded onto the Recovery Board tab. These are accounts that have exceeded the critical inactivity threshold and need immediate ownership reassignment.

### Related Functions
- **`window.sendRelationshipToRecoveryBoard(client)`** (Line 143274): Adds a client to the recovery board
- **Recovery queue KPI calculation** (Lines 121045, 121133, 121214): Counts accounts where `inactiveDays >= decayCritical` OR in `recoveryBoardClients`
- **Recovery Board badge count** (Line 144442): `badge.textContent = window.recoveryBoardClients.length`

### Migration Note
Replace with a `contacts.status = 'recovery'` flag or a dedicated `recovery_board` junction table.

---

## C. Default Provisioned Seats

**File:** `main-dashboard-v34.js`, Lines 235694–235722

```javascript
let activeSeatsList = [
    { name: "Gregory Sterling", email: "g.sterling@whitebox.com", role: "Executive" },
    { name: "Sarah Lansky", email: "s.lansky@whitebox.com", role: "Executive" },
    { name: "Marcus Dupond", email: "m.dupond@whitebox.com", role: "Manager" },
    { name: "Jane Smith", email: "j.smith@whitebox.com", role: "Manager" },
    { name: "Dwight Schrute", email: "d.schrute@whitebox.com", role: "Rep" },
    { name: "Emily Davis", email: "e.davis@whitebox.com", role: "Executive" }
];
```

This is the default list of provisioned seats displayed in Settings → User Management. It's overridden by `localStorage('rmos_provisioned_seats')` if saved.

**Seat limit:** Maximum 10 seats (Line 236022: `if (activeSeatsList.length >= 10)`)

### Migration Note
Replace with `profiles` table query + `workspace.seat_limit` column.

---

## D. Hardcoded Role-Specific TODO Checklist Items

**File:** `main-dashboard-v34.js`, Lines 121355–121410 (embedded in the dashboard overview panel HTML)

### Owner TODO Items
1. Nudge Tom Collins regarding high-value *Chevron Logistics* (Red Alert - 64 Days)
2. Conduct 1-on-1 performance review with Rep *Tom Collins* (62 days ago)
3. Schedule HR satisfaction sync with Chief People Officer *Sarah Lansky*

### Rep TODO Items
1. Respond to Orion Biotech recovery recommendations (64 days inactive)
2. Log a touchpoint for Pinnacle Brands (68 days inactive)
3. Submit weekly sales projection checklist to Jane Smith

### Manager TODO Items
1. Review team pipeline metrics and recovery board allocations
2. Sync with Tom Collins regarding B2B healthcare account activity
3. Authorize priority sweet box delivery to active partners

### Executive (HR) TODO Items
1. Approve team health scaling factors for sales team
2. Review employee stress levels and alignment across branches
3. Configure onboarding credentials for new sales hires

### Migration Note
Replace with database-driven task queue generated from real activity analysis.

---

## E. `getClientHistory()` Fallback Timeline Generator

**File:** `main-dashboard-v34.js`, Lines 56144–56280

When a client's name isn't found in `clientGraphData`, this function generates a **default fallback timeline** with 5 generic touchpoints:

```javascript
if (!clientGraphData[name]) {
    clientGraphData[name] = [
        { type: "Email", date: "Jan 15", grade: "A", count: 3,
          notes: "Introductory outreach campaign. Enthusiastic response.", rep: "System Automation" },
        { type: "Call", date: "Feb 20", grade: "C", count: 2,
          notes: "Routine check-in. The client was busy but receptive.", rep: "Owner" },
        { type: "System", date: "Mar 10", grade: "C", count: 1,
          notes: "Auto-newsletter catalog sent regarding seasonal boxes.", rep: "System Automation" },
        { type: "Gift", date: "Apr 05", grade: "A", count: 3,
          notes: "Sent Sweets & Packs appreciation box. Positive feedback.", rep: "Milestone Automation" },
        { type: "Touchpoint", date: "May 12", grade: "A", count: 4,
          notes: "Detailed review of account. Highly satisfied.", rep: "Owner" }
    ];
}
```

This ensures that every client, even those without explicit timeline data, still shows a populated timeline in the detail panel.

### Migration Note
Eliminate entirely — real `activities` table query will return empty set for new contacts with no history.

---

## F. Software Page Demo Data (`software.html`)

**File:** [software.html](file:///c:/Users/paulk/OneDrive/Desktop/WHITEBOX%20GIFTWORKS%20PROJECT/public-website/software.html)

The public-facing Software page contains **marketing-purpose hardcoded demo data** in its visual sections:

### Constellation Diagram Node Stats (Lines 469–515)
| Node | Stat | Status |
|:-----|:-----|:-------|
| Customers | `62% Health` | `status-red` |
| Prospects | `2 Neglected` | `status-red` |
| Executives | `72% Alignment` | `status-red` |
| Managers | `Overloaded` | `status-red` |
| Employees | `65% Satisfaction` | `status-red` |
| HR Portal | `3 Pending Reviews` | `status-red` |

### Pipeline Analytics HUD (Lines 583–595)
| Metric | Value |
|:-------|:------|
| Conversion Rate | `12%` |
| Active Deals | `8` |
| Acquisition Value | `$15,000` |

### Control Center Module Cards (Lines 310–406)
| Module | Stat |
|:-------|:-----|
| At-Risk Radar | `5 Warnings`, `5 Accounts Cold (Veer Inc, Initech)` |
| Rep Performance | `Sarah L. leads at 98 Perf Index` |
| Impact Timing | `Touchpoint timings aligned for 94% retention` |
| Conversion Accelerator | `Direct Gifting accelerated 12 deals this week` |

### Magnet Section (Line 532)
- `14 Accounts Dormant — Relationships decaying in static CRM lists`

### Pipeline Log (Line 601)
- `Apex Solutions logged as active Prospect.`

> [!NOTE]
> These are **marketing showcase values** on the public website — NOT dashboard mock data. They are static HTML and would typically remain hardcoded for marketing purposes even after Supabase migration. Document them for completeness only.

---

## G. Duplicate Data Layer in `main-theme-v34.js` (Public Website JS)

**File:** [main-theme-v34.js](file:///c:/Users/paulk/OneDrive/Desktop/WHITEBOX%20GIFTWORKS%20PROJECT/public-website/main-theme-v34.js)

> [!WARNING]
> The public-website JavaScript contains its **own copies** of the same mock data structures found in the dashboard. This creates a **dual maintenance burden**.

### Duplicate Data Sources Found

| Variable | Dashboard (`main-dashboard-v34.js`) | Public Website (`main-theme-v34.js`) |
|:---------|:------------------------------------|:-------------------------------------|
| `clientGraphData` | Line 55872+ | Line 4292 (with fallback generator at Line 4326) |
| `employeesData` | Line 118979+ | Referenced at Line 3189 (imported from shared scope) |
| `customersData` | Line 144570+ | Referenced at Line 3191 |
| `prospectsData` | Line 144570+ | Referenced at Line 3193 |
| `giftingDispatchSchedule` | Line 76722 | Line 6760 |
| `getClientHistory()` | Line 56144 | Line 4326 (fallback generator) |
| Hardcoded employee names | In employeesData | Line 3351 (explicit name list for `isIndividual` check) |

### `isIndividual` Name Check (Line 3351)
```javascript
const isIndividual = ['Tom Collins', 'Sarah Lansky', 'Emily Davis', 'Marcus Dupond',
    'Jane Smith', 'Gregory Sterling'].includes(targetName) ||
    (typeof employeesData !== 'undefined' && employeesData.some(emp => emp.name === targetName));
```

This hardcoded name list is used as a fallback to determine if a target is an individual vs. an organization.

### Migration Note
During Supabase migration, all data will come from a single source (Supabase). The dual JS files must both be updated to fetch from Supabase instead of maintaining separate hardcoded arrays.

---

## H. `dashboard/index.html` — Massive Inline Hardcoded HTML Data (682 KB)

**File:** [dashboard/index.html](file:///c:/Users/paulk/OneDrive/Desktop/WHITEBOX%20GIFTWORKS%20PROJECT/dashboard/index.html) (682,421 bytes / 21,052 lines)

> [!CAUTION]
> The dashboard HTML file is the **largest single file** in the project and contains enormous amounts of hardcoded mock data embedded directly in the HTML markup. This was NOT caught in the original audit because searches focused on JavaScript variable declarations rather than inline HTML `data-*` attributes and static markup.

### H.1 — Recovery Board HTML Cards (Lines 9340–9436)

Two hardcoded recovery board opportunity cards:

| Client | Inactivity | Data Attributes |
|:-------|:-----------|:----------------|
| Vanguard Health | 84 days | `data-client="Vanguard Health"` |
| Nova Financial | 92 days | `data-client="Nova Financial"` |

### H.2 — Rep View Client Table (Lines 6288–7120)

7 complete inline client/prospect records with full contact details embedded as `data-*` attributes:

| Row | Name | Type | Rep | Health | Contact | Address | Email | Phone |
|:----|:-----|:-----|:----|:-------|:--------|:--------|:------|:------|
| 1 | Pinnacle Brands | Customer | Tom Collins | 62% | Lisa Kudrow | 99 Brand St, Los Angeles, CA 90015 | sales@pinnacle.com | (213) 555-0177 |
| 2 | Summit Media | Prospect | Tom Collins | 48% | Samuel Jackson | 44 Media Way, Austin, TX 78701 | hello@summitmedia.com | (512) 555-0178 |
| 3 | Orion Biotech | Prospect | Tom Collins | 54% | Dr. Robert Vance | 23 Innovation Ave, Boston, MA 02111 | rnd@orion.com | (617) 555-0167 |
| 4 | Vanguard Logistics | Customer | Tom Collins | 58% | Tom Higgins | 78 Logistics Way, Chicago, IL 60606 | ops@vanguard.com | (312) 555-0188 |
| 5 | Nova Financial | Customer | Jack R. | 74% | Dr. Aris | 200 Health Ave, Seattle, WA 98104 | admin@nova.com | (206) 555-0144 |
| 6 | Beacon Logistics | Prospect | Jack R. | 76% | Ben Franklin | 300 Cargo Lane, Atlanta, GA 30320 | freight@beacon.com | (404) 555-0189 |
| 7 | Summit Financial | Customer | Anna L. | 81% | Marcus Miller | 500 Finance Blvd, Boston, MA 02109 | vip@summit.com | (617) 555-0133 |

Each row contains: `data-type`, `data-address`, `data-contact`, `data-city`, `data-province`, `data-postal`, `data-prospect` (date), `data-customer` (date), `data-phone`, `data-email`, `data-rep`, `data-health`, `data-calls`, `data-gifts`, `data-ai`.

### H.3 — HTML Leaderboard Rows (Lines 3897–4181)

3 hardcoded leaderboard rows in the HTML (these are the initial/default render before JS takes over):

| Rank | Name | Score | Prospects | Customers | Gifts |
|:-----|:-----|:------|:----------|:----------|:------|
| 1 | Sarah Lansky | 98% | 14 ▲ | 18 ▲ | 12 |
| 2 | Marcus Dupond | 92% | 10 ▲ | 12 ▼ | 8 |
| 3 | Tom Collins | 64% | 8 ▼ | 4 ▼ | 2 |

### H.4 — Employees Tab KPI Card Defaults (Lines 4237–4317)

| KPI | Default Value | Trend |
|:----|:-------------|:------|
| Gifts Sent | `96` | +12% ▲ vs last month |
| Gifts Received | `41` | +8% ▲ vs last month |

### H.5 — COSMO AI Insight Cards (Lines 3509–3561)

3 hardcoded AI insight narratives in the owner overview:

1. `🔴 Vanguard Health exceeded threshold inactivity levels (34 days neglected).`
2. `🔴 Chevron Logistics has remained a prospect for 42 days with zero logged manual touches.`
3. `🟡 Dwight Schrute logged 14 touches this week but has yielded a 0% conversion rate.`

### H.6 — COSMO Task Expansion Cards (Lines 6045–6120)

4 expanded TODO task detail panels (owner-specific) with full narrative text, action buttons, and data attributes:

1. **Nudge Tom Collins / Chevron Logistics** — 64 days of silence, Collins managing 4 neglected accounts
2. **Tom Collins Performance Review** — 64% overall score, 8 prospects, 4 customers
3. **HR Satisfaction Sync / Sarah Lansky** — Quarterly CPO performance sync
4. **Recovery Board Critical** — Vanguard Health (84 Days), Nova Financial (92 Days) exceeded critical threshold

### H.7 — Select Dropdown Options (Lines 280–288, 980–982, 1737–1749, 2343–2355)

Hardcoded `<option>` elements for rep/client/manager selectors:

**Recovery send gift dropdown:**
- `Chevron Logistics (Red Alert)`
- `Apex Global Retail (Orange Alert)`
- `Vanguard Health (Extended Inactivity)`

**Rep assignment dropdowns (2 duplicate instances):**
- `Gregory Sterling (CEO)`
- `Sarah Lansky (Enterprise AE)`
- `Marcus Dupond (Core Sales AE)`
- `Tom Collins (Core Sales AE)`

**Manager selector:**
- `Jane Smith (Scranton Sales)`
- `Marcus Dupond (Enterprise Sales)`

### H.8 — Gifting Approval Queue (Lines 9528+)

Gift cards for owner approval with hardcoded client names, gift types, and spend amounts in `data-*` attributes (e.g., `data-client="Chevron Logistics"`, `data-gift="Tech Essentials Box"`, `data-spend="180"`).

### H.9 — Default Detail Panel Values (Lines 7200–7328)

Initial values rendered in the relationship detail side-panel:
- Default name: `Chevron Logistics`
- Default email: `logistics@chevron.com`
- Default rep: `Rep: Tom Collins`
- Team branch tag: `Scranton Branch`

### Migration Note
The `dashboard/index.html` contains the **initial render state** of the dashboard. When Supabase is integrated, these hardcoded HTML elements become templates that are populated by Supabase query results on page load. All `data-*` attributes, `<option>` values, default text content, and inline table rows must be stripped and replaced with JavaScript-driven DOM rendering from live data.

---

## I. `software.js` — Magnet Section Mock Company Names

**File:** [software.js](file:///c:/Users/paulk/OneDrive/Desktop/WHITEBOX%20GIFTWORKS%20PROJECT/public-website/software.js), Lines 328–332

```javascript
const names = [
    'Acme Corp', 'Globex Inc', 'Initech', 'Umbrella Corp', 'Hooli',
    'Veer Inc', 'Innova Co', 'Contoso', 'Soylent Co', 'Tepco',
    'Stark Ind', 'Wayne Ent', 'Tyrell Corp', 'Cyberdyne', 'Oscar Co',
    'Delos LLC', 'InGen', 'Massive Dyn', 'Aperture Lab', 'Safaricom'
];
```

These 20 company names populate the 32 magnet-effect contact cards in the "Magnetic Recovery" section.

**Also contains:**
- `nodeStats` object (Line 43) with start/target values for constellation animation counters
- Pipeline milestones (Lines 489–496): `Apex Solutions` referenced in 3 places
- Journey HUD counters: Conversion (12→48%), Deals (8→42), Revenue ($15K→$240K), `Closed Won: $240,000`

### Migration Note
Marketing page — these remain hardcoded as they're demo/showcase values, not connected to live data.

---

## J. `spend-ledger-modal.js` — Additional Filler Arrays

**File:** [spend-ledger-modal.js](file:///c:/Users/paulk/OneDrive/Desktop/WHITEBOX%20GIFTWORKS%20PROJECT/dashboard/spend-ledger-modal.js)

Beyond the already-documented filler generation logic, additional hardcoded arrays were found:

### J.1 — Rep-Scoped Customer Names (Line 210)
```javascript
var repCustomers = ['Vanguard Health', 'Pinnacle Brands', 'Orion Biotech',
    'Chevron Logistics', 'Summit Media', 'BlueStar Retail', 'Peak Financial'];
```

### J.2 — Manager-Scoped Customer Names (Line 227)
```javascript
['Apex Global Retail', 'Nova Financial', 'Stripe Canada', 'Chevron Logistics',
 'Zenith Corp', 'Scranton Business Park', 'Dunder Mifflin']
```

### J.3 — Detail Panel Filler Clients (Line 361)
```javascript
var fakeClients = ['Zenith Corp', 'Chevron Group', 'Marcus & Co',
    'Support Tech', 'Acme Inc', 'Global Logistics'];
```

### J.4 — Detail Panel Filler Dates and Confections (Lines 360–362)
```javascript
var fakeDates = ['May 24, 2026', 'May 20, 2026', 'May 15, 2026', ...];
var fakeConfections = ['Sweets Box', 'Packs appreciation box',
    'Deluxe Confections Box', 'Cosmo Signature Pack'];
```

### J.5 — Role-Based Row Counts (Lines 172–173)
```javascript
var remainingEmployees = role === 'manager' ? 8 : 32;
var remainingCustomers = role === 'manager' ? 28 : 106;
```

### Migration Note
All filler row generation is eliminated when spend ledger reads from the real `gifts` table.

---

## Updated Master File Index

Adding ALL newly discovered data to the original index:

| Data Source | File | Line | Status |
|:------------|:-----|:-----|:-------|
| `analyticsDataSets` (7 timeframes) | `main-dashboard-v34.js` | 156609 | **Section 15A** |
| `recoveryBoardClients` default | `main-dashboard-v34.js` | 143242 | **Section 15B** |
| Default provisioned seats | `main-dashboard-v34.js` | 235694 | **Section 15C** |
| Role-specific TODO checklists | `main-dashboard-v34.js` | 121355 | **Section 15D** |
| `getClientHistory()` fallback | `main-dashboard-v34.js` | 56144 | **Section 15E** |
| Software page demo metrics | `software.html` | 310–601 | **Section 15F** |
| Duplicate data layer | `main-theme-v34.js` | 3189–6760 | **Section 15G** |
| **Dashboard HTML inline data (682KB)** | **`dashboard/index.html`** | **280–9584** | **Section 15H** |
| Software.js magnet company names | `software.js` | 328–495 | **Section 15I** |
| Spend ledger additional filler arrays | `spend-ledger-modal.js` | 159–362 | **Section 15J** |

