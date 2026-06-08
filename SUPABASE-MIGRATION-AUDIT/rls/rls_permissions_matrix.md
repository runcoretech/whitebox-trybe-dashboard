# Phase 3 RLS Permissions Matrix
## WhiteBox RMOS Role Access Control Matrix

This matrix charts the allowed CRUD operations, approval controls, and data scopes for each of the 16 tables by user role.

---

## 1. Table Permissions Matrix

| Table Name | Operations | `rep` | `manager` | `executive` | `owner` |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`workspaces`** | SELECT <br> INSERT <br> UPDATE <br> DELETE | Self Workspace <br> ❌ Blocked <br> ❌ Blocked <br> ❌ Blocked | Self Workspace <br> ❌ Blocked <br> ❌ Blocked <br> ❌ Blocked | Self Workspace <br> ❌ Blocked <br> ❌ Blocked <br> ❌ Blocked | Self Workspace <br> ❌ Blocked <br> ✅ Allowed <br> ❌ Blocked |
| **`profiles`** | SELECT <br> INSERT <br> UPDATE <br> DELETE | Workspace Users <br> ❌ Blocked <br> Self Profile <br> ❌ Blocked | Workspace Users <br> ❌ Blocked <br> Self Profile <br> ❌ Blocked | Workspace Users <br> ❌ Blocked <br> ❌ Blocked <br> ❌ Blocked | Workspace Users <br> ✅ Allowed <br> All Workspace <br> ✅ Allowed |
| **`workspace_settings`** | SELECT <br> INSERT <br> UPDATE <br> DELETE | ✅ Allowed <br> ❌ Blocked <br> ❌ Blocked <br> ❌ Blocked | ✅ Allowed <br> ❌ Blocked <br> ❌ Blocked <br> ❌ Blocked | ✅ Allowed <br> ❌ Blocked <br> ❌ Blocked <br> ❌ Blocked | ✅ Allowed <br> ✅ Allowed <br> ✅ Allowed <br> ✅ Allowed |
| **`organizations`** | SELECT <br> INSERT <br> UPDATE <br> DELETE | Assigned Orgs <br> ❌ Blocked <br> ❌ Blocked <br> ❌ Blocked | Team Orgs <br> ✅ Allowed <br> ✅ Allowed <br> ✅ Allowed | All Workspace <br> ❌ Blocked <br> ❌ Blocked <br> ❌ Blocked | All Workspace <br> ✅ Allowed <br> ✅ Allowed <br> ✅ Allowed |
| **`contacts`** | SELECT <br> INSERT <br> UPDATE <br> DELETE | Assigned / Open Fumble <br> ✅ Allowed <br> Assigned <br> ❌ Blocked | Team / Open Fumble <br> ✅ Allowed <br> Team Contacts <br> ❌ Blocked | All Workspace <br> ❌ Blocked <br> ❌ Blocked <br> ❌ Blocked | All Workspace <br> ✅ Allowed <br> ✅ Allowed <br> ✅ Allowed |
| **`activities`** | SELECT <br> INSERT <br> UPDATE <br> DELETE | Self-logged <br> Self-logged <br> ❌ Blocked <br> ❌ Blocked | Team-logged <br> Team-logged <br> Team-logged <br> ❌ Blocked | All Workspace <br> ❌ Blocked <br> ❌ Blocked <br> ❌ Blocked | All Workspace <br> ✅ Allowed <br> ✅ Allowed <br> ✅ Allowed |
| **`boxes`** | SELECT <br> INSERT <br> UPDATE <br> DELETE | ✅ Allowed <br> ❌ Blocked <br> ❌ Blocked <br> ❌ Blocked | ✅ Allowed <br> ❌ Blocked <br> ❌ Blocked <br> ❌ Blocked | ✅ Allowed <br> ❌ Blocked <br> ❌ Blocked <br> ❌ Blocked | ✅ Allowed <br> ✅ Allowed <br> ✅ Allowed <br> ✅ Allowed |
| **`gifts`** | SELECT <br> INSERT <br> UPDATE <br> DELETE | Self-logged <br> Self (status='pending') <br> Self (status='pending') <br> ❌ Blocked | Team-logged <br> Team (status='pending') <br> Team (status='pending') <br> ❌ Blocked | All Workspace <br> ❌ Blocked <br> ❌ Blocked <br> ❌ Blocked | All Workspace <br> ✅ Allowed <br> ✅ Allowed <br> ✅ Allowed |
| **`calendar_events`** | SELECT <br> INSERT <br> UPDATE <br> DELETE | Self-owned <br> Self-owned <br> Self-owned <br> Self-owned | Team-owned <br> Team-owned <br> Team-owned <br> Team-owned | All Workspace <br> ❌ Blocked <br> ❌ Blocked <br> ❌ Blocked | All Workspace <br> ✅ Allowed <br> ✅ Allowed <br> ✅ Allowed |
| **`nudges`** | SELECT <br> INSERT <br> UPDATE <br> DELETE | Self-owned <br> ❌ Blocked <br> Self-owned (is_read) <br> Self-owned | Self-owned <br> ❌ Blocked <br> Self-owned (is_read) <br> Self-owned | Self-owned <br> ❌ Blocked <br> Self-owned (is_read) <br> Self-owned | All Workspace <br> ✅ Allowed <br> All Workspace <br> All Workspace |
| **`cosmo_audits`** | SELECT <br> INSERT <br> UPDATE <br> DELETE | Assigned Contacts <br> ❌ Blocked <br> ❌ Blocked <br> ❌ Blocked | Team Contacts <br> ❌ Blocked <br> ❌ Blocked <br> ❌ Blocked | All Workspace <br> ❌ Blocked <br> ❌ Blocked <br> ❌ Blocked | All Workspace <br> ❌ Blocked <br> ❌ Blocked <br> ❌ Blocked |
| **`audit_logs`** | SELECT <br> INSERT <br> UPDATE <br> DELETE | ❌ Blocked <br> ❌ Blocked <br> ❌ Blocked <br> ❌ Blocked | ❌ Blocked <br> ❌ Blocked <br> ❌ Blocked <br> ❌ Blocked | ✅ Allowed <br> ❌ Blocked <br> ❌ Blocked <br> ❌ Blocked | ✅ Allowed <br> ❌ Blocked <br> ❌ Blocked <br> ❌ Blocked |
| **`contact_assignments`** | SELECT <br> INSERT <br> UPDATE <br> DELETE | Self-involved <br> ❌ Blocked <br> ❌ Blocked <br> ❌ Blocked | Team-involved <br> ❌ Blocked <br> ❌ Blocked <br> ❌ Blocked | All Workspace <br> ❌ Blocked <br> ❌ Blocked <br> ❌ Blocked | All Workspace <br> ❌ Blocked <br> ❌ Blocked <br> ❌ Blocked |
| **`recovery_requests`** | SELECT <br> INSERT <br> UPDATE <br> DELETE | Self-requested <br> Self-requested <br> ❌ Blocked <br> Self-requested | Team-requested <br> Team-requested <br> Team-requested <br> Team-requested | All Workspace <br> ❌ Blocked <br> ❌ Blocked <br> ❌ Blocked | All Workspace <br> ✅ Allowed <br> ✅ Allowed <br> ✅ Allowed |
| **`integration_credentials`**| SELECT <br> INSERT <br> UPDATE <br> DELETE | ❌ Blocked <br> ❌ Blocked <br> ❌ Blocked <br> ❌ Blocked | ❌ Blocked <br> ❌ Blocked <br> ❌ Blocked <br> ❌ Blocked | ❌ Blocked <br> ❌ Blocked <br> ❌ Blocked <br> ❌ Blocked | ✅ Allowed <br> ✅ Allowed <br> ✅ Allowed <br> ✅ Allowed |
| **`integration_mappings`** | SELECT <br> INSERT <br> UPDATE <br> DELETE | ✅ Allowed <br> ❌ Blocked <br> ❌ Blocked <br> ❌ Blocked | ✅ Allowed <br> ❌ Blocked <br> ❌ Blocked <br> ❌ Blocked | ✅ Allowed <br> ❌ Blocked <br> ❌ Blocked <br> ❌ Blocked | ✅ Allowed <br> ✅ Allowed <br> ✅ Allowed <br> ✅ Allowed |

---

## 2. Advanced Feature Actions Matrix

### Gifting Actions
*   **Create Gift:** `rep`, `manager`, `owner`.
*   **Approve / Reject Gift:** Only `owner` has full rights. `manager` can approve only if `manager_override = true` and price is below `approval_threshold` in `workspace_settings`.
*   **Update Shipping Info:** `rep` (only if status is `pending`), `manager` (team gifts, only if status is `pending`), `owner` (any status).
*   **Update Carrier/Tracking:** Only `owner` (integrates with shipping server API).
*   **Mark Delivered:** Only `owner` (system-triggered via webhook hook).

### Fumble / Recovery Actions
*   **Create Recovery Request:** `rep`, `manager`.
*   **Approve / Reject Request:** `owner`, `manager` (within their regional branch/team only).
*   **Transfer Ownership:** Only `owner` and `manager` (automatic upon approval of request).
*   **View Leaderboards & Metrics:** All roles (used to drive rep competition).
