# WhiteBox RMOS Dashboard - Seed Mapping Plan

This document establishes the detailed table-by-table mapping from the mock/demo data structures to the 16 approved Supabase database tables.

---

## 1. Table-by-Table Schema Mapping

### 1.1. `workspaces`
*   **Source Data:** Implicit single organization workspace in the demo dashboard ("WhiteBox Giftworks").
*   **Columns to Seed:**
    *   `id`: Static UUID (`4a9df364-58ad-4fa9-83bc-2234559c5d01`)
    *   `name`: `'WhiteBox Giftworks'`
    *   `subdomain`: `'whitebox'`
    *   `logo_url`: `'https://app.whiteboxworks.com/assets/logo-whitebox.png'` (default branding)
    *   `theme`: `'{"primary": "#6366f1", "dark_mode": true}'`
*   **Notes:** This is the single tenant bootstrap workspace. All other table seeds must reference this `workspace_id`.

---

### 1.2. `profiles`
*   **Source Data:** `users.json`, `employeesData`, `activeSeatsList`
*   **Columns to Seed:**
    *   `id`: Static UUIDs mapped to `auth.users`
    *   `email`: Mapped from employee record email address
    *   `name`: Mapped from employee name
    *   `role`: Mapped to `user_role` enum (`owner`, `executive`, `manager`, `rep`)
    *   `manager_id`: Mapped to manager profile UUID (e.g. `Tom Collins.manager_id` -> `Marcus Dupond.id`)
    *   `workspace_id`: `4a9df364-58ad-4fa9-83bc-2234559c5d01`
    *   `avatar_url`: Seeding with initials-based placeholders or generic image assets
    *   `status`: `'active'`
*   **Role Mapping Translation:**
    *   `users.json` uses `'hr'` for Sarah Lansky. The database schema uses the enum `'executive'` for this tier. We map `'hr'` -> `'executive'`.
    *   Implicit user `Paul K. (owner@whitebox.com)` is the primary Owner.
    *   Gregory Sterling (CEO) is seeded as an `'executive'` since he shares organizational visibility without system configuration access.
*   **Stable UUID Mappings:**
    *   `Paul K. (owner)`: `8b1933c0-0f0e-4361-b472-3c8cfa2b9801`
    *   `Gregory Sterling (executive/CEO)`: `8b1933c0-0f0e-4361-b472-3c8cfa2b9802`
    *   `Sarah Lansky (executive/CPO)`: `8b1933c0-0f0e-4361-b472-3c8cfa2b9803`
    *   `Emily Davis (executive/VP)`: `8b1933c0-0f0e-4361-b472-3c8cfa2b9804`
    *   `Marcus Dupond (manager)`: `8b1933c0-0f0e-4361-b472-3c8cfa2b9805`
    *   `Jane Smith (manager)`: `8b1933c0-0f0e-4361-b472-3c8cfa2b9806`
    *   `Tom Collins (rep)`: `8b1933c0-0f0e-4361-b472-3c8cfa2b9807`
    *   `Dwight Schrute (rep)`: `8b1933c0-0f0e-4361-b472-3c8cfa2b9808`
    *   `John Doe (rep)`: `8b1933c0-0f0e-4361-b472-3c8cfa2b9809`
    *   `Alice Cooper (rep)`: `8b1933c0-0f0e-4361-b472-3c8cfa2b9810`
    *   `Bob Martin (rep)`: `8b1933c0-0f0e-4361-b472-3c8cfa2b9811`
    *   `Charlie Brown (rep)`: `8b1933c0-0f0e-4361-b472-3c8cfa2b9812`

---

### 1.3. `workspace_settings`
*   **Source Data:** `window.rmosSettings` (Line 233881)
*   **Columns to Seed:** Matches default settings object exactly (e.g. `decay_warning = 30`, `decay_critical = 60`, `budget_monthly = 500.00`, etc.).
*   **Relationships:** Mapped via `workspace_id` (`4a9df364-58ad-4fa9-83bc-2234559c5d01`).

---

### 1.4. `organizations`
*   **Source Data:** `customersData`, `prospectsData`, and inline HTML lists.
*   **Columns to Seed:**
    *   `id`: Static UUID
    *   `name`: Client/Prospect organization name (e.g., `'Apex Global Retail'`, `'Chevron Solutions'`)
    *   `sector`: Read from customer record sector property (e.g. `'Enterprise B2B'`, `'Prospect'`)
    *   `category`: `'enterprise'`, `'smb'`, or `'prospect'`
    *   `workspace_id`: `4a9df364-58ad-4fa9-83bc-2234559c5d01`
*   **Notes:** Multi-word sector text (e.g., "Enterprise B2B") matches the `sector` text column, while `category` parses categories into the enum values.

---

### 1.5. `contacts`
*   **Source Data:** Inline HTML attributes (from `index.html` lines 6288-7120) which list individual contact persons for organizations.
*   **Columns to Seed:**
    *   `id`: Static UUID
    *   `org_id`: UUID of parent organization
    *   `name`: Contact representative name (e.g. `'Lisa Kudrow'` for Pinnacle Brands, `'Dr. Aris'` for Nova Financial)
    *   `email`: Mapped from HTML dataset (e.g. `'sales@pinnacle.com'`)
    *   `phone`: Mapped from HTML dataset (e.g. `'(213) 555-0177'`)
    *   `assigned_rep_id`: UUID of the assigned sales profile
    *   `status`: `'active'`, `'inactive'`, or `'neglected'`
    *   `relationship_health`: Mapped from mock health %
    *   `ai_recommendation`: Mapped from `aiRecommend` metadata (e.g. `'Send Sweet Box for reaching retention.'`)
    *   `workspace_id`: `4a9df364-58ad-4fa9-83bc-2234559c5d01`

---

### 1.6. `activities`
*   **Source Data:** `clientGraphData` timeline arrays, `executiveActivityHistory`
*   **Columns to Seed:**
    *   `id`: Generated UUID
    *   `contact_id`: Mapped to contact profile UUID
    *   `rep_id`: Mapped to logging rep's profile UUID
    *   `type`: Activity type enum (`Call`, `Email`, `Meeting`, `Proposal`, `Gift`, `Note`, `System`)
    *   `grade`: Activity performance grade enum (`A`, `B`, `C`, `D`, `F`)
    *   `notes`: Timeline description text
    *   `workspace_id`: `4a9df364-58ad-4fa9-83bc-2234559c5d01`
    *   `logged_at`: Seeded with dates relative to baseline (e.g. `now() - INTERVAL '5 days'`) to ensure dashboard timeline views are populated appropriately.

---

### 1.7. `boxes`
*   **Source Data:** Box directories in the dashboard catalog (Sweet Box, Pack Box, Premium Box).
*   **Columns to Seed:**
    *   `id`: Static UUIDs:
        *   `Sweet Box` ($90.00): `9b1933c0-0f0e-4361-b472-3c8cfa2b9821`
        *   `Pack Box` ($80.00): `9b1933c0-0f0e-4361-b472-3c8cfa2b9822`
        *   `Premium Box` ($300.00): `9b1933c0-0f0e-4361-b472-3c8cfa2b9823`
    *   `name`: Box product name
    *   `price`: Decimal amount
    *   `workspace_id`: `4a9df364-58ad-4fa9-83bc-2234559c5d01`

---

### 1.8. `gifts`
*   **Source Data:** `giftingDispatchSchedule` and `activeB2BOrders`
*   **Columns to Seed:**
    *   `id`: Generated UUID
    *   `contact_id`: Recipient contact ID
    *   `rep_id`: Sender profile ID
    *   `box_id`: Associated box catalog ID
    *   `category`: Gift reason purpose category enum (`reach`, `retain`, `remember`, `reward`)
    *   `amount`: Historical purchase price (locked to box price or custom quote)
    *   `status`: Gifting pipeline status enum (`pending`, `awaiting_approval`, `awaiting_design`, `quote_ready`, `approved`, `dispatched`, `delivered`, `failed`, `rejected`)
    *   `shipping_street` / `shipping_city` / `shipping_province` / `shipping_postal`: Recipient address data
    *   `reason`: Descriptive text justifying the dispatch
    *   `workspace_id`: `4a9df364-58ad-4fa9-83bc-2234559c5d01`
    *   `dispatched_at` / `created_at`: Datetime limits

---

### 1.9. `calendar_events`
*   **Source Data:** `calendarEventsDB` and `executiveCalendarEvents`
*   **Columns to Seed:**
    *   `id`: Generated UUID
    *   `profile_id`: Owning profile UUID
    *   `type`: Event category (e.g. `'Performance Review'`, `'Client Strategic Meeting'`)
    *   `target`: Target name (entity or contact name)
    *   `event_date`: Date of the event
    *   `event_time`: Time of the event
    *   `agenda`: Notes / description
    *   `workspace_id`: `4a9df364-58ad-4fa9-83bc-2234559c5d01`

---

### 1.10. `nudges`
*   **Source Data:** `executiveNudges`
*   **Columns to Seed:**
    *   `id`: Generated UUID
    *   `profile_id`: target recipient profile (owner or rep)
    *   `message`: Warning text message (e.g. `Tom Collins conversion rate dropped 12%...`)
    *   `severity`: `'warning'` or `'critical'`
    *   `is_read`: `false`
    *   `workspace_id`: `4a9df364-58ad-4fa9-83bc-2234559c5d01`

---

### 1.11. `cosmo_audits`
*   **Source Data:** `activeAuditsDB` and inline HTML card summaries
*   **Columns to Seed:**
    *   `id`: Generated UUID
    *   `contact_id`: Mapped to contact ID (e.g. Vanguard Health, Chevron Logistics)
    *   `narrative`: Full markdown/text narrative explaining the risk breakdown
    *   `severity`: `'info'`, `'warning'`, or `'critical'`
    *   `workspace_id`: `4a9df364-58ad-4fa9-83bc-2234559c5d01`

---

### 1.12. `audit_logs`
*   **Source Data:** Security audits logged during setup.
*   **Columns to Seed:**
    *   `workspace_id`: `4a9df364-58ad-4fa9-83bc-2234559c5d01`
    *   `actor_name`: `'System Bootstrapper'`
    *   `role`: `'owner'`
    *   `action`: `'SEEDED_DATABASE'`
    *   `entity_type`: `'workspace'`
    *   `created_at`: `now()`
*   **Notes:** Seeding at least one record to verify partition mapping works correctly.

---

### 1.13. `contact_assignments`
*   **Source Data:** Implicit reassignment text logs.
*   **Columns to Seed:** We insert chronological reassignment events (e.g., reassigning Vanguard Health from Tom Collins to Paul K.) to establish baseline history.

---

### 1.14. `recovery_requests`
*   **Source Data:** Recovery Board default cards (`Vanguard Health`, `Nova Financial`).
*   **Columns to Seed:**
    *   `id`: Generated UUID
    *   `workspace_id`: `4a9df364-58ad-4fa9-83bc-2234559c5d01`
    *   `contact_id`: Contact UUID
    *   `original_rep_id`: Assigned rep UUID (e.g. Tom Collins)
    *   `requester_rep_id`: Reclaiming rep UUID (e.g. Marcus Dupond)
    *   `justification`: Reason for claim
    *   `status`: `'pending'`
    *   `created_at`: `now() - INTERVAL '1 days'`

---

### 1.15. `integration_credentials`
*   **Source Data:** None (Default settings are set to `false`).
*   **Columns to Seed:** No active credentials will be seeded. Columns will default to empty to enforce security and privacy.

---

### 1.16. `integration_mappings`
*   **Source Data:** None.
*   **Columns to Seed:** Left empty for post-migration sync triggers.

---

## 2. Mapping Gaps & Missing Schema Concerns

### 2.1. Dynamic Inactivity-Based Health Decay
*   **Concern:** In the mock code, `inactiveDays` is hardcoded as an integer (e.g. `34` or `42`). In the database, inactivity must be computed dynamically:
    `inactive_days = CURRENT_DATE - MAX(logged_at)` from activities.
*   **Resolution:** We must seed the activities history with `logged_at` dates matching the desired inactivity window. For example:
    *   To simulate Vanguard Health being inactive for **34 days**, we seed its latest activity record with `logged_at = now() - INTERVAL '34 days'`.
    *   To simulate Chevron Logistics being inactive for **42 days**, we seed its latest activity with `logged_at = now() - INTERVAL '42 days'`.
    This dynamic calculation ensures that when the SQL view runs, the computed inactivity matches the mock dashboard values exactly!

### 2.2. Contact-Organization Separation
*   **Concern:** The dashboard UI uses "Client Name" interchangeably to refer to both the Contact Person (Lisa Kudrow) and the Company (Pinnacle Brands).
*   **Resolution:** Our schema maps Companies to `organizations` and people to `contacts`. The seed script must insert the company first, capture its `id`, and then link the individual contact to that organization.

### 2.3. Seeding auth.users Safely
*   **Concern:** In Supabase, the public schema cannot insert foreign keys referencing `auth.users` until those records exist in the auth schema.
*   **Resolution:** The seed script must run in a single transaction that first inserts placeholder records into `auth.users` (using stable UUIDs and hashes for the passwords) and then inserts matching profiles into `public.profiles`. Triggers on `auth.users` must be disabled during the seeding transaction to avoid insert collisions.
