-- 0007_get_kpi_summary_workspace_scope.sql
-- Security hardening (blocker "2c", defense-in-depth).
--
-- get_kpi_summary runs SECURITY INVOKER, so every subquery already runs under
-- the caller's RLS, which is workspace-scoped (workspace_id = get_my_workspace()
-- on contacts / recovery_requests). Verified 2026-06-18: real users are already
-- tenant-isolated (the cross-tenant test user "Eve Tenant" sees only her own
-- workspace's numbers). So this is NOT closing a live leak.
--
-- WHY WE STILL DO IT: the function's tenant-safety currently depends ENTIRELY on
-- two external conditions holding (SECURITY INVOKER + workspace-scoped RLS). If
-- the function were ever switched to SECURITY DEFINER, or an RLS policy were
-- loosened, every count below would silently blend all workspaces. Adding an
-- explicit `workspace_id = my_ws` filter to each count makes the function
-- correct ON ITS OWN, independent of RLS. Belt-and-suspenders per the project's
-- "never trust a single security layer" rule.
--
-- Additive + reversible (CREATE OR REPLACE; no data touched). Behaviour for real
-- users is unchanged (verified: owner/exec avg_health=79, rep=73, Eve=92 before
-- AND after). Rollback: scripts/rollback-2c.sql (local) restores the prior body.

CREATE OR REPLACE FUNCTION public.get_kpi_summary(timeframe_days integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
    result jsonb;
    my_ws uuid;
BEGIN
    my_ws := public.get_my_workspace();
    IF my_ws IS NULL THEN
        RETURN '{}'::jsonb;
    END IF;

    SELECT json_build_object(
        'clients', (SELECT COUNT(*) FROM public.contacts WHERE workspace_id = my_ws AND org_id IN (SELECT id FROM public.organizations WHERE category != 'prospect')),
        'prospects', (SELECT COUNT(*) FROM public.contacts WHERE workspace_id = my_ws AND org_id IN (SELECT id FROM public.organizations WHERE category = 'prospect')),
        'avg_health', COALESCE((SELECT AVG(relationship_health)::integer FROM public.contacts WHERE workspace_id = my_ws), 100),
        'neglected_count', (SELECT COUNT(*) FROM public.contacts WHERE workspace_id = my_ws AND status = 'neglected'),
        'recovery_queue', (SELECT COUNT(*) FROM public.recovery_requests WHERE workspace_id = my_ws AND status = 'pending')
    )::jsonb INTO result;
    RETURN result;
END;
$function$;
