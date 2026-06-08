# Phase 2 Auth Security Review
## WhiteBox RMOS Authentication Security Analysis

This review analyzes potential security vectors, vulnerabilities, and mitigations in the proposed Supabase Auth integration.

---

## 1. Privilege Escalation Risks

### Threat: Metadata Manipulation on Registration
During self-registration, a malicious user can intercept the HTTP payload and append `raw_user_meta_data: {"role": "owner"}` to the request.
*   **Vulnerability Level:** Critical (if unchecked).
*   **Mitigation:** The database trigger `public.handle_new_user()` checks the session creator via `auth.uid()`. If `auth.uid()` is null (signifying self-signup) or does not have a profile role of `'owner'`, the metadata role is ignored, and the user is forced to `'rep'`.

### Threat: Workspace Injection on Invited Flow
An Owner of Workspace A invites an employee but alters the payload to set the employee's workspace ID to Workspace B, causing unauthorized profile entry into another tenant.
*   **Vulnerability Level:** High (Cross-tenant mapping leakage).
*   **Mitigation:** The trigger `public.handle_new_user()` ignores any `workspace_id` parameters passed in user metadata. Instead, if an active session is detected (`auth.uid() IS NOT NULL`), the user's workspace is hard-assigned using the creator's `public.get_my_workspace()`.

### Threat: Self-Promotion via Profiles Table Updates
A sales representative can execute an API update call targeting `public.profiles` to elevate their role column to `manager` or `owner`.
*   **Vulnerability Level:** Critical.
*   **Mitigation:** 
    1.  RLS policies on `profiles` prevent reps from performing `UPDATE` queries on columns other than their own avatar and contact numbers.
    2.  The trigger `prevent_role_escalation()` rejects any role column changes unless executed by a workspace Owner.

---

## 2. Multi-Tenant Data Isolation & Bypasses

### Threat: Security Definitive Trigger Cross-Updates
Because PostgreSQL trigger functions are declared as `SECURITY DEFINER` (running with high database permissions and bypassing row-level filters), an Owner of Tenant A could theoretically execute a profile update query passing an ID of Tenant B.
*   **Vulnerability Level:** High (Cross-tenant data corruption).
*   **Mitigation:** The update trigger function `prevent_role_escalation()` verifies that both the record's existing workspace (`OLD.workspace_id`) and the new workspace (`NEW.workspace_id`) match the actor's active workspace `public.get_my_workspace()`. If there is a mismatch, the transaction is immediately aborted.

---

## 3. Signup Abuse & Spam Protection

### Threat: Automated Registration Spam
Bots can target the signup endpoints to create thousands of fake rep accounts, exhausting the database connection pool or workspace resources.
*   **Vulnerability Level:** Medium.
*   **Mitigation:**
    *   **Disable Self-Signup:** In production, standard self-signup is disabled inside the Supabase Auth settings. Users must be created via invitation only (`inviteUserByEmail`).
    *   **CAPTCHA Integration:** Standard signup is guarded by Cloudflare Turnstile or Google reCAPTCHA v3.

---

## 4. Session Security & Hijacking

### Threat: JWT Theft & Token Expiration
If a user's access token is stolen from browser storage, a malicious actor can query the database.
*   **Vulnerability Level:** High.
*   **Mitigation:**
    *   **Short Token Expiry:** Set Supabase JWT access token lifespan to 1 hour.
    *   **HTTP-Only Cookies:** Store session state in HTTP-Only, Secure, SameSite=Strict cookies rather than `localStorage` when possible, shielding the JWT from XSS scripts.
    *   **Revocation Checks:** When a user profile status is set to `revoked`, RLS policies instantly block database access, even if the user has an active JWT that has not expired yet.

---

## 5. Single-Owner Lockout Protection

### Threat: Accidental Demotion of Last Owner
An Owner attempts to demote their profile role to Rep or deactivates their account, leaving the workspace without any administrative user.
*   **Vulnerability Level:** Medium (leads to total tenant lockout).
*   **Mitigation:** The trigger `prevent_role_escalation()` checks if the profile role change targets the last active Owner. If the active Owner count is `<= 1`, the update query is aborted with a constraint exception.

---

## 6. Seat Limitation Locks

### Threat: Seat Count Bypass
An Owner invites more employees than their paid subscription plan allows.
*   **Vulnerability Level:** Low (Financial leak).
*   **Mitigation:** A database constraint trigger on `public.profiles` counts active profiles against the workspace's seat limit. If `profile_count >= seat_limit`, invitations are blocked.
