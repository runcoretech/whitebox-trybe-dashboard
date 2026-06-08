# WhiteBox RMOS Dashboard - Seed Security Review

This document evaluates database security, privacy risks, deployment safeguards, and production cleanup requirements during the Supabase database migration.

---

## 1. Security & Privacy Risks

### 1.1. Plaintext Password Cleanup
*   **Risk:** Plaintext credentials are currently stored in `public-website/users.json` and `public/users.json`.
*   **Mitigation:** These files must be deleted completely before launching the Supabase backend. All passwords stored in `auth.users` during development seeding must use high-entropy Bcrypt hashes (`$2a$10$...`) rather than raw text.

### 1.2. Production Database Seeding Hazard
*   **Risk:** Seeding dummy profiles (e.g., Jane Smith, Dwight Schrute, Initech Software) in a production workspace environment introduces data pollution and clutter.
*   **Mitigation:** The seed script (`seed_script_draft.sql`) is strictly for local/staging environment testing. In production deployment, a lean **bootstrap script** should be executed instead. This bootstrap script must ONLY initialize:
    1.  The primary tenant workspace scope.
    2.  The workspace Owner profile.
    3.  Default `workspace_settings` parameters.
    No mock organizations, activity timelines, calendar milestones, or demo reps should be inserted into production tables.

### 1.3. Credentials & Key Leaks
*   **Risk:** Leaking live database keys, JWT secrets, or Slack/Teams webhook URLs in git repository history.
*   **Mitigation:**
    *   No active third-party credentials or webhook keys are allowed in `seed_script_draft.sql`. Webhook fields are populated with dummy strings (`https://hooks.slack.com/...`).
    *   Ensure all Supabase configuration parameters (such as `SUPABASE_SERVICE_ROLE_KEY` or custom JWT keys) are read exclusively from environment variables (`.env`) which are explicitly declared in `.gitignore`.

---

## 2. Integrity of trigger operations

During seeding, triggers are temporarily disabled:
```sql
ALTER TABLE auth.users DISABLE TRIGGER on_auth_user_created;
ALTER TABLE public.profiles DISABLE TRIGGER check_role_escalation;
```
*   **Security Control:** If the seed transaction crashes mid-execution, PostgreSQL rolls back all changes, restoring triggers to their active status.
*   **Verification:** Ensure that every seed script contains a matching `ENABLE TRIGGER` pair prior to the transaction `COMMIT` block. This guarantees that RLS checks, self-promotion blocks, and cross-tenant escalation checks are fully active when live users begin signing up.

---

## 3. Post-Migration Security Checklist

Prior to staging the final Supabase project, execute the following steps:

1.  [ ] **Purge Mock JSON Files:** Delete `/public-website/users.json` and `/public/users.json` from the repository root.
2.  [ ] **Remove Role Selector UI:** Delete the demo-only role selector dropdown from the dashboard header in `dashboard/index.html`.
3.  [ ] **Decouple LocalStorage Tokens:** Replace all `localStorage` reads (`whitebox_role`, `whitebox_username`) with real session verification checks using `supabase.auth.getSession()`.
4.  [ ] **Confirm SSL Encryption:** Verify that all Supabase API endpoints connect over HTTPS with TLS 1.3 enforced.
5.  [ ] **Enforce RLS Audit:** Run a security sweep on the database to ensure all 16 tables show `ROW LEVEL SECURITY ENABLED` in the PostgreSQL database directory:
    ```sql
    SELECT tablename, rowsecurity FROM pg_tables WHERE schemaname = 'public';
    ```
