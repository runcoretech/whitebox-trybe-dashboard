# 03 — Mock Customers & Prospects

## Data Location

**File:** [main-dashboard-v34.js](file:///c:/Users/paulk/OneDrive/Desktop/WHITEBOX%20GIFTWORKS%20PROJECT/dashboard/main-dashboard-v34.js)  
**Variables:** `customersData` and `prospectsData` (starts at ~line 144570)

## Customer Records

| Organization Name | Assigned Rep | Grade | Inactive Days | Health | Sector |
|:------------------|:-------------|:------|:--------------|:-------|:-------|
| Apex Global Retail | Sarah Lansky | A | Low | High | Enterprise B2B |
| Chevron Solutions | Marcus Dupond | A | Low | High | Enterprise B2B |
| Initech Software | Tom Collins | C | Moderate | Medium | Enterprise B2B |
| Wayne Enterprises | Dwight Schrute | A | Low | High | Enterprise B2B |
| Stark Industries | Jane Smith | A | Low | High | Enterprise B2B |
| Tyrell Corporation | Bob Martin | C | High | Low | Enterprise B2B |

## Prospect Records

| Organization Name | Assigned Rep | Grade | Inactive Days | Health | Sector |
|:------------------|:-------------|:------|:--------------|:-------|:-------|
| Apex Systems | Sarah Lansky | C | Moderate | Medium | Prospect |
| Zenith Corp | Tom Collins | C | Moderate | Medium | Prospect |
| Vanguard Health | Dwight Schrute | F | High (34+ days) | Low | Prospect |
| OmniCorp | Jane Smith | C | Moderate | Medium | Prospect |
| Chevron Logistics | Marcus Dupond | F | High (42+ days) | Low | Prospect |
| TechFlow Inc | Bob Martin | C | Moderate | Medium | Prospect |

## Data Structure Per Customer/Prospect

Each record contains:

| Field | Type | Example | Purpose |
|:------|:-----|:--------|:--------|
| `name` | string | `"Apex Global Retail"` | Display name |
| `rep` | string | `"Sarah Lansky"` | Assigned representative (used for role-based filtering) |
| `grade` | string | `"A"` | Relationship grade: A, B, C, D, F |
| `inactiveDays` | number | `5` | Days since last touchpoint |
| `health` | number | `96` | Relationship health score (0–100%) |
| `sector` | string | `"Enterprise B2B"` | Industry classification |
| `status` | string | `"active"` | Account status |
| `aiRecommend` | string | `"Send Sweet Box..."` | COSMO AI recommendation text |

## Additional Mock Customer Names in `spend-ledger-modal.js`

**File:** [spend-ledger-modal.js](file:///c:/Users/paulk/OneDrive/Desktop/WHITEBOX%20GIFTWORKS%20PROJECT/dashboard/spend-ledger-modal.js), Lines 159–164

The spend ledger uses an **expanded** mock customer list for filler rows:

```javascript
var mockCustomers = [
    'Acme Industrial Corp', 'Globex International', 'Initech Software', 'Wayne Enterprises',
    'Stark Industries', 'Tyrell Corporation', 'OmniCorp Tech', 'Chevron Solutions',
    'Apex Global Retail', 'Nova Financial', 'Summit Capital', 'TechFlow Inc',
    'Soylent Corp', 'Hooli Inc', 'Veer Industries', 'Aero Dynamics', 'Sterling Cooper',
    'Oscorp Industries', 'Cyberdyne Systems', 'Dunder Mifflin', 'Gekko & Co', 'Monarch Shipping'
];
```

### Role-Specific Spend Ledger Customer Lists

The `spend-ledger-modal.js` also has role-specific customer arrays for filler generation:

**Rep view (Line 210):**
```javascript
var repCustomers = ['Vanguard Health', 'Pinnacle Brands', 'Orion Biotech',
    'Chevron Logistics', 'Summit Media', 'BlueStar Retail', 'Peak Financial'];
```

**Manager view (Line 221–231):**
- Employees: `'Dwight Schrute', 'Jane Smith', 'Marcus Dupond'`
- Customers: `'Apex Global Retail', 'Nova Financial', 'Stripe Canada', 'Chevron Logistics', 'Zenith Corp', 'Scranton Business Park', 'Dunder Mifflin'`
- Reps: `'Dwight Schrute', 'Marcus Dupond'`

**Owner/Exec view (Line 234–244):**
- Uses full `mockEmployees` and `mockCustomers` arrays
- Reps: `'Jim Halpert', 'Dwight Schrute', 'Pam Beesly', 'Ryan Howard'`

## Additional Company Names Referenced Across the Dashboard

These company names appear in COSMO audit cards, dispatch schedule, or timeline but are NOT in `customersData`/`prospectsData`:

| Company | Context | File Location |
|:--------|:--------|:-------------|
| Pinnacle Brands | COSMO audit card (health score 62%, 68 days inactive) | `main-dashboard-v34.js`, Line 159 |
| Orion Biotech | COSMO audit card (prospect, 64 days, health 54%) | `main-dashboard-v34.js`, Line 191 |
| Nova Financial | COSMO audit card + dispatch schedule + calendar | Multiple locations |
| Nova Healthcare | Executive calendar event + COSMO descriptions | Lines 201363, 227221 |
| Stripe Canada | Live activity feed + executive activity history | Lines 159073, 201635 |
| Delta Aerospace | Executive activity history | Line 201891 |
| Aero Dynamics | Executive calendar event | Line 201395 |
| BlueStar Retail | Dispatch schedule + spend ledger | Line 76786 |
| Silverline Tech | Dispatch schedule | Line 76882 |
| Helix Labs | Dispatch schedule | Line 76898 |
| Alpha Digital | Dispatch schedule | Line 76930 |
| Quantum Tech | Dispatch schedule | Line 76946 |
| Zenith Group | Dispatch schedule | Line 76866 |
| Peak Financial | Active B2B orders | Line 77731 |
| Starlight Ventures | Live activity feed | Line 159185 |
| Scranton Business Park | COSMO audit (Dwight) | Spend ledger |

---

## Role-Based Filtering Logic

**How customers/prospects are filtered by role:**

| Role | Filtering Rule | Code Reference |
|:-----|:---------------|:---------------|
| `rep` | `cust.rep === currentUsername` (e.g., shows only Tom Collins's clients) | `main-dashboard-v34.js` |
| `manager` | Finds employees where `emp.manager === currentUsername`, then filters customers by those employees' names | `main-dashboard-v34.js` |
| `hr` (Executive) | Full read access. Filterable by any rep profile | `main-dashboard-v34.js` |
| `owner` | Full read/write. Includes Settings access | `main-dashboard-v34.js` |

**View mode toggles (for owner/exec/manager):**

| Variable | Default | Options | Purpose |
|:---------|:--------|:--------|:--------|
| `window.ownerCustViewMode` | `'all'` | `'all'`, `'team'` | Owner: show all org or filter by team |
| `window.execCustViewMode` | `'all'` | `'all'`, `'team'` | Executive: show all org or filter by team |
| `window.managerCustViewMode` | `'mine'` | `'mine'`, `'team'` | Manager: show self-managed or full team |

---

## Supabase Migration Notes

| Current | Target |
|:--------|:-------|
| `customersData` / `prospectsData` JS arrays | `organizations` + `contacts` tables |
| `cust.rep === "Tom Collins"` string matching | `contacts.assigned_rep_id = auth.uid()` |
| Hardcoded `inactiveDays`, `grade`, `health` | Computed via SQL views / functions from `activities` |
| View mode toggles as JS globals | Query parameters or session-scoped filters |
