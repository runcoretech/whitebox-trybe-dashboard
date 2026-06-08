# Phase 3 Row Level Security Plan
## WhiteBox RMOS Access Control & Permissions Architecture

This document defines the complete **Row Level Security (RLS)** and authorization architecture for the WhiteBox RMOS. It details helper functions, RLS logic filters, visibility cadences, and approval gates.

---

## 1. RLS Strategy Overview

The RMOS RLS system enforces isolation across three coordinates:
1.  **Multi-Tenant Isolation:** Guaranteed by filtering all tables via `workspace_id = public.get_my_workspace()`. No query can leak rows across organizations.
2.  **Role-Based Filtering:** Columns and rows are gated based on the caller's role (`owner`, `executive`, `manager`, or `rep`).
3.  **Active Status Validation:** Any profile with `status = 'revoked'` is denied all database access.

---

## 2. Secure Context Helper Functions

To optimize query compilation and keep RLS policies readable, we declare two core context helper functions:
*   **`public.get_my_role()`**: Returns the role of the authenticated user (`owner`, `executive`, `manager`, or `rep`).
*   **`public.get_my_workspace()`**: Returns the workspace ID of the authenticated user.

> [!IMPORTANT]
> **Deactivation Kill Switch:** Both helper functions check the `public.profiles` table and enforce `status = 'active'`. If a user is deactivated (status = `'revoked'`), both helpers return `NULL`, causing all downstream RLS policies to evaluate to `false` and block access.

---

## 3. Granular Role Scoping Rules

### 1. `owner` (Full Workspace Control)
*   **Permissions:** Select, Insert, Update, and Delete over all workspace records.
*   **Settings:** Full write access to `workspace_settings`.
*   **Security:** Full view of `audit_logs` and `integration_credentials`.

### 2. `executive` (Read-Only Company-Wide Audit)
*   **Permissions:** Select-only over all workspace tables. Write access is blocked.
*   **Settings:** Read-only settings and credentials check (API secret keys are redacted).
*   **Security:** Read-only access to `audit_logs` for compliance auditing.

### 3. `manager` (Team Scoped Management)
*   **Permissions:** CRUD access on contacts, activities, and calendars for themselves and their direct reports (`manager_id = auth.uid()`).
*   **Fumble Queue:** Can claim and approve/reject claims for team accounts.
*   **Blocked:** No access to `workspace_settings`, `audit_logs`, or `integration_credentials`.

### 4. `rep` (Self-Scoped Sales Execution)
*   **Permissions:** Access restricted exclusively to assigned contacts, logs, and orders (`assigned_rep_id = auth.uid()`).
*   **Gifting Limit:** Can insert gifts with `status = 'pending'` only. Cannot update the `status` column to bypass approval gates.
*   **Fumble Queue:** Can only see Fumbles if the contact is assigned to them or has entered the open pool (> 75 days inactive).

---

## 4. Gifting Approval & Status Protections

To prevent reps or managers from bypassing the financial threshold gates:
*   **INSERT Restriction:** Reps can insert gifts, but RLS forces `status = 'pending'::public.gift_status`.
*   **UPDATE Restriction:** Reps can only update gifts where `status = 'pending'`. The update policy blocks modifying the `status` column to approved or delivered.
*   **Approval Authority:** Only workspace Owners can change status to `approved`, `dispatched`, or `delivered` (unless `manager_override` is enabled and the cost is below the `approval_threshold`).

---

## 5. Fumble System Cadences (RLS Filtering)

The RLS policy on the `contacts` table determines visibility based on inactivity thresholds fetched dynamically from `workspace_settings`:

1.  **Active Zone (0 to 30 days):** Only visible to the assigned Rep.
2.  **Warning Zone (31 to 60 days):** Visible to Rep and the Rep's Manager.
3.  **Critical Grace Zone (61 to 75 days):** Visible to Rep, Manager, and Owner.
4.  **Open Fumble Pool (76+ days):** Visible to **all** Reps in the workspace for claiming.

---

## 6. Integration Secret Redactions

*   **`integration_credentials` Table:** Blocked entirely from Reps, Managers, and Executives. Only Workspace Owners can view credentials.
*   **`integration_mappings` Table:** Publicly queryable (read-only) by all workspace employees for syncing records. Write access is restricted to Owners.
