-- ============================================================
-- CALCULATED VIEWS, FUNCTION FORMULAS & KPI ENGINES
-- ============================================================

-- 1. Live Leaderboard View (Aggregated Touchpoints & Stats)
CREATE OR REPLACE VIEW public.leaderboard_live AS
SELECT
    p.id,
    p.name,
    p.role,
    COUNT(DISTINCT a.id) AS touchpoints,
    COUNT(DISTINCT CASE WHEN c.status = 'active' AND o.category != 'prospect' THEN c.id END) AS clients,
    COUNT(DISTINCT CASE WHEN o.category = 'prospect' THEN c.id END) AS prospects,
    COALESCE(AVG(c.relationship_health), 100) AS avg_health,
    COUNT(DISTINCT g.id) AS gifts_sent
FROM public.profiles p
LEFT JOIN public.activities a ON a.rep_id = p.id AND a.logged_at > NOW() - INTERVAL '7 days'
LEFT JOIN public.contacts c ON c.assigned_rep_id = p.id
LEFT JOIN public.organizations o ON o.id = c.org_id
LEFT JOIN public.gifts g ON g.rep_id = p.id AND g.status = 'delivered'
WHERE p.workspace_id = public.get_my_workspace()
GROUP BY p.id, p.name, p.role
ORDER BY touchpoints DESC;

-- 2. Neglected Accounts Tracker
-- Identifies contacts who have been inactive longer than the critical decay setting
CREATE OR REPLACE FUNCTION public.get_neglected_contacts(threshold_days integer DEFAULT 60)
RETURNS SETOF public.contacts AS $$
    SELECT c.*
    FROM public.contacts c
    LEFT JOIN LATERAL (
        SELECT MAX(logged_at) AS last_activity
        FROM public.activities
        WHERE contact_id = c.id
    ) la ON true
    WHERE c.workspace_id = public.get_my_workspace()
    AND (la.last_activity IS NULL OR la.last_activity < NOW() - (threshold_days || ' days')::interval);
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- 3. Dynamic Health Decay Calculator
-- Computes decay based on elapsed days since last touchpoint activity
CREATE OR REPLACE VIEW public.contacts_decay_status AS
SELECT 
    c.id AS contact_id,
    c.name AS contact_name,
    c.workspace_id,
    COALESCE(DATE_PART('day', now() - la.last_activity), 999) AS inactive_days,
    GREATEST(0, LEAST(100, 
        CASE 
            WHEN la.last_activity IS NULL THEN 0
            -- Health decays linearly after 30 days of inactivity
            WHEN DATE_PART('day', now() - la.last_activity) <= 30 THEN 100
            ELSE 100 - ((DATE_PART('day', now() - la.last_activity) - 30) * 1.5)
        END
    ))::integer AS computed_health
FROM public.contacts c
LEFT JOIN LATERAL (
    SELECT MAX(logged_at) AS last_activity
    FROM public.activities
    WHERE contact_id = c.id
) la ON true
WHERE c.workspace_id = public.get_my_workspace();
