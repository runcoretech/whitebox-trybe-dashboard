# Phase 3 RLS Security Review
## WhiteBox RMOS Row Level Security Vulnerability Audit

This security review analyzes potential bypass vectors, RLS weaknesses, and access loopholes in the Phase 3 database layout.

---

## 1. Identified Security Vectors & Mitigations

### Threat A: Direct assigned_rep_id Alteration (Poaching)
A rep executes a direct `UPDATE` query on `public.contacts` to change the `assigned_rep_id` to their own profile ID, effectively stealing a client from a peer.
*   **Vulnerability Level:** High.
*   **Mitigation:** 
    1.  The RLS update policy for contacts:
        `contacts_rep_write` enforces `assigned_rep_id = auth.uid()`. It does not allow updating records where they are not *already* the owner.
    2.  If the rep attempts to claim a neglected client from the recovery board, they cannot update the contact directly. They must insert a request into `public.recovery_requests`.
    3.  A database-level check trigger `prevent_direct_reassignments` rejects update transactions on `assigned_rep_id` unless executed by an Owner or the system executing an approved recovery request.

### Threat B: Gift Status Bypass (Financial Fraud)
A rep inserts a gift record directly with `status = 'approved'` or updates a pending gift to `approved` to bypass approval thresholds.
*   **Vulnerability Level:** Critical.
*   **Mitigation:** The RLS INSERT policy `gifts_rep_insert` enforces `WITH CHECK (status = 'pending'::public.gift_status)`. The UPDATE policy `gifts_rep_update` enforces `WITH CHECK (status = 'pending'::public.gift_status)`. This prevents reps from ever setting or changing the status column.

### Threat C: Client-Side Override of RLS Toggles
A malicious user modifies the dashboard JavaScript code in the browser using DevTools to toggle nav tabs and expose settings or directories.
*   **Vulnerability Level:** Low.
*   **Mitigation:** The frontend toggles are only visual decorations. If a user bypasses JS controls to expose the Settings tab, any API queries sent to Supabase targeting `workspace_settings` or `integration_credentials` will be blocked by RLS policies, returning an empty dataset.

### Threat D: Self-Approval on Fumble Claims
A manager submits a claim request to recover a client, then approves their own request to bypass Owner audit review.
*   **Vulnerability Level:** Medium.
*   **Mitigation:** The `recovery_requests` table enforces a check constraint:
    ```sql
    CONSTRAINT chk_reviewer_is_distinct CHECK (requester_rep_id <> reviewed_by)
    ```
    This blocks self-approval updates.

### Threat E: Revoked User Access Leaks (Active Sessions)
An employee is fired, and their profile status is set to `'revoked'`. However, their JWT access token remains valid in the browser for up to an hour.
*   **Vulnerability Level:** High.
*   **Mitigation:** The secure context helper functions (`public.get_my_role()` and `public.get_my_workspace()`) check `status = 'active'`. If status is revoked, the helpers return `NULL`, rendering all RLS policies immediately `false` and terminating data access.

---

## 2. Export & Report Data Exfiltrations

### Threat: Bulk CSV/PDF Data Exfiltration
A Rep or Manager exports the entire customer list or audit ledger to CSV.
*   **Mitigation:** 
    *   Reps and Managers cannot access `public.audit_logs`. The table blocks SELECT access entirely.
    *   Reps can only select contacts assigned to them. If they trigger a CSV export, the query results are filtered by RLS, allowing them to export only their own records.
    *   Bulk CSV downloads of the entire workspace are restricted to Owners.
