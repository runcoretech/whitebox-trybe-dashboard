# WhiteBox RMOS Dashboard - Mock Data Inventory

This document provides a comprehensive inventory of all mock, demo, sample, hardcoded, or calculated data currently used in the WhiteBox RMOS Dashboard repository.

---

## 1. Raw Mock Data Inventory

### 1.1. User Logins (`users.json`)
*   **File Name:** `users.json`
*   **Folder Path:** `/public-website/` (duplicated in `/public/`)
*   **Variable Name:** N/A (Plain JSON array)
*   **Data Type:** `Array<Object>`
*   **Dashboard Feature:** Authentication/Login screen (`login.html`)
*   **Target Supabase Table:** `auth.users` (linked to `public.profiles` via trigger)
*   **Relationships:** N/A
*   **Data Classification:** Raw data
*   **Action Plan:** **Seed data** (seeding both `auth.users` and `public.profiles`). Delete file entirely post-migration.

---

### 1.2. Employee & Rep Profiles (`employeesData`)
*   **File Name:** `main-dashboard-v34.js`
*   **Folder Path:** `/dashboard/`
*   **Variable Name:** `employeesData` (starts around line 118979)
*   **Data Type:** `Array<Object>`
*   **Dashboard Feature:** Overview tab leaderboard, Employee Detail Panel, Management Hierarchy view, Cosmo audits, Gifting queue.
*   **Target Supabase Table:** `public.profiles`
*   **Relationships:** Self-referential `manager_id` (hierarchy)
*   **Data Classification:** Raw Data + Calculated Fields (e.g. `inactiveDays`, `grade`, `health` are hardcoded in mock data but must be calculated in database)
*   **Action Plan:** **Seed data** (for profile name, email, role, manager_id, avatar_url). Calculated fields will be driven by SQL views/aggregates.

---

### 1.3. Active Customers (`customersData`)
*   **File Name:** `main-dashboard-v34.js`
*   **Folder Path:** `/dashboard/`
*   **Variable Name:** `customersData` (starts around line 144570)
*   **Data Type:** `Array<Object>`
*   **Dashboard Feature:** Customers Tab listing, Client Detail Side Panel, relationship health indicators, Cosmo audits.
*   **Target Supabase Table:** `public.organizations` (for organization metadata) + `public.contacts` (individual clients assigned to reps)
*   **Relationships:** `contacts.org_id` -> `organizations.id`, `contacts.assigned_rep_id` -> `profiles.id`
*   **Data Classification:** Raw Data + Calculated Fields (e.g. `inactiveDays`, `health`, `grade` must be computed)
*   **Action Plan:** **Seed data** (insert organizations, insert contacts with assigned reps). Calculated metrics will be computed dynamically from the `activities` history.

---

### 1.4. Active Prospects (`prospectsData`)
*   **File Name:** `main-dashboard-v34.js`
*   **Folder Path:** `/dashboard/`
*   **Variable Name:** `prospectsData` (starts around line 144570)
*   **Data Type:** `Array<Object>`
*   **Dashboard Feature:** Prospects Tab listing, Client Detail Side Panel, Cosmo audits.
*   **Target Supabase Table:** `public.organizations` (category = 'prospect') + `public.contacts`
*   **Relationships:** `contacts.org_id` -> `organizations.id`, `contacts.assigned_rep_id` -> `profiles.id`
*   **Data Classification:** Raw Data + Calculated Fields (e.g. `inactiveDays`, `health`, `grade` must be computed)
*   **Action Plan:** **Seed data** (insert organization with category = 'prospect', insert contact with assigned reps).

---

### 1.5. CRM Activity History & Touchpoints (`clientGraphData`)
*   **File Name:** `main-dashboard-v34.js`
*   **Folder Path:** `/dashboard/`
*   **Variable Name:** `clientGraphData` (starts around line 55872)
*   **Data Type:** `Object<String, Array<Object>>` (keyed by Client Name)
*   **Dashboard Feature:** Client Detail Panel Timeline, Chart sparklines, relationship health calculation, neglected status checks.
*   **Target Supabase Table:** `public.activities`
*   **Relationships:** `activities.contact_id` -> `contacts.id`, `activities.rep_id` -> `profiles.id`
*   **Data Classification:** Raw data
*   **Action Plan:** **Seed data** (insert a complete set of chronological activity logs to recreate the mock dashboard timeline and health score outputs).

---

### 1.6. Gifting Dispatch Schedule (`giftingDispatchSchedule`)
*   **File Name:** `main-dashboard-v34.js`
*   **Folder Path:** `/dashboard/`
*   **Variable Name:** `giftingDispatchSchedule` (starts around line 76722)
*   **Data Type:** `Array<Object>`
*   **Dashboard Feature:** Gifting Tab queue, Calendar events, active order metrics, KPI spent card.
*   **Target Supabase Table:** `public.gifts` (linked to `public.boxes` for boxes catalog mapping)
*   **Relationships:** `gifts.contact_id` -> `contacts.id`, `gifts.rep_id` -> `profiles.id`, `gifts.box_id` -> `boxes.id`
*   **Data Classification:** Raw data
*   **Action Plan:** **Seed data** (insert historical confections gifts and pending queue gifts to match dashboard displays).

---

### 1.7. Active B2B Orders (`activeB2BOrders`)
*   **File Name:** `main-dashboard-v34.js`
*   **Folder Path:** `/dashboard/`
*   **Variable Name:** `activeB2BOrders` (starts around line 77075)
*   **Data Type:** `Array<Object>`
*   **Dashboard Feature:** Multi-step gifting approval flow, quote ready cards, awaiting design cards.
*   **Target Supabase Table:** `public.gifts` (mapped via `status` column)
*   **Relationships:** `gifts.contact_id` -> `contacts.id`, `gifts.rep_id` -> `profiles.id`, `gifts.box_id` -> `boxes.id`
*   **Data Classification:** Raw data
*   **Action Plan:** **Seed data** (insert records with status = 'awaiting_approval', 'awaiting_design', 'quote_ready').

---

### 1.8. Calendar Events (`calendarEventsDB` & `executiveCalendarEvents`)
*   **File Name:** `main-dashboard-v34.js`
*   **Folder Path:** `/dashboard/`
*   **Variable Name:** `calendarEventsDB` (line 116195) and `executiveCalendarEvents` (line 201331)
*   **Data Type:** `Object` (calendarEventsDB) and `Array<Object>` (executiveCalendarEvents)
*   **Dashboard Feature:** Gifting Calendar panel, scheduled/dispatched event dots, agenda detail view.
*   **Target Supabase Table:** `public.calendar_events`
*   **Relationships:** `calendar_events.profile_id` -> `profiles.id`
*   **Data Classification:** Raw data
*   **Action Plan:** **Seed data** (insert calendar event records associated with the seeded manager/executive profiles).

---

### 1.9. Cosmo AI Audits (`activeAuditsDB` & Inline HTML)
*   **File Name:** `main-dashboard-v34.js` / `index.html`
*   **Folder Path:** `/dashboard/`
*   **Variable Name:** `activeAuditsDB` (line 227125) / Inline HTML lists (lines 145-270)
*   **Data Type:** `Object` (activeAuditsDB) / Static HTML strings
*   **Dashboard Feature:** Overview tab COSMO Audit cards, audit narrative detail panel.
*   **Target Supabase Table:** `public.cosmo_audits`
*   **Relationships:** `cosmo_audits.contact_id` -> `contacts.id`
*   **Data Classification:** Raw data
*   **Action Plan:** **Seed data** (insert default audits matching the mock reports).

---

### 1.10. Recovery Board Default Clients (`recoveryBoardClients`)
*   **File Name:** `main-dashboard-v34.js`
*   **Folder Path:** `/dashboard/`
*   **Variable Name:** `window.recoveryBoardClients` (line 143242)
*   **Data Type:** `Array<String>`
*   **Dashboard Feature:** Fumble Recovery tab queue, recovery board badge counts, claim request buttons.
*   **Target Supabase Table:** `public.recovery_requests`
*   **Relationships:** `recovery_requests.contact_id` -> `contacts.id`
*   **Data Classification:** Raw data
*   **Action Plan:** **Seed data** (insert recovery requests with status = 'pending' to populate the queue).

---

### 1.11. Executive Nudges / Operational Warnings (`executiveNudges`)
*   **File Name:** `main-dashboard-v34.js`
*   **Folder Path:** `/dashboard/`
*   **Variable Name:** `executiveNudges` (line 201459)
*   **Data Type:** `Array<Object>`
*   **Dashboard Feature:** Executive/Owner calendar view, critical/warning banner cards.
*   **Target Supabase Table:** `public.nudges`
*   **Relationships:** `nudges.profile_id` -> `profiles.id`
*   **Data Classification:** Raw data
*   **Action Plan:** **Seed data** (insert warning/critical nudges mapped to the owner/executive profiles).

---

### 1.12. Executive Activity History (`executiveActivityHistory`)
*   **File Name:** `main-dashboard-v34.js`
*   **Folder Path:** `/dashboard/`
*   **Variable Name:** `executiveActivityHistory` (line 201571)
*   **Data Type:** `Array<Object>` (17 manual + 125 dynamic filler entries)
*   **Dashboard Feature:** Owner/Executive Activity panel log history.
*   **Target Supabase Table:** `public.activities`
*   **Relationships:** `activities.rep_id` -> `profiles.id` (associated with Gregory Sterling/Sarah Lansky/Paul K.)
*   **Data Classification:** Raw data (17 records) + calculated/synthesized (125 records)
*   **Action Plan:** **Seed data** for the 17 manual records. Eliminate the 125 Math.sin() generated filler entries in production, as they will be replaced by real timeline logs.

---

### 1.13. Live Activity Feed (`liveActivityFeed`)
*   **File Name:** `main-dashboard-v34.js`
*   **Folder Path:** `/dashboard/`
*   **Variable Name:** `liveActivityFeed` (line 159057)
*   **Data Type:** `Array<Object>`
*   **Dashboard Feature:** Sidebar real-time activity ticker.
*   **Target Supabase Table:** `public.activities` (queried chronologically)
*   **Relationships:** `activities.contact_id` -> `contacts.id`
*   **Data Classification:** Raw data
*   **Action Plan:** **SQL View or direct query** selecting the 8 most recent entries from the `activities` table.

---

## 2. Calculated / Derived Logic Inventory

### 2.1. Leaderboard Data Sets (`leaderboardData` & `employeesLeaderboardDataSets`)
*   **File Name:** `main-dashboard-v34.js`
*   **Folder Path:** `/dashboard/`
*   **Variable Name:** `leaderboardData` (line 112650) & `employeesLeaderboardDataSets` (line 158449)
*   **Calculated Logic:** Rank matching, performance index, active client/prospect counting, total gifts sent.
*   **Target SQL View:** `public.leaderboard_live` (which aggregates `profiles`, `activities`, and `gifts`)
*   **Action Plan:** **SQL View logic** mapping inputs dynamically from the database using Postgres window functions (`ROW_NUMBER() OVER`).

---

### 2.2. Inactivity Decayed Health & Warnings (`getInactivityStatus()`)
*   **File Name:** `main-dashboard-v34.js`
*   **Folder Path:** `/dashboard/`
*   **Variable Name:** `getInactivityStatus()` (line 121418)
*   **Calculated Logic:** Compares contact's last activity date to current date. Categorizes green (<30), orange (>=30), red (>=60) based on settings. Decays health score by multiplying factor * elapsed days past warning.
*   **Target SQL View:** `public.contacts_decay_status`
*   **Action Plan:** **SQL View logic** joining `contacts`, `activities`, and `workspace_settings` to calculate active days, status flag, and health decay.

---

### 2.3. Conversion Funnel Data
*   **File Name:** `main-dashboard-v34.js`
*   **Folder Path:** `/dashboard/`
*   **Variable Name:** `analyticsDataSets[range].funnel` (line 156609+)
*   **Calculated Logic:** Counts steps: Contacts in Prospect stage -> Contact with 'Meeting' activity -> Contact with 'Proposal' activity -> Contact with 'Customer' org category.
*   **Target SQL View/RPC:** `public.get_conversion_funnel(timeframe_days)`
*   **Action Plan:** **RPC function** that returns aggregated counts for each stage in the funnel based on real `activities` and `organizations` data.

---

### 2.4. Spend Ledger Balancing & Dynamic Filler
*   **File Name:** `spend-ledger-modal.js`
*   **Folder Path:** `/dashboard/`
*   **Variable Name:** N/A (Embedded filler generator)
*   **Calculated Logic:** Scrapes the total spend KPI and generated fake rows using variance `[-15, 5, 20, -10, -5, 10, -5]` to sum up exactly to the KPI total.
*   **Target SQL View/RPC:** Real queries on `public.gifts` table
*   **Action Plan:** **Eliminate filler arrays entirely.** The modal will render real rows directly from a select query on the `gifts` table, summing their `amount` columns for the outlay count. No mock balance arrays will be seeded.
