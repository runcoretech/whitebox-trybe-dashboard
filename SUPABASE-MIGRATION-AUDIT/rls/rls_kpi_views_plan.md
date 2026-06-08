# Phase 3 RLS & KPI Views Plan
## WhiteBox RMOS Secure Analytics Views & RPC Design

This document details the architecture for secure database views, stored procedures (RPCs), and frontend filters to populate RMOS KPI cards, analytics widgets, and reporting ledgers.

---

## 1. Analytics & KPI Security Strategy

Rather than scraping DOM values or querying full tables and performing client-side reductions, the backend utilizes PostgreSQL **Views** and **Stored Procedures (RPCs)**:
*   **Automatic RLS Scoping:** All SQL Views automatically inherit the RLS policies of the underlying source tables. If a Rep queries a view (e.g., `leaderboard_live`), PostgreSQL automatically filters the profile records and activities using the caller's active session, preventing database leakage.
*   **Execution Privileges:** Complex math (such as conversion rates and average health scores) runs directly on the database server using PostgreSQL aggregates, optimizing payload sizes.

---

## 2. Secure Database Views & RPC Schema Mappings

### View 1: `public.leaderboard_live`
*   **Purpose:** Compiles touchpoints, active customers, prospects, average health, and gifts dispatched per profile in the workspace.
*   **Security Scoping:** Binds to RLS on `public.profiles`, `public.activities`, and `public.gifts`.
    *   *Rep:* Sees nothing (view returns empty dataset because RLS blocks other profiles).
    *   *Manager:* Sees rows corresponding to their direct team reports only.
    *   *Executive / Owner:* Sees full workspace leaderboards.

### View 2: `public.contacts_decay_status`
*   **Purpose:** Computes the elapsed inactivity days since the last logged touchpoint and calculates the resulting relationship health score dynamically:
    ```sql
    computed_health = GREATEST(0, LEAST(100, 
        CASE 
            WHEN last_activity IS NULL THEN 0
            WHEN inactive_days <= warning_days THEN 100
            ELSE 100 - ((inactive_days - warning_days) * factor)
        END
    ))
    ```
    Where `warning_days` and `factor` are read dynamically via a join on `public.workspace_settings`.

### View 3: `public.recovery_leaderboard`
*   **Purpose:** Displays top representatives ranked by counts of successfully claimed and rescued relationships.
*   **Security Scoping:** Selectable by all roles. Tracks public recovery metrics for competitive gamification.

---

## 3. Operations Placement Matrix

| Feature / Metric | RLS Policies | SQL Database Views | Stored Procedures (RPC) | Frontend Logic Only |
| :--- | :--- | :--- | :--- | :--- |
| **Workspace Separation** | ✅ Enforces tenant boundaries | ❌ | ❌ | ❌ |
| **Leaderboard Rows** | ✅ Restricts rows to team/self | ✅ Joins profiles & activities | ❌ | ❌ |
| **Gifts Sent & Spend Outlay** | ✅ Restricts visibility by role | ❌ | ✅ `get_gifting_kpi_summary()` (runs count/sum) | ❌ |
| **Relationship Decay Status** | ❌ | ✅ Joins settings & dates | ❌ | ❌ |
| **Cosmo AI Audit Narrative**| ✅ Scopes narrative read | ❌ | ❌ | ❌ |
| **Spend Ledger Balancing** | ❌ | ❌ | ❌ | ✅ Renders rows based on real JSON lists |
| **Leaderboard Tab Toggles** | ❌ | ❌ | ❌ | ✅ Toggles UI visibility based on profile roles |

---

## 4. Stored Procedure Blueprints (RPCs)

### `public.get_kpi_summary(timeframe_days integer)`
Returns total active customers, prospects, average health index, neglected count, and recovery queue count:
```sql
CREATE OR REPLACE FUNCTION public.get_kpi_summary(timeframe_days integer)
RETURNS jsonb AS $$
DECLARE
    result jsonb;
BEGIN
    SELECT json_build_object(
        'clients', (SELECT COUNT(*) FROM public.contacts WHERE org_id IN (SELECT id FROM public.organizations WHERE category != 'prospect')),
        'prospects', (SELECT COUNT(*) FROM public.contacts WHERE org_id IN (SELECT id FROM public.organizations WHERE category = 'prospect')),
        'avg_health', COALESCE((SELECT AVG(relationship_health)::integer FROM public.contacts), 100),
        'neglected_count', (SELECT COUNT(*) FROM public.contacts WHERE status = 'neglected'),
        'recovery_queue', (SELECT COUNT(*) FROM public.recovery_requests WHERE status = 'pending')
    )::jsonb INTO result;
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER STABLE;
```
*   **Security Note:** Declared with `SECURITY INVOKER` (the function executes with the permissions of the calling user, forcing PostgreSQL to filter count statistics via RLS). Reps only see counts for their assigned contacts.
