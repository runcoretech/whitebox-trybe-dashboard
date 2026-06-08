# Phase 3 RLS Testing Plan
## WhiteBox RMOS Row Level Security Test Cases

This testing plan outlines test suites to verify that the PostgreSQL RLS policies, helper functions, and views successfully isolate data and enforce permission boundaries.

---

## 1. Test Setup Prerequisites

To execute these tests, the database must contain:
1.  **Two Workspaces:** Workspace A (`WhiteBox HQ`) and Workspace B (`Apex HQ`).
2.  **Profiles:**
    *   `Owner A` and `Rep A1` (Workspace A).
    *   `Owner B` and `Rep B1` (Workspace B).
3.  **Active Contacts:**
    *   `Contact A` (assigned to Rep A1 in Workspace A).
    *   `Contact B` (assigned to Rep B1 in Workspace B).

---

## 2. RLS Security Test Cases

### Test Case 2.1: Multi-Tenant Data Leakage Block
*   **Goal:** Verify that a representative cannot see contacts in another tenant workspace.
*   **Steps:**
    1.  Authenticate session as `Rep B1` (Workspace B).
    2.  Execute query:
        ```sql
        SELECT * FROM public.contacts;
        ```
*   **Expected Result:** Only `Contact B` is returned. `Contact A` is hidden.

### Test Case 2.2: Rep Self-Scope Visibility Block
*   **Goal:** Verify that a Representative cannot see contacts assigned to another Rep, even within the same workspace.
*   **Steps:**
    1.  Add `Rep A2` and assign them `Contact A2` (Workspace A).
    2.  Authenticate session as `Rep A1`.
    3.  Execute query:
        ```sql
        SELECT * FROM public.contacts;
        ```
*   **Expected Result:** Only `Contact A` is returned. `Contact A2` is hidden.

### Test Case 2.3: Gifting Approval Gate Bypass Block
*   **Goal:** Verify that a Representative cannot bypass approval by directly inserting or updating a gift's status.
*   **Steps:**
    1.  Authenticate session as `Rep A1`.
    2.  Attempt insert:
        ```sql
        INSERT INTO public.gifts (contact_id, rep_id, box_id, category, amount, status, workspace_id)
        VALUES ('contact-uuid-here', auth.uid(), 'box-uuid-here', 'reach', 100.00, 'approved', 'ws-uuid-here');
        ```
*   **Expected Result:** Query fails with RLS `WITH CHECK` constraint violation. (Insert is blocked unless status is `'pending'`).

### Test Case 2.4: Revoked User Access Kill Switch
*   **Goal:** Verify that a deactivated profile status blocks all access immediately.
*   **Steps:**
    1.  Authenticate session as `Rep A1`.
    2.  Verify data is queryable.
    3.  In Owner A's session, execute:
        ```sql
        UPDATE public.profiles SET status = 'revoked'::public.profile_status WHERE id = 'rep-a1-uuid-here';
        ```
    4.  Attempt a SELECT query from Rep A1's session.
*   **Expected Result:** Query returns an empty dataset (Access blocked).

### Test Case 2.5: Fumble Queue Exclusivity (Grace Window Checks)
*   **Goal:** Verify that other representatives cannot see neglected contacts during their Warning/Grace zones.
*   **Steps:**
    1.  Locate `Contact A` (assigned to `Rep A1`).
    2.  Inactivities calculations: set last activity to 40 days ago (Warning zone).
    3.  Authenticate session as `Rep A2` (another rep in same workspace).
    4.  Query `public.contacts` where `id = Contact A`.
*   **Expected Result:** Query returns empty dataset. (Not claimable yet).
    5.  Set last activity to 76 days ago (Open Fumble Pool).
    6.  Re-run query from `Rep A2`'s session.
*   **Expected Result:** `Contact A` is returned (visible for claim).

### Test Case 2.6: Self-Claim Approval Block (Manager Checks)
*   **Goal:** Verify that a manager cannot approve a claim request they submitted.
*   **Steps:**
    1.  Authenticate session as `Manager A`.
    2.  Insert a recovery request for `Contact A` (assigning requester to `Manager A`).
    3.  Attempt to update `status = 'approved'` and `reviewed_by = Manager A`.
*   **Expected Result:** Update fails with database check constraint violation: `chk_reviewer_is_distinct`.

---

## 3. Stored Procedure & Views Audits

### Test Case 3.1: Stored Procedure Security Invoker Check
*   **Goal:** Verify that RPC functions execute under the caller's RLS constraints.
*   **Steps:**
    1.  Authenticate session as `Rep A1`.
    2.  Execute RPC:
        ```sql
        SELECT * FROM public.get_kpi_summary(30);
        ```
*   **Expected Result:** Counts returned reflect only Rep A1's assigned leads.
