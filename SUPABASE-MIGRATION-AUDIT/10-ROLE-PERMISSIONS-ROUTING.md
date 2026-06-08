# 10 — Role-Based Permissions & Routing

## A. Role Hierarchy

| Role Key | Display Role | Scope | Settings Access |
|:---------|:-------------|:------|:----------------|
| `owner` | Account Owner | Full org-wide read/write | ✅ Yes |
| `hr` | Executive / CPO | Full org-wide read | ❌ No |
| `manager` | Managing Director | Self + direct reports | ❌ No |
| `rep` | Sales Representative | Self only | ❌ No |

## B. How Role Is Determined

### Login Flow
1. `login.html` validates credentials against `users.json`
2. On success, sets `localStorage.setItem('whitebox_role', user.role)`
3. Dashboard reads: `const savedRole = localStorage.getItem('whitebox_role') || 'owner'`

### Dashboard Role Selector (Debug/Demo Only)
- **Function:** `initDashboardRoleSelector()` in `main-dashboard-v34.js`
- Allows switching roles without re-logging (for demo purposes)
- Sets `window.currentRole` and `window.currentUsername`
- Triggers full dashboard re-render via role change handlers

> [!WARNING]
> The role selector dropdown is a demo-only feature. In production with Supabase, the role must come exclusively from the `profiles` table linked to `auth.uid()`.

## C. Visibility Rules Per Dashboard Section

### Overview Tab

| Element | Owner | Executive | Manager | Rep |
|:--------|:------|:----------|:--------|:----|
| All KPI cards | ✅ Org-wide | ✅ Org-wide | ✅ Team-scoped | ✅ Self-scoped |
| Leaderboard | ✅ All tabs | ✅ All tabs | ✅ My Team only | ❌ Hidden |
| COSMO Audit Cards | ✅ Owner-specific | ✅ Exec-specific | ✅ Mgr-specific | ✅ Rep-specific |
| Live Activity Feed | ✅ | ✅ | ✅ | ✅ Self-filtered |

### Customers Tab

| Role | Filtering | View Mode Toggle |
|:-----|:----------|:----------------|
| `owner` | All customers visible | Toggle: `all` / `team` via `ownerCustViewMode` |
| `hr` | All customers visible | Toggle: `all` / `team` via `execCustViewMode` |
| `manager` | Self-managed + team | Toggle: `mine` / `team` via `managerCustViewMode` |
| `rep` | `cust.rep === currentUsername` only | No toggle |

### Prospects Tab
Same filtering rules as Customers tab.

### Employees Tab

| Role | Visibility |
|:-----|:-----------|
| `owner` | All employees visible |
| `hr` | All employees visible |
| `manager` | Only employees where `emp.manager === currentUsername` |
| `rep` | ❌ Tab hidden entirely |

### Gifting Tab

| Role | Visibility |
|:-----|:-----------|
| `owner` | All orders + approval workflow (Approve/Reject buttons) |
| `hr` | All orders (read-only) |
| `manager` | Team orders only |
| `rep` | Self orders only, filtered via `recordBelongsToRep()` |

### Settings Tab

| Role | Access |
|:-----|:-------|
| `owner` | ✅ Full access to all settings panels |
| `hr`, `manager`, `rep` | ❌ Tab hidden or redirected |

Settings panels include:
- General Operating Parameters
- Financial Policies & Budget
- Operational Alert Webhooks
- Integration Connections
- Workspace Branding & Theme
- Seat Provisioning & User Management

## D. Sidebar Navigation Visibility

**File:** `main-dashboard-v34.js` and `dashboard/index.html`

Sidebar nav items are shown/hidden based on role:

| Nav Item | Owner | Executive | Manager | Rep |
|:---------|:------|:----------|:--------|:----|
| Overview | ✅ | ✅ | ✅ | ✅ |
| Customers | ✅ | ✅ | ✅ | ✅ |
| Prospects | ✅ | ✅ | ✅ | ✅ |
| Employees | ✅ | ✅ | ✅ | ❌ |
| Gifting | ✅ | ✅ | ✅ | ✅ |
| Settings | ✅ | ❌ | ❌ | ❌ |

## E. Profile Dropdown Actions

The user profile dropdown in the top bar shows role-appropriate options:

| Action | Owner | Executive | Manager | Rep |
|:-------|:------|:----------|:--------|:----|
| My Profile | ✅ | ✅ | ✅ | ✅ |
| Settings | ✅ | ❌ | ❌ | ❌ |
| Sign Out | ✅ | ✅ | ✅ | ✅ |

## F. Cross-Tab Auth Sync

**File:** `main-theme-v34.js`, Line 29010

```javascript
window.addEventListener('storage', function(e) {
    if (e.key === 'whitebox_role' || e.key === 'whitebox_username' || e.key === null) {
        // Refreshes role-aware UI across all open tabs
    }
});
```

This ensures that login/logout events in one tab immediately propagate to other open tabs of the website.

---

## Supabase Migration Notes

| Current | Target |
|:--------|:-------|
| `localStorage` role tokens | Supabase session + `profiles.role` lookup |
| Client-side role filtering | Supabase RLS policies (see Section 14) |
| Role selector dropdown (demo) | Remove entirely — role from `profiles` table only |
| `recordBelongsToRep()` JS function | RLS: `assigned_rep_id = auth.uid()` |
| View mode toggles (`ownerCustViewMode`, etc.) | Client-side filter params applied to Supabase queries |
| Settings tab visibility | `profiles.role = 'owner'` check |
| Cross-tab sync via `storage` event | `supabase.auth.onAuthStateChange()` |
