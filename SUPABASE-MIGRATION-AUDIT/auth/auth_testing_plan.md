# Phase 2 Auth Testing Plan
## WhiteBox RMOS User Authentication Test Cases

This testing plan outlines test suites to verify that the authentication triggers, profile sync routines, and role locks operate as intended before proceeding to frontend implementation.

---

## 1. Database Triggers & Profile Sync Test Suite

### Test Case 1.1: Standard Signup Profile Auto-Sync
*   **Goal:** Verify that a standard user signup creates a matching profile in `public.profiles`.
*   **Steps:**
    1.  Create a mock user in Supabase Auth using the SQL Admin Console or Supabase CLI:
        ```sql
        INSERT INTO auth.users (id, email, raw_user_meta_data)
        VALUES ('00000000-0000-0000-0000-000000000001', 'tester@whitebox.com', '{"name": "Test User"}');
        ```
    2.  Query `public.profiles` for the user:
        ```sql
        SELECT * FROM public.profiles WHERE id = '00000000-0000-0000-0000-000000000001';
        ```
*   **Expected Result:** A profile row is found, containing name = `Test User`, role = `rep`, status = `active`, and a default `workspace_id`.

### Test Case 1.2: Bootstrap Workspace Dependency Check
*   **Goal:** Verify that signup fails if no workspaces exist.
*   **Steps:**
    1.  Truncate the `workspaces` table in a local test environment.
    2.  Attempt to register a user.
*   **Expected Result:** Registration fails, raising a custom database exception: *"Bootstrap Error: No active workspaces found in public.workspaces. Seed a workspace first."*

### Test Case 1.3: Invited Workspace Mapping Force-Lock
*   **Goal:** Verify that an invited user is forced to match the creator admin's workspace, ignoring client metadata.
*   **Steps:**
    1.  Seed two workspaces (Workspace A and Workspace B).
    2.  Authenticate a session as Owner of Workspace A.
    3.  Create a user passing Workspace B's ID in metadata.
*   **Expected Result:** The user profile is created but assigned to Workspace A (matching the creator).

---

## 2. Role Security & Escalation Test Suite

### Test Case 2.1: Anonymous Role Escalation Prevention
*   **Goal:** Verify that a self-signup cannot elevate their role to `owner` or `executive`.
*   **Steps:**
    1.  Attempt a signup passing `raw_user_meta_data = {"role": "owner"}` as an anonymous requester.
    2.  Query `public.profiles` for the created user.
*   **Expected Result:** The profile is created, but the role column is forced to `rep`.

### Test Case 2.2: Rep Self-Promotion Block
*   **Goal:** Verify that a Rep cannot change their profile role.
*   **Steps:**
    1.  Authenticate a session as Rep (e.g. Tom Collins).
    2.  Execute an update query targeting the `profiles` table to set `role = 'owner'`.
*   **Expected Result:** Database blocks update, raising exception: *"Access Denied: Only Owners can modify profile role levels."*

### Test Case 2.3: Single Owner Protection Lock
*   **Goal:** Verify that the last active Owner cannot be demoted or deactivated.
*   **Steps:**
    1.  Locate the single active owner (e.g. Paul K.).
    2.  Execute an update query to change Paul's status to `revoked` or role to `rep`.
*   **Expected Result:** Database blocks update, raising exception: *"Constraint Error: Cannot demote or revoke the last remaining Owner in the workspace."*

### Test Case 2.4: Cross-Tenant Profile Modification Block
*   **Goal:** Verify that an Owner in Workspace A cannot modify profiles in Workspace B, even when executing updates with high trigger access.
*   **Steps:**
    1.  Create an Owner profile in Workspace A.
    2.  Create a Rep profile in Workspace B.
    3.  Attempt to update the Rep's profile status from the Workspace A Owner's session context.
*   **Expected Result:** Transaction is aborted, raising exception: *"Access Denied: Cross-tenant profile modifications are strictly prohibited."*

---

## 3. Session Expiration & Revocation Test Suite

### Test Case 3.1: Instant Access Block for Revoked Users
*   **Goal:** Verify that a revoked user is blocked from reading data, even with an active JWT.
*   **Steps:**
    1.  Log in as Rep `Tom Collins` and verify data is queryable.
    2.  In a separate session (as Owner), update Tom's profile: `status = 'revoked'`.
    3.  Attempt to query `public.contacts` from Tom's active session.
*   **Expected Result:** Tom's query fails with an RLS authorization error (denied read access).

---

## 4. Password Recovery & Reset Test Suite

### Test Case 4.1: Recovery Redirection Token Verification
*   **Goal:** Verify recovery redirects are routed to the proper sub-domain.
*   **Steps:**
    1.  Trigger a password recovery request for email `tester@whitebox.com`.
    2.  Inspect the secure link inside the test inbox.
*   **Expected Result:** The link targets `https://app.whiteboxworks.com/reset-password.html` containing the recovery token parameters.
