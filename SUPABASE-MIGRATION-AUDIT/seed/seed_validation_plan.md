# WhiteBox RMOS Dashboard - Seed Validation Plan

This document outlines the testing and verification plan to guarantee that the seeded Supabase database replicates the mock dashboard metrics, calculations, role filters, and UI behaviors.

---

## 1. Automated Database Verification Queries

Before testing frontend behavior, run the following validation SQL queries to verify relationship counts, data integrity, and settings limits:

### 1.1. Validate Row Counts & Totals
Ensure the seeded tables match the inventory checklist exactly:

```sql
SELECT 'workspaces' AS table_name, COUNT(*) FROM public.workspaces
UNION ALL
SELECT 'profiles' AS table_name, COUNT(*) FROM public.profiles
UNION ALL
SELECT 'organizations' AS table_name, COUNT(*) FROM public.organizations
UNION ALL
SELECT 'contacts' AS table_name, COUNT(*) FROM public.contacts
UNION ALL
SELECT 'activities' AS table_name, COUNT(*) FROM public.activities
UNION ALL
SELECT 'boxes' AS table_name, COUNT(*) FROM public.boxes
UNION ALL
SELECT 'gifts' AS table_name, COUNT(*) FROM public.gifts;
```
*Expected Outputs:*
*   `workspaces`: 1
*   `profiles`: 12
*   `organizations`: 21
*   `contacts`: 21
*   `boxes`: 3
*   `gifts`: 8 (non-finalized) + 6 (delivered/finalized) = 14 total seeded gifts.

### 1.2. Validate Gifting Outlay & Totals
Ensure spend outlay matches the mock layout:

```sql
SELECT 
    COUNT(*) AS gifts_sent_count,
    SUM(amount) AS total_spend_outlay
FROM public.gifts
WHERE status = 'delivered';
```
*Expected Outputs:*
*   `gifts_sent_count`: 6 (Note: In the mock dashboard, the Owner KPI shows 142. For testing, we verify that our query correctly counts the seeded rows. If the UI still requires 142 total for visual decoration, the UI-side ledger mock rows will backfill the rest. Once Supabase is fully connected, the KPI cards will read the true count, e.g. 6).

### 1.3. Validate Inactivity Decay Calculations
Check that the dynamic health decay view matches the mock thresholds (30/60 days):

```sql
SELECT name, inactive_days, computed_health, computed_status
FROM public.contacts_decay_status
WHERE name IN ('Vanguard Admin', 'Chevron Logistics CS', 'Pepper Potts');
```
*Expected Outputs:*
*   `Vanguard Admin`: ~84 days inactive, computed health `38%` (capped base), status `neglected`.
*   `Chevron Logistics CS`: ~42 days inactive, decayed health `72%`, status `inactive`.
*   `Pepper Potts`: ~0 days inactive, health `98%`, status `active`.

---

## 2. Role-Based Permissions & Filtering Checks

To verify Row Level Security (RLS) policies, simulate logins for each role category and query the `contacts` list:

### 2.1. Test Owner / Executive Permissions
Simulate `owner@whitebox.com` or `executive@whitebox.com` login session (`auth.uid() = 8b1933c0-0f0e-4361-b472-3c8cfa2b9801`):
*   **Action:** Query `SELECT * FROM public.contacts`.
*   **Verification:** Returns all 21 contact records across the entire workspace.

### 2.2. Test Manager Permissions
Simulate `manager@whitebox.com` (Marcus Dupond, `auth.uid() = 8b1933c0-0f0e-4361-b472-3c8cfa2b9805`):
*   **Action:** Query `SELECT * FROM public.contacts`.
*   **Verification:** Returns only contacts assigned to Marcus Dupond OR his direct reports (Tom Collins, Dwight Schrute, John Doe). Should NOT return contacts assigned to Alice Cooper or Bob Martin (managed by Emily Davis).

### 2.3. Test Rep Permissions
Simulate `rep@whitebox.com` (Tom Collins, `auth.uid() = 8b1933c0-0f0e-4361-b472-3c8cfa2b9807`):
*   **Action:** Query `SELECT * FROM public.contacts`.
*   **Verification:** Returns only contacts assigned directly to Tom Collins OR contacts in the Open Fumble Pool (Vanguard Admin, which is >= 75 days inactive). Should NOT return Initech Software (Dwight) or Wayne Enterprises.

---

## 3. Frontend Behavior Alignment Checklist

Once Supabase client connectivity is enabled, verify the following visual behaviors in the dashboard HUD:

| Checkpoint | Target UI Component | Verification Step | Expected Visual State |
| :--- | :--- | :--- | :--- |
| **3.1. Auth State** | Sidebar Navigation / Header | Log in as Tom Collins. | Leaderboard and Settings tabs disappear; header display updates to "Tom Collins". |
| **3.2. KPI Spend** | Gifting KPI Summary Cards | Observe Overview KPI cards. | Spend counts align with database aggregates (Reps see their own $1,654 outlay; Owner sees full $4,850). |
| **3.3. Recovery Board** | Fumble Recovery Tab | Open Recovery Queue board. | "Vanguard Health" appears in the claimable list with status "pending". |
| **3.4. Cosmo Alerts** | Jarvis AI Sidebar | Open Jarvis AI pane. | Displays three warning narrative cards matching seeded `cosmo_audits`. |
| **3.5. Calendar Event** | Gifting Calendar Grid | Load Calendar tab. | Scheduled send dots appear on June 5 and June 15 matching the seeded timeline. |
| **3.6. Gifting Gate** | Gifting Tab Queue | Log in as Representative, submit new gift. | Status is forced to `pending`. Gifting Gate check blocks status upgrades to `approved` without Owner role. |
