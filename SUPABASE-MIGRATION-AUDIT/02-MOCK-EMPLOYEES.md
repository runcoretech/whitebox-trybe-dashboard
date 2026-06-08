# 02 — Mock Employee Records

## Data Location

**File:** [main-dashboard-v34.js](file:///c:/Users/paulk/OneDrive/Desktop/WHITEBOX%20GIFTWORKS%20PROJECT/dashboard/main-dashboard-v34.js)  
**Variable:** `employeesData` (starts at ~line 118979)

## Employee Inventory

| Name | Category | Manager | Role Title (Implied) |
|:-----|:---------|:--------|:---------------------|
| Gregory Sterling | `executives` | Board / Shareholders | CEO |
| Sarah Lansky | `executives` | Gregory Sterling | Chief People Officer |
| Emily Davis | `executives` | Sarah Lansky | VP / Director |
| Marcus Dupond | `managers` | Paul K. | Managing Director |
| Tom Collins | `reps` | Marcus Dupond | Enterprise Sales Rep |
| Dwight Schrute | `reps` | Marcus Dupond | Sales Rep |
| Jane Smith | `reps` | Marcus Dupond | Sales Rep |
| John Doe | `reps` | Marcus Dupond | Sales Rep |
| Alice Cooper | `reps` | Emily Davis | Sales Rep |
| Bob Martin | `reps` | Emily Davis | Sales Rep |
| Charlie Brown | `reps` | Emily Davis | Sales Rep |

## Hierarchy Tree

```
Board / Shareholders
└── Gregory Sterling (CEO / executives)
    ├── Sarah Lansky (CPO / executives)
    │   └── Emily Davis (VP / executives)
    │       ├── Alice Cooper (rep)
    │       ├── Bob Martin (rep)
    │       └── Charlie Brown (rep)
    └── Paul K. (Account Owner — implicit, not in employeesData)
        └── Marcus Dupond (Managing Director / managers)
            ├── Tom Collins (rep)
            ├── Dwight Schrute (rep)
            ├── Jane Smith (rep)
            └── John Doe (rep)
```

## Data Structure Per Employee

Each employee record contains these fields:

| Field | Type | Example | Description |
|:------|:-----|:--------|:------------|
| `name` | string | `"Tom Collins"` | Display name |
| `category` | string | `"reps"` | Role tier: `executives`, `managers`, `reps` |
| `manager` | string | `"Marcus Dupond"` | Direct manager name (used for hierarchy filtering) |
| `inactiveDays` | number | `14` | Days since last logged touchpoint (drives inactivity status) |
| `grade` | string | `"C"` | Performance grade: A, B, C, D, F |
| `touchpoints` | number | `31` | Total touchpoints logged |
| `clients` | number | `4` | Active client assignments |
| `prospects` | number | `3` | Active prospect assignments |
| `health` | number | `85` | Composite relationship health score (0–100) |

## How Employee Data Drives the Dashboard

1. **Employee Leaderboard Cards** — Populated from `employeesData` ranked by composite score
2. **Inactivity Status Indicators** — `getInactivityStatus(emp.inactiveDays)` returns `green` / `orange` / `red`
3. **Management Hierarchy Filtering** — Managers see only employees where `emp.manager === currentUsername`
4. **Employee Detail Panel** — Clicking an employee card loads their touchpoint timeline, grade, and health ring
5. **COSMO AI Audit Cards** — Employee-specific audit recommendations reference these records
6. **Gifting Queue** — Employee reward gifts (birthday, milestone) reference employee names

## Additional Mock Employee Names in `spend-ledger-modal.js`

**File:** [spend-ledger-modal.js](file:///c:/Users/paulk/OneDrive/Desktop/WHITEBOX%20GIFTWORKS%20PROJECT/dashboard/spend-ledger-modal.js), Line 166–170

The spend ledger modal uses an **expanded** mock employee list for filler row generation:

```javascript
var mockEmployees = [
    'Sarah Lansky', 'Tom Collins', 'Marcus Dupond', 'Emily Davis', 'Jane Smith',
    'John Doe', 'Alice Cooper', 'Bob Martin', 'Charlie Brown', 'Diana Prince',
    'Peter Parker', 'Bruce Wayne', 'Clark Kent', 'Tony Stark', 'Steve Rogers'
];
```

> [!NOTE]
> Names like `Diana Prince`, `Peter Parker`, `Bruce Wayne`, `Clark Kent`, `Tony Stark`, `Steve Rogers` are fictional filler names used only in the spend ledger modal — they do NOT appear in `employeesData` or elsewhere in the dashboard.

---

## Supabase Migration Notes

| Current | Target |
|:--------|:-------|
| `employeesData` JS array | `profiles` table with `role`, `manager_id` foreign key |
| `emp.manager === "Marcus Dupond"` string matching | `profiles.manager_id = auth.uid()` foreign key join |
| Hardcoded `inactiveDays`, `grade`, `health` | Computed from `activities` table aggregations |
| `category` field (`executives`, `managers`, `reps`) | `profiles.role` column (`owner`, `hr`, `manager`, `rep`) |
