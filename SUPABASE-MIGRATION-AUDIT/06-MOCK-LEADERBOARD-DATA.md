# 06 — Mock Leaderboard Data

## A. Overview Leaderboard (`leaderboardData`)

**File:** [main-dashboard-v34.js](file:///c:/Users/paulk/OneDrive/Desktop/WHITEBOX%20GIFTWORKS%20PROJECT/dashboard/main-dashboard-v34.js)  
**Variable:** `leaderboardData` (Line 112650)

This populates the wide performance leaderboard on the Overview tab. It has TWO sub-categories (`reps` and `managers`), each with THREE timeframes (`week`, `month`, `quarter`).

### Reps Leaderboard

**Headers:** Rank | Rep Name | Performance Score | Active Prospects | Active Customers | Gifts Dispatched

#### Weekly
| Rank | Name | Score | Prospects | Customers | Gifts |
|:-----|:-----|:------|:----------|:----------|:------|
| 1 | Sarah Lansky | 98% ↑ | 14 ▲ | 18 ▲ | 12 gifts sent |
| 2 | Marcus Dupond | 92% ↑ | 10 ▲ | 12 ▼ | 8 gifts sent |
| 3 | Tom Collins | 64% ↓ | 8 ▼ | 4 ▼ | 2 gifts sent |

#### Monthly
| Rank | Name | Score | Prospects | Customers | Gifts |
|:-----|:-----|:------|:----------|:----------|:------|
| 1 | Sarah Lansky | 97% ↑ | 54 ▲ | 72 ▲ | 48 gifts sent |
| 2 | Marcus Dupond | 94% ↑ | 42 ▲ | 46 ▲ | 36 gifts sent |
| 3 | Tom Collins | 68% ↓ | 28 ▼ | 18 ▼ | 14 gifts sent |

#### Quarterly
| Rank | Name | Score | Prospects | Customers | Gifts |
|:-----|:-----|:------|:----------|:----------|:------|
| 1 | Sarah Lansky | 99% ↑ | 168 ▲ | 210 ▲ | 144 gifts sent |
| 2 | Marcus Dupond | 95% ↑ | 135 ▲ | 148 ▲ | 112 gifts sent |
| 3 | Tom Collins | 71% ↓ | 92 ▼ | 64 ▼ | 45 gifts sent |

### Managers Leaderboard

**Headers:** Rank | Manager Name | Management Index | Pipeline Compliance | Recovery Success | Direct Nudges Sent

#### Weekly
| Rank | Name | Index | Compliance | Recovery | Nudges |
|:-----|:-----|:------|:-----------|:---------|:-------|
| 1 | Marcus Dupond | 94% ↑ | 96% ▲ | 8 ▲ | 12 nudges |
| 2 | Jane Smith | 89% ↑ | 88% ▲ | 5 ▲ | 8 nudges |
| 3 | Sarah Lansky | 85% ↑ | 82% ▼ | 4 ▼ | 6 nudges |

#### Monthly
| Rank | Name | Index | Compliance | Recovery | Nudges |
|:-----|:-----|:------|:-----------|:---------|:-------|
| 1 | Marcus Dupond | 95% ↑ | 97% ▲ | 32 ▲ | 45 nudges |
| 2 | Jane Smith | 91% ↑ | 92% ▲ | 20 ▲ | 34 nudges |
| 3 | Sarah Lansky | 87% ↑ | 85% ▼ | 15 ▼ | 22 nudges |

#### Quarterly
*(Same pattern as above with scaled-up numbers)*

---

## B. Employees Tab Leaderboard (`employeesLeaderboardDataSets`)

**Variable:** `employeesLeaderboardDataSets` (Line 158449)

This populates the Employees tab leaderboard. It has FIVE timeframes: `live`, `yesterday`, `week`, `month`, `quarter`.

### Structure Per Entry

| Field | Type | Example |
|:------|:-----|:--------|
| `rank` | string | `'🥇'` / `'🥈'` / `'🥉'` |
| `name` | string | `'Sarah Lansky'` |
| `initials` | string | `'SL'` |
| `composite` | number | `98` (composite performance score) |
| `touchpoints` | number | `68` |
| `prospects` | number | `6` |
| `clients` | number | `4` |
| `health` | number | `96` |
| `color` | string | `'#8b5cf6'` (avatar color) |

### Live Dataset Example

| Rank | Name | Composite | Touchpoints | Prospects | Clients | Health |
|:-----|:-----|:----------|:------------|:----------|:--------|:-------|
| 🥇 | Sarah Lansky | 98 | 68 | 6 | 4 | 96 |
| 🥈 | Marcus Dupond | 91 | 48 | 5 | 3 | 92 |
| 🥉 | Tom Collins | 84 | 31 | 3 | 1 | 85 |

All five timeframes (`live`, `yesterday`, `week`, `month`, `quarter`) follow this same structure with different numbers.

## C. Leaderboard Tab Visibility by Role

**Functions:** `updateLeaderboardTabsForRole()` (Line 101129) and `updateOverviewLeaderboardTabs()` (Line 101276)

| Role | Overview Leaderboard Tabs | Employees Leaderboard Tabs |
|:-----|:--------------------------|:---------------------------|
| `rep` | Hidden (no leaderboard access) | Hidden |
| `manager` | My Team only | My Team, Individuals |
| `hr` | All Teams, My Team, Individuals | All Teams, My Team, Individuals |
| `owner` | All Teams, My Team, Individuals | All Teams, My Team, Individuals |

---

## Supabase Migration Notes

| Current | Target |
|:--------|:-------|
| `leaderboardData` static object with week/month/quarter | SQL view computing rankings from `activities` + `gifts` tables, grouped by date range |
| `employeesLeaderboardDataSets` static object with 5 timeframes | Same SQL view with live/yesterday/week/month/quarter date filters |
| Hardcoded rank emojis | Computed by `ROW_NUMBER() OVER (ORDER BY composite_score DESC)` |
| Tab visibility rules | Client-side role check from Supabase session, same logic preserved |
