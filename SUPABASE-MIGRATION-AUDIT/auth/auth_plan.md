# Phase 2 Auth Architecture Plan
## WhiteBox RMOS Authentication & User Synchronization

This document outlines the architecture, database triggers, security controls, and integration workflows to migrate WhiteBox RMOS authentication from a client-side mock framework to **Supabase Auth** and Postgres triggers.

---

## 1. Supabase Auth Core Workflow

The dashboard will shift from insecure `users.json` checking to JWT-based Supabase Auth:
1.  **Authentication Gate:** The client logs in via the website login page (`login.html`) using `supabase.auth.signInWithPassword()`.
2.  **JWT Retrieval:** Supabase Auth returns a JSON Web Token (JWT) and a refresh token, stored securely in the browser.
3.  **Local Storage Deprecation:** The plain text keys `whitebox_role` and `whitebox_username` inside `localStorage` are deprecated. Frontend components will query user profiles dynamically via Supabase sessions.

---

## 2. Profiles Mapping & Auto-Creation Trigger

We utilize a PostgreSQL function and trigger on the `auth.users` table inside the `auth` schema:
*   **The Bridge:** When a new user registers or is invited, Supabase creates a row in `auth.users`. A database trigger (`on_auth_user_created`) automatically copies credentials to `public.profiles`.
*   **Safe Execution:** The trigger runs with `SECURITY DEFINER` privileges, bypassing standard RLS to safely populate profiles.

---

## 3. Safe Role Assignment & Sign-Up Protection

To prevent anonymous signup abuse (where a user attempts to self-provision as `owner` or `executive` via modified client metadata):
*   **The Rule:** Anonymous registration defaults strictly to `'rep'::public.user_role`.
*   **Admin Override:** Metadata roles are trusted **only** if the transaction initiator has a profile with `role = 'owner'`.
*   **Workspace Mapping Protection:** On invited flows, the trigger ignores any client-supplied `workspace_id` in user metadata and instead assigns the user to the creator's `workspace_id` (preventing cross-tenant metadata spoofing).
*   **Role Change Constraint:** A trigger on `public.profiles` blocks updates to the `role` column unless executed by an Owner.

---

## 4. Default Workspace Bootstrap Dependency

Because `public.profiles` requires a non-null `workspace_id`, any user signup will fail if no workspaces exist:
*   **Requirement:** At least one default workspace record (e.g., `WhiteBox Headquarters`) must be seeded in the `workspaces` table before enabling Auth triggers or allowing registration.
*   **Trigger Fallback:** If a signup does not provide a specific `workspace_id` in metadata, the profile trigger queries and assigns the first available workspace in `public.workspaces`.

---

## 5. User Invites & Provisioning

*   **Who can invite:** Only users with `role = 'owner'` have the permission to invite staff.
*   **Invitation Flow:**
    1.  The Owner goes to Settings -> Seat Provisioning.
    2.  They enter the new employee's name, email, and select their role (`rep`, `manager`, or `executive`).
    3.  The frontend calls the Supabase Admin API (`supabase.auth.admin.inviteUserByEmail()`) or inserts a row into an invitations queue.
    4.  An invitation email is sent to the employee.
    5.  Once the employee clicks the invitation link and sets a password, the `on_auth_user_created` trigger fires, matching the pre-selected role from metadata.

---

## 6. Revoked Users & Session Expiration

*   **Revocation Mechanism:** An Owner deactivates an employee by changing their profile status to `status = 'revoked'`.
*   **RLS Enforcement:** All database RLS policies evaluate both workspace alignment and status:
    ```sql
    (SELECT status FROM public.profiles WHERE id = auth.uid()) = 'active'
    ```
    If status is `'revoked'`, all select/write actions are instantly blocked.
*   **Session Kill:** The frontend checks the profile state on session launch. If revoked, it automatically calls `supabase.auth.signOut()` and redirects to login.

---

## 7. Password Reset & Self-Service

*   **Triggering Resets:** Users click "Forgot Password" on the website portal, calling `supabase.auth.resetPasswordForEmail()`.
*   **Recovery Flow:**
    1.  Supabase emails a secure recovery link.
    2.  Clicking the link redirects the user to `app.whiteboxworks.com/reset-password.html` with a recovery token.
    3.  The user inputs a new password, validated via `supabase.auth.updateUser()`.

---

## 8. Frontend Session & Routing Flow

```
+------------------+       Successful Auth       +--------------------------+
| website/login    | -------------------------> | app.whiteboxworks.com/   |
| (Uses Supabase)  |                            | (Validates JWT Session)  |
+------------------+                            +--------------------------+
                                                              |
                                                    +---------+---------+
                                                    |                   |
                                            Active Profile       Revoked / Expired
                                                    |                   |
                                                    v                   v
                                            Render Dashboard     Redirect to Login
```

*   **Unified Domain:** The website runs on `whiteboxworks.com` and the dashboard runs on the sub-domain `app.whiteboxworks.com`.
*   **Cross-Domain Cookie Sharing:** JWT tokens can be shared across sub-domains via HTTPS-secured cookies, enabling immediate redirection.
*   **Redirection Router:** On successful login, the website routes to `/dashboard`. The dashboard validation script checks if a valid session exists. If missing, it immediately redirects back to the login page.

---

## 9. Cross-Tenant Modification Protections

To protect workspace isolation boundaries:
*   **Security Definitive Bypasses Block:** Triggers are executed as `SECURITY DEFINER` (bypassing RLS). To prevent an owner in Workspace A from updating profile properties in Workspace B, the trigger explicitly aborts transactions if the targeted record does not belong to the user's active workspace.

---

## 10. Files to Create in Phase 2

During implementation, the following files will be deployed:
1.  **`SUPABASE-MIGRATION-AUDIT/auth/auth_triggers.sql`**: The production triggers initializing profiles and protecting roles.
2.  **`src/auth.js`** (Vite Dashboard): Client authentication wrapper library.
3.  **`public-website/login.html`**: Updated web login form connected to Supabase Auth.
