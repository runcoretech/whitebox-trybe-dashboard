# WhiteBox RMOS Dashboard - Analytics Mapping Plan

This document details how each dashboard KPI metric, chart, sparkline, and reporting ledger is calculated from mock data today, and how it will be powered by Supabase SQL views, stored procedures (RPCs), or frontend calculations.

---

## 1. Analytics & KPI Calculations Mapping Matrix

| Metric / Card | Mock Source Variable | Current Calculation Logic | Supabase Power Source |
| :--- | :--- | :--- | :--- |
| **Relationship Health** | `customersData[i].health` | Hardcoded value on each customer/prospect object (e.g. 96%, 62%). | **SQL View:** `public.contacts_decay_status` computes dynamic health decay based on settings thresholds and date of last logged activity. |
| **Company Health** (Avg Index) | `analyticsDataSets[range].health` | Static number per timeframe (e.g. 91% for 'live'). | **RPC Function:** `public.get_kpi_summary()` aggregates the decayed health scores of all active contacts in the workspace. |
| **Customer / Prospect Health** | `customersData`/`prospectsData` | Static health rings based on hardcoded grades (A = 98%, C = 74%, F = 38%). | **SQL View:** Evaluates relationship quality by averaging touchpoint grades (A=100, B=80, C=60, D=40, F=0) over the last 90 days. |
| **Touchpoint Counts** | `employeesData[i].touchpoints` | Hardcoded total count per employee (e.g. 31). | **SQL View / Direct Query:** `SELECT COUNT(*) FROM public.activities WHERE contact_id = ID` (or `rep_id = ID`). |
| **Last Touchpoint Date** | `employeesData[i].inactiveDays` | Hardcoded inactive days count. | **SQL View:** `SELECT MAX(logged_at) FROM public.activities WHERE contact_id = ID` (days elapsed is calculated via date subtraction). |
| **Neglected Account Counts** | `recoveryQueue` filter (Line 121045) | Filter on `inactiveDays >= 60`. | **RPC Function:** Counts contacts where `NOW() - last_activity >= workspace_settings.decay_critical` and status != 'recovery'. |
| **Fumble / Recovery Counts** | `recoveryBoardClients.length` | Hardcoded array length (starts at 2). | **Direct Query / RLS Count:** `SELECT COUNT(*) FROM public.recovery_requests WHERE status = 'pending'`. |
| **Active Gifts Queued** | `activeB2BOrders.length` | Count of incomplete multi-step order objects. | **Direct Query:** `SELECT COUNT(*) FROM public.gifts WHERE status NOT IN ('dispatched', 'delivered', 'failed', 'rejected')`. |
| **Total Gifts Sent** | KPI card `.kpi-gifts-sent-count` | Hardcoded in HTML (142 for Owner, 23 for Rep). | **RPC Function:** `SELECT COUNT(*) FROM public.gifts WHERE status = 'delivered'`. |
| **Gifts by Type** | `giftingDispatchSchedule` | Counts specific box types in array. | **Direct Query:** `SELECT box_id, COUNT(*) FROM public.gifts WHERE status = 'delivered' GROUP BY box_id`. |
| **Gifts by Purpose** | `giftingDispatchSchedule` | Counts category values (`reach`, `retain`, etc.) in schedule array. | **Direct Query:** `SELECT category, COUNT(*) FROM public.gifts GROUP BY category`. |
| **Gifts by Sender** | `giftingDispatchSchedule` | Scrapes sender labels. | **Direct Query:** `SELECT rep_id, COUNT(*) FROM public.gifts WHERE status = 'delivered' GROUP BY rep_id`. |
| **Gifts by Recipient** | `giftingDispatchSchedule` | Scrapes recipient client strings. | **Direct Query:** `SELECT contact_id, COUNT(*) FROM public.gifts WHERE status = 'delivered' GROUP BY contact_id`. |
| **Gift Spend / Outlay** | KPI card `.kpi-gifts-spend-value` | Hardcoded in HTML ($4,850.00 for Owner, $1,654.00 for Rep). | **RPC Function:** `SELECT SUM(amount) FROM public.gifts WHERE status = 'delivered'`. |
| **Conversion Rate** | `analyticsDataSets[range].conversion` | Hardcoded values per range (e.g. 34% for live). | **SQL View / RPC:** Computed as `(converted_customers_count / total_contacts_count) * 100` within the active timeframe. |
| **Leaderboard Rankings** | `leaderboardData` & `employeesLeaderboard` | Hardcoded rankings grouped by weeks/months/quarters. | **SQL View:** `public.leaderboard_live` uses `ROW_NUMBER() OVER` to rank reps based on touchpoint grades, conversion success, and client health. |
| **Employee Activity** | `employeeSectorTimeframeData` | Hardcoded charts grouped by industry sector and range. | **SQL View:** Groups `activities` records by `rep_id`, org sector, and date intervals. |
| **Ecosystem Analytics** | Static cards in Executive HUD | Marketing showcase values. | **RPC Function:** Computes overall touchpoint-to-conversion velocities across the entire workspace directory. |
| **Calendar Counts** | `calendarEventsDB` | Counts event objects nested inside client keys. | **Direct Query:** `SELECT COUNT(*) FROM public.calendar_events WHERE profile_id = ID`. |
| **Nudge Counts** | `executiveNudges` | Hardcoded array length. | **Direct Query:** `SELECT COUNT(*) FROM public.nudges WHERE profile_id = ID AND is_read = false`. |
| **Cosmo Audit Outputs** | Hardcoded cards in HTML | Pre-baked card templates. | **Direct Query:** `SELECT * FROM public.cosmo_audits WHERE workspace_id = WS_ID`. |
| **Graph / Chart Values** | `analyticsDataSets[range].healthTrend` | Hardcoded numeric arrays (e.g. `[89, 90, 90, 91]`). | **Frontend Rendering (Data from SQL View):** SQL View aggregates touchpoint frequencies and health indexes by day/week intervals, returned to frontend to draw SVG paths. |

---

## 2. Technical Implementation Blueprints

### 2.1. Dynamic Inactivity-Based Health Decay View (`public.contacts_decay_status`)
This view replaces the static client lists by dynamically calculating the active status and decay percentage based on workspace thresholds:

```sql
CREATE OR REPLACE VIEW public.contacts_decay_status AS
WITH last_activities AS (
    SELECT 
        contact_id, 
        MAX(logged_at) AS last_activity_date,
        COALESCE(DATE_PART('day', now() - MAX(logged_at)), 999) AS inactive_days
    FROM public.activities
    GROUP BY contact_id
)
SELECT 
    c.id AS contact_id,
    c.name,
    c.workspace_id,
    c.assigned_rep_id,
    COALESCE(la.inactive_days, 999) AS inactive_days,
    ws.decay_warning,
    ws.decay_critical,
    ws.decay_factor,
    -- Calculate decayed health
    GREATEST(0, LEAST(100,
        CASE
            WHEN la.last_activity_date IS NULL THEN 0
            WHEN la.inactive_days <= ws.decay_warning THEN c.relationship_health
            ELSE c.relationship_health - ((la.inactive_days - ws.decay_warning) * ws.decay_factor)
        END
    ))::integer AS computed_health,
    -- Determine status tag
    CASE
        WHEN la.last_activity_date IS NULL OR la.inactive_days >= ws.decay_critical THEN 'neglected'
        WHEN la.inactive_days >= ws.decay_warning THEN 'inactive'
        ELSE 'active'
    END::text AS computed_status
FROM public.contacts c
JOIN public.workspace_settings ws ON c.workspace_id = ws.workspace_id
LEFT JOIN last_activities la ON c.id = la.contact_id;
```

### 2.2. Conversion Funnel RPC (`public.get_conversion_funnel`)
Aggregates active sales velocity stages. Scopes queries automatically based on RLS:

```sql
CREATE OR REPLACE FUNCTION public.get_conversion_funnel(range_days integer)
RETURNS jsonb AS $$
DECLARE
    prospect_count integer;
    meeting_count integer;
    proposal_count integer;
    customer_count integer;
    cutoff_date timestamp with time zone;
BEGIN
    cutoff_date := now() - (range_days || ' days')::interval;

    -- Stage 1: Active Prospects
    SELECT COUNT(DISTINCT c.id) INTO prospect_count
    FROM public.contacts c
    JOIN public.organizations o ON c.org_id = o.id
    WHERE o.category = 'prospect'
      AND c.created_at >= cutoff_date;

    -- Stage 2: Engaged (Has had a Meeting touchpoint)
    SELECT COUNT(DISTINCT a.contact_id) INTO meeting_count
    FROM public.activities a
    WHERE a.type = 'Meeting'
      AND a.logged_at >= cutoff_date;

    -- Stage 3: Proposal Sent (Has had a Proposal/Quote activity)
    SELECT COUNT(DISTINCT a.contact_id) INTO proposal_count
    FROM public.activities a
    WHERE a.type = 'Proposal'
      AND a.logged_at >= cutoff_date;

    -- Stage 4: Converted (Organization category transitioned to smb or enterprise)
    SELECT COUNT(DISTINCT c.id) INTO customer_count
    FROM public.contacts c
    JOIN public.organizations o ON c.org_id = o.id
    WHERE o.category IN ('smb', 'enterprise')
      AND c.created_at >= cutoff_date;

    RETURN json_build_object(
        'prospects', prospect_count,
        'meetings', meeting_count,
        'proposals', proposal_count,
        'customers', customer_count
    )::jsonb;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER STABLE;
```

### 2.3. Leaderboard view (`public.leaderboard_live`)
Computes the dynamic performance ranks for reps and managers:

```sql
CREATE OR REPLACE VIEW public.leaderboard_live AS
WITH rep_stats AS (
    SELECT 
        p.id AS profile_id,
        p.name,
        p.workspace_id,
        COUNT(DISTINCT c.id) FILTER (WHERE o.category = 'prospect') AS prospects_count,
        COUNT(DISTINCT c.id) FILTER (WHERE o.category IN ('smb', 'enterprise')) AS customers_count,
        COUNT(g.id) FILTER (WHERE g.status = 'delivered') AS gifts_count,
        -- Weighted composite score: 40% customer health, 30% touchpoint volume, 30% gifts sent
        COALESCE(AVG(cds.computed_health), 100) AS avg_health,
        COUNT(a.id) AS touchpoints_count
    FROM public.profiles p
    JOIN public.organizations o ON p.workspace_id = o.workspace_id
    LEFT JOIN public.contacts c ON c.org_id = o.id AND c.assigned_rep_id = p.id
    LEFT JOIN public.contacts_decay_status cds ON c.id = cds.contact_id
    LEFT JOIN public.activities a ON a.rep_id = p.id
    LEFT JOIN public.gifts g ON g.rep_id = p.id
    WHERE p.role = 'rep'
    GROUP BY p.id, p.name, p.workspace_id
)
SELECT 
    profile_id,
    name,
    workspace_id,
    prospects_count,
    customers_count,
    gifts_count,
    touchpoints_count,
    avg_health::integer AS avg_health,
    -- Composite formula matching mock defaults
    GREATEST(0, LEAST(100, (avg_health * 0.40 + LEAST(100, touchpoints_count * 2) * 0.30 + LEAST(100, gifts_count * 5) * 0.30)))::integer AS composite_score,
    ROW_NUMBER() OVER (PARTITION BY workspace_id ORDER BY (avg_health * 0.40 + LEAST(100, touchpoints_count * 2) * 0.30 + LEAST(100, gifts_count * 5) * 0.30) DESC) AS rank
FROM rep_stats;
```
