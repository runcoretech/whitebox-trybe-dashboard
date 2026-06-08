-- ============================================================================
-- MIGRATION: 0005_post_phase4_fixes
-- Description: Applies Phase 4 fixes including role privileges, updated_at trigger, 
-- get_kpi_summary return fix, workspace renaming, and seed cleanup.
-- ============================================================================

BEGIN;

-- 1. Grant proper privileges to authenticated and anon roles
-- Grant SELECT, INSERT, UPDATE, DELETE on all public tables to authenticated
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;

-- Keep anon locked down: revoke SELECT on all tables first, then only grant to public-safe tables
REVOKE SELECT ON ALL TABLES IN SCHEMA public FROM anon;
GRANT SELECT ON public.workspaces TO anon;
GRANT SELECT ON public.boxes TO anon;

-- Grant usage and select on all sequences to authenticated, and revoke from anon
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;
REVOKE SELECT ON ALL SEQUENCES IN SCHEMA public FROM anon;

-- Alter default privileges for future objects (only granting to authenticated, not anon)
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE SELECT ON TABLES FROM anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE SELECT ON SEQUENCES FROM anon;

-- 2. Add automatic updated_at trigger on recovery_requests
CREATE OR REPLACE FUNCTION public.set_current_timestamp_updated_at()
RETURNS trigger AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_recovery_requests_updated_at ON public.recovery_requests;
CREATE TRIGGER trg_recovery_requests_updated_at
    BEFORE UPDATE ON public.recovery_requests
    FOR EACH ROW EXECUTE FUNCTION public.set_current_timestamp_updated_at();

-- 3. Fix get_kpi_summary RPC return path missing return statement
CREATE OR REPLACE FUNCTION public.get_kpi_summary(timeframe_days integer)
RETURNS jsonb AS $$
DECLARE
    result jsonb;
    my_ws uuid;
BEGIN
    my_ws := public.get_my_workspace();
    IF my_ws IS NULL THEN
        RETURN '{}'::jsonb;
    END IF;

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

-- 4. Align gift workflow status: change any awaiting_approval gifts to pending
UPDATE public.gifts SET status = 'pending' WHERE status = 'awaiting_approval';

-- 5. Rename Workspace 1 from WhiteBox Headquarters to WhiteBox Giftworks
UPDATE public.workspaces SET name = 'WhiteBox Giftworks' WHERE id = 'd9b0a1a0-0000-0000-0000-000000000001';

-- 6. Clean duplicate Phase 4 audit log and set deterministic created_at
DELETE FROM public.audit_logs WHERE id = 'f11933c0-0f0e-4361-b472-3c8cfa2b9801';
INSERT INTO public.audit_logs (id, workspace_id, actor_id, actor_name, role, action, entity_type, entity_id, new_values, created_at)
VALUES
    ('f11933c0-0f0e-4361-b472-3c8cfa2b9801', 'd9b0a1a0-0000-0000-0000-000000000001', '8b1933c0-0f0e-4361-b472-3c8cfa2b9801', 'Paul K.', 'owner'::public.user_role, 'SEED_DEVELOPMENT_ENVIRONMENT', 'workspace', 'd9b0a1a0-0000-0000-0000-000000000001', '{"description": "Initial development preset database seeding."}'::jsonb, '2026-06-08 12:00:00+00'::timestamp with time zone)
ON CONFLICT (id, created_at) DO NOTHING;

COMMIT;
