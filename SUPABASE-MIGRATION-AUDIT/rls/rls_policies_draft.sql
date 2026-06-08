-- ============================================================================
-- WHITEBOX RMOS ROW LEVEL SECURITY (RLS) POLICIES (PHASE 3 FINAL)
-- ============================================================================

-- Helper functions to get current context securely (Verifies Active User Status)
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS text AS $$
    SELECT role::text FROM public.profiles 
    WHERE id = auth.uid() AND status = 'active'::public.profile_status;
$$ LANGUAGE sql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION public.get_my_workspace()
RETURNS uuid AS $$
    SELECT workspace_id FROM public.profiles 
    WHERE id = auth.uid() AND status = 'active'::public.profile_status;
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Check if contact is open in Fumble Pool (dynamic settings check)
-- Resolves workspace internally to prevent parameter forgery
CREATE OR REPLACE FUNCTION public.is_contact_claimable(cid uuid)
RETURNS boolean AS $$
DECLARE
    inactive_days integer;
    critical_days integer;
    my_ws uuid;
BEGIN
    my_ws := public.get_my_workspace();

    SELECT COALESCE(DATE_PART('day', now() - MAX(logged_at)), 999) INTO inactive_days
    FROM public.activities WHERE contact_id = cid AND workspace_id = my_ws;

    SELECT decay_critical INTO critical_days
    FROM public.workspace_settings WHERE workspace_id = my_ws;

    -- Open pool triggers 15 days after critical neglect threshold (e.g., 75 days if critical=60)
    IF inactive_days >= (critical_days + 15) THEN
        RETURN true;
    END IF;
    RETURN false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- ============================================================================
-- RLS POLICIES ON TABLES
-- ============================================================================

-- 1. workspaces RLS
ALTER TABLE public.workspaces ENABLE ROW LEVEL SECURITY;

CREATE POLICY "workspaces_select" ON public.workspaces
    FOR SELECT USING (id = public.get_my_workspace());

CREATE POLICY "workspaces_owner_update" ON public.workspaces
    FOR UPDATE USING (id = public.get_my_workspace() AND public.get_my_role() = 'owner');

-- 2. profiles RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "profiles_select" ON public.profiles
    FOR SELECT USING (workspace_id = public.get_my_workspace());

CREATE POLICY "profiles_update" ON public.profiles
    FOR UPDATE USING (
        workspace_id = public.get_my_workspace()
        AND (public.get_my_role() = 'owner' OR id = auth.uid())
    );

-- 3. workspace_settings RLS
ALTER TABLE public.workspace_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "settings_select" ON public.workspace_settings
    FOR SELECT USING (workspace_id = public.get_my_workspace());

CREATE POLICY "settings_owner_all" ON public.workspace_settings
    FOR ALL USING (
        workspace_id = public.get_my_workspace() 
        AND public.get_my_role() = 'owner'
    );

-- 4. organizations RLS
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "organizations_select" ON public.organizations
    FOR SELECT USING (
        workspace_id = public.get_my_workspace()
        AND (
            public.get_my_role() IN ('owner', 'executive', 'manager')
            OR id IN (
                -- Reps can see organizations of their assigned contacts
                SELECT org_id FROM public.contacts 
                WHERE assigned_rep_id = auth.uid() AND org_id IS NOT NULL
            )
        )
    );

CREATE POLICY "organizations_manager_write" ON public.organizations
    FOR ALL USING (
        workspace_id = public.get_my_workspace()
        AND public.get_my_role() = 'manager'
    );

CREATE POLICY "organizations_owner_write" ON public.organizations
    FOR ALL USING (
        workspace_id = public.get_my_workspace()
        AND public.get_my_role() = 'owner'
    );

-- 5. contacts RLS
ALTER TABLE public.contacts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "contacts_select" ON public.contacts
    FOR SELECT USING (
        workspace_id = public.get_my_workspace()
        AND (
            public.get_my_role() IN ('owner', 'executive')
            OR (public.get_my_role() = 'manager' AND (
                assigned_rep_id = auth.uid() 
                OR assigned_rep_id IN (
                    SELECT id FROM public.profiles WHERE manager_id = auth.uid()
                )
            ))
            OR (public.get_my_role() = 'rep' AND (
                assigned_rep_id = auth.uid()
                OR public.is_contact_claimable(id) = true
            ))
        )
    );

CREATE POLICY "contacts_rep_write" ON public.contacts
    FOR ALL USING (
        workspace_id = public.get_my_workspace()
        AND assigned_rep_id = auth.uid()
        AND public.get_my_role() = 'rep'
    );

CREATE POLICY "contacts_manager_write" ON public.contacts
    FOR ALL USING (
        workspace_id = public.get_my_workspace()
        AND (
            assigned_rep_id = auth.uid() 
            OR assigned_rep_id IN (
                SELECT id FROM public.profiles WHERE manager_id = auth.uid()
            )
        )
        AND public.get_my_role() = 'manager'
    );

CREATE POLICY "contacts_owner_write" ON public.contacts
    FOR ALL USING (
        workspace_id = public.get_my_workspace()
        AND public.get_my_role() = 'owner'
    );

-- 6. activities RLS
ALTER TABLE public.activities ENABLE ROW LEVEL SECURITY;

CREATE POLICY "activities_select" ON public.activities
    FOR SELECT USING (
        workspace_id = public.get_my_workspace()
        AND (
            public.get_my_role() IN ('owner', 'executive')
            OR (public.get_my_role() = 'manager' AND (
                rep_id = auth.uid() 
                OR rep_id IN (
                    SELECT id FROM public.profiles WHERE manager_id = auth.uid()
                )
            ))
            OR (public.get_my_role() = 'rep' AND rep_id = auth.uid())
        )
    );

CREATE POLICY "activities_insert" ON public.activities
    FOR INSERT WITH CHECK (
        workspace_id = public.get_my_workspace()
        AND rep_id = auth.uid()
    );

CREATE POLICY "activities_owner_all" ON public.activities
    FOR ALL USING (
        workspace_id = public.get_my_workspace()
        AND public.get_my_role() = 'owner'
    );

-- 7. boxes RLS
ALTER TABLE public.boxes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "boxes_select" ON public.boxes
    FOR SELECT USING (workspace_id = public.get_my_workspace());

CREATE POLICY "boxes_owner_all" ON public.boxes
    FOR ALL USING (
        workspace_id = public.get_my_workspace()
        AND public.get_my_role() = 'owner'
    );

-- 8. gifts RLS
ALTER TABLE public.gifts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "gifts_select" ON public.gifts
    FOR SELECT USING (
        workspace_id = public.get_my_workspace()
        AND (
            public.get_my_role() IN ('owner', 'executive')
            OR (public.get_my_role() = 'manager' AND (
                rep_id = auth.uid() 
                OR rep_id IN (
                    SELECT id FROM public.profiles WHERE manager_id = auth.uid()
                )
            ))
            OR (public.get_my_role() = 'rep' AND rep_id = auth.uid())
        )
    );

CREATE POLICY "gifts_rep_insert" ON public.gifts
    FOR INSERT WITH CHECK (
        workspace_id = public.get_my_workspace()
        AND rep_id = auth.uid()
        AND status = 'pending'::public.gift_status
    );

CREATE POLICY "gifts_rep_update" ON public.gifts
    FOR UPDATE USING (
        workspace_id = public.get_my_workspace()
        AND rep_id = auth.uid()
        AND status = 'pending'::public.gift_status
    ) WITH CHECK (
        status = 'pending'::public.gift_status
    );

CREATE POLICY "gifts_manager_write" ON public.gifts
    FOR ALL USING (
        workspace_id = public.get_my_workspace()
        AND (
            rep_id = auth.uid()
            OR rep_id IN (
                SELECT id FROM public.profiles WHERE manager_id = auth.uid()
            )
        )
        AND public.get_my_role() = 'manager'
    ) WITH CHECK (
        -- Protect status changes from managers unless override is active
        (status = OLD.status) OR (
            status IN ('approved'::public.gift_status, 'rejected'::public.gift_status)
            AND (
                SELECT manager_override FROM public.workspace_settings WHERE workspace_id = OLD.workspace_id
            )
        )
    );

CREATE POLICY "gifts_owner_all" ON public.gifts
    FOR ALL USING (
        workspace_id = public.get_my_workspace()
        AND public.get_my_role() = 'owner'
    );

-- 9. calendar_events RLS
ALTER TABLE public.calendar_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "calendar_select" ON public.calendar_events
    FOR SELECT USING (
        workspace_id = public.get_my_workspace()
        AND (
            public.get_my_role() IN ('owner', 'executive')
            OR (public.get_my_role() = 'manager' AND (
                profile_id = auth.uid()
                OR profile_id IN (
                    SELECT id FROM public.profiles WHERE manager_id = auth.uid()
                )
            ))
            OR (public.get_my_role() = 'rep' AND profile_id = auth.uid())
        )
    );

CREATE POLICY "calendar_rep_write" ON public.calendar_events
    FOR ALL USING (
        workspace_id = public.get_my_workspace()
        AND profile_id = auth.uid()
    );

CREATE POLICY "calendar_owner_all" ON public.calendar_events
    FOR ALL USING (
        workspace_id = public.get_my_workspace()
        AND public.get_my_role() = 'owner'
    );

-- 10. nudges RLS
ALTER TABLE public.nudges ENABLE ROW LEVEL SECURITY;

CREATE POLICY "nudges_user_all" ON public.nudges
    FOR ALL USING (
        workspace_id = public.get_my_workspace()
        AND profile_id = auth.uid()
    );

-- 11. cosmo_audits RLS
ALTER TABLE public.cosmo_audits ENABLE ROW LEVEL SECURITY;

CREATE POLICY "cosmo_select" ON public.cosmo_audits
    FOR SELECT USING (
        workspace_id = public.get_my_workspace()
        AND (
            public.get_my_role() IN ('owner', 'executive')
            OR (public.get_my_role() = 'manager' AND contact_id IN (
                SELECT id FROM public.contacts 
                WHERE assigned_rep_id = auth.uid() 
                   OR assigned_rep_id IN (SELECT id FROM public.profiles WHERE manager_id = auth.uid())
            ))
            OR (public.get_my_role() = 'rep' AND contact_id IN (
                SELECT id FROM public.contacts WHERE assigned_rep_id = auth.uid()
            ))
        )
    );

-- 12. audit_logs RLS
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "audit_select" ON public.audit_logs
    FOR SELECT USING (
        workspace_id = public.get_my_workspace()
        AND public.get_my_role() IN ('owner', 'executive')
    );

-- 13. contact_assignments RLS
ALTER TABLE public.contact_assignments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "assignments_select" ON public.contact_assignments
    FOR SELECT USING (
        workspace_id = public.get_my_workspace()
        AND (
            public.get_my_role() IN ('owner', 'executive')
            OR (public.get_my_role() = 'manager' AND (
                new_rep_id = auth.uid() 
                OR previous_rep_id = auth.uid()
                OR new_rep_id IN (SELECT id FROM public.profiles WHERE manager_id = auth.uid())
            ))
            OR (public.get_my_role() = 'rep' AND (new_rep_id = auth.uid() OR previous_rep_id = auth.uid()))
        )
    );

-- 14. recovery_requests RLS
ALTER TABLE public.recovery_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "requests_select" ON public.recovery_requests
    FOR SELECT USING (
        workspace_id = public.get_my_workspace()
        AND (
            public.get_my_role() IN ('owner', 'executive')
            OR (public.get_my_role() = 'manager' AND (
                original_rep_id = auth.uid() OR requester_rep_id = auth.uid()
                OR requester_rep_id IN (SELECT id FROM public.profiles WHERE manager_id = auth.uid())
            ))
            OR (public.get_my_role() = 'rep' AND requester_rep_id = auth.uid())
        )
    );

CREATE POLICY "requests_rep_insert" ON public.recovery_requests
    FOR INSERT WITH CHECK (
        workspace_id = public.get_my_workspace()
        AND requester_rep_id = auth.uid()
        AND status = 'pending'::public.recovery_status
    );

CREATE POLICY "requests_owner_all" ON public.recovery_requests
    FOR ALL USING (
        workspace_id = public.get_my_workspace()
        AND public.get_my_role() = 'owner'
    );

-- 15. integration_credentials RLS
ALTER TABLE public.integration_credentials ENABLE ROW LEVEL SECURITY;

CREATE POLICY "credentials_owner_all" ON public.integration_credentials
    FOR ALL USING (
        workspace_id = public.get_my_workspace()
        AND public.get_my_role() = 'owner'
    );

-- 16. integration_mappings RLS
ALTER TABLE public.integration_mappings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "mappings_select" ON public.integration_mappings
    FOR SELECT USING (workspace_id = public.get_my_workspace());

CREATE POLICY "mappings_owner_all" ON public.integration_mappings
    FOR ALL USING (
        workspace_id = public.get_my_workspace()
        AND public.get_my_role() = 'owner'
    );
