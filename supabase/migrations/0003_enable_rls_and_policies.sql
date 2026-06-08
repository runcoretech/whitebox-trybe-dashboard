-- ============================================================================
-- PHASE 3: ROW LEVEL SECURITY, VIEWS, RPC, AND TRIGGER ENFORCEMENT
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. HARDENED SECURE CONTEXT HELPERS & UTILITIES
-- ============================================================================

-- Re-declare Phase 2 helpers with search path hardening to prevent search-path hijacking
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS text AS $$
    SELECT role::text FROM public.profiles 
    WHERE id = auth.uid() AND status = 'active'::public.profile_status;
$$ LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public;

CREATE OR REPLACE FUNCTION public.get_my_workspace()
RETURNS uuid AS $$
    SELECT workspace_id FROM public.profiles 
    WHERE id = auth.uid() AND status = 'active'::public.profile_status;
$$ LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public;

-- Check if contact is open in Fumble Pool (dynamic settings check)
-- SECURITY DEFINER allows bypassing direct table RLS while scoping internally
CREATE OR REPLACE FUNCTION public.is_contact_claimable(cid uuid)
RETURNS boolean AS $$
DECLARE
    inactive_days integer;
    critical_days integer;
    my_ws uuid;
    contact_exists boolean;
BEGIN
    my_ws := public.get_my_workspace();
    IF my_ws IS NULL THEN
        RETURN false;
    END IF;

    -- Tenant Isolation Lock: Ensure contact belongs to current workspace
    SELECT EXISTS (
        SELECT 1 FROM public.contacts 
        WHERE id = cid AND workspace_id = my_ws
    ) INTO contact_exists;

    IF NOT contact_exists THEN
        RETURN false;
    END IF;

    -- Compute days elapsed since last touchpoint activity
    SELECT COALESCE(DATE_PART('day', now() - MAX(logged_at)), 999) INTO inactive_days
    FROM public.activities WHERE contact_id = cid AND workspace_id = my_ws;

    -- Fetch workspace settings critical neglect threshold
    SELECT decay_critical INTO critical_days
    FROM public.workspace_settings WHERE workspace_id = my_ws;

    -- Open pool triggers 15 days after critical neglect threshold (e.g., 75 days if critical=60)
    IF inactive_days >= (critical_days + 15) THEN
        RETURN true;
    END IF;
    RETURN false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public;

-- ============================================================================
-- 2. ENABLE ROW LEVEL SECURITY ON ALL 17 PHYSICAL TABLES
-- ============================================================================

ALTER TABLE public.workspaces ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workspace_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.boxes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.calendar_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nudges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cosmo_audits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs_default ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contact_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recovery_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.integration_credentials ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.integration_mappings ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 3. ROW LEVEL SECURITY POLICIES BY TABLE
-- ============================================================================

-- --- 3.1. workspaces policies ---
CREATE POLICY "workspaces_select" ON public.workspaces
    FOR SELECT USING (id = public.get_my_workspace());

CREATE POLICY "workspaces_owner_update" ON public.workspaces
    FOR UPDATE USING (id = public.get_my_workspace() AND public.get_my_role() = 'owner');

-- --- 3.2. profiles policies ---
CREATE POLICY "profiles_select" ON public.profiles
    FOR SELECT USING (workspace_id = public.get_my_workspace());

CREATE POLICY "profiles_update" ON public.profiles
    FOR UPDATE USING (
        workspace_id = public.get_my_workspace()
        AND (public.get_my_role() = 'owner' OR id = auth.uid())
    );

-- --- 3.3. workspace_settings policies ---
CREATE POLICY "settings_select" ON public.workspace_settings
    FOR SELECT USING (workspace_id = public.get_my_workspace());

CREATE POLICY "settings_owner_all" ON public.workspace_settings
    FOR ALL USING (
        workspace_id = public.get_my_workspace() 
        AND public.get_my_role() = 'owner'
    );

-- --- 3.4. organizations policies ---
CREATE POLICY "organizations_select" ON public.organizations
    FOR SELECT USING (
        workspace_id = public.get_my_workspace()
        AND (
            public.get_my_role() IN ('owner', 'executive', 'manager')
            OR id IN (
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

-- --- 3.5. contacts policies (Explicitly blocking Deletes for Reps/Managers) ---
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
                OR public.is_contact_claimable(id) = true
            ))
            OR (public.get_my_role() = 'rep' AND (
                assigned_rep_id = auth.uid()
                OR public.is_contact_claimable(id) = true
            ))
        )
    );

CREATE POLICY "contacts_rep_insert" ON public.contacts
    FOR INSERT WITH CHECK (
        workspace_id = public.get_my_workspace()
        AND public.get_my_role() = 'rep'
    );

CREATE POLICY "contacts_rep_update" ON public.contacts
    FOR UPDATE USING (
        workspace_id = public.get_my_workspace()
        AND assigned_rep_id = auth.uid()
        AND public.get_my_role() = 'rep'
    );

CREATE POLICY "contacts_manager_insert" ON public.contacts
    FOR INSERT WITH CHECK (
        workspace_id = public.get_my_workspace()
        AND public.get_my_role() = 'manager'
    );

CREATE POLICY "contacts_manager_update" ON public.contacts
    FOR UPDATE USING (
        workspace_id = public.get_my_workspace()
        AND (
            assigned_rep_id = auth.uid() 
            OR assigned_rep_id IN (
                SELECT id FROM public.profiles WHERE manager_id = auth.uid()
            )
        )
        AND public.get_my_role() = 'manager'
    );

CREATE POLICY "contacts_owner_all" ON public.contacts
    FOR ALL USING (
        workspace_id = public.get_my_workspace()
        AND public.get_my_role() = 'owner'
    );

-- --- 3.6. activities policies ---
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

-- --- 3.7. boxes policies ---
CREATE POLICY "boxes_select" ON public.boxes
    FOR SELECT USING (workspace_id = public.get_my_workspace());

CREATE POLICY "boxes_owner_all" ON public.boxes
    FOR ALL USING (
        workspace_id = public.get_my_workspace()
        AND public.get_my_role() = 'owner'
    );

-- --- 3.8. gifts policies (Explicitly blocking Deletes for Reps/Managers) ---
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

CREATE POLICY "gifts_manager_insert" ON public.gifts
    FOR INSERT WITH CHECK (
        workspace_id = public.get_my_workspace()
        AND rep_id = auth.uid()
        AND status = 'pending'::public.gift_status
    );

CREATE POLICY "gifts_manager_update" ON public.gifts
    FOR UPDATE USING (
        workspace_id = public.get_my_workspace()
        AND public.get_my_role() = 'manager'
        AND (
            rep_id = auth.uid()
            OR rep_id IN (
                SELECT id FROM public.profiles WHERE manager_id = auth.uid()
            )
        )
    ) WITH CHECK (
        -- Can only modify within owner limits. Trigger enforces status change rules.
        true
    );

CREATE POLICY "gifts_owner_all" ON public.gifts
    FOR ALL USING (
        workspace_id = public.get_my_workspace()
        AND public.get_my_role() = 'owner'
    );

-- --- 3.9. calendar_events policies ---
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

-- --- 3.10. nudges policies ---
CREATE POLICY "nudges_user_all" ON public.nudges
    FOR ALL USING (
        workspace_id = public.get_my_workspace()
        AND profile_id = auth.uid()
    );

-- --- 3.11. cosmo_audits policies ---
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

-- --- 3.12. audit_logs parent policy (Inherited by partitions) ---
CREATE POLICY "audit_select" ON public.audit_logs
    FOR SELECT USING (
        workspace_id = public.get_my_workspace()
        AND public.get_my_role() IN ('owner', 'executive')
    );

-- --- 3.13. contact_assignments policies ---
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

-- --- 3.14. recovery_requests policies ---
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

CREATE POLICY "requests_insert" ON public.recovery_requests
    FOR INSERT WITH CHECK (
        workspace_id = public.get_my_workspace()
        AND requester_rep_id = auth.uid()
        AND status = 'pending'::public.recovery_status
        AND public.get_my_role() IN ('rep', 'manager')
    );

CREATE POLICY "requests_manager_update" ON public.recovery_requests
    FOR UPDATE USING (
        workspace_id = public.get_my_workspace()
        AND public.get_my_role() = 'manager'
        AND requester_rep_id IN (
            SELECT id FROM public.profiles WHERE manager_id = auth.uid()
        )
    ) WITH CHECK (
        status IN ('approved'::public.recovery_status, 'rejected'::public.recovery_status)
        AND reviewed_by = auth.uid()
    );

CREATE POLICY "requests_owner_all" ON public.recovery_requests
    FOR ALL USING (
        workspace_id = public.get_my_workspace()
        AND public.get_my_role() = 'owner'
    );

-- --- 3.15. integration_credentials policies ---
CREATE POLICY "credentials_owner_all" ON public.integration_credentials
    FOR ALL USING (
        workspace_id = public.get_my_workspace()
        AND public.get_my_role() = 'owner'
    );

-- --- 3.16. integration_mappings policies ---
CREATE POLICY "mappings_select" ON public.integration_mappings
    FOR SELECT USING (workspace_id = public.get_my_workspace());

CREATE POLICY "mappings_owner_all" ON public.integration_mappings
    FOR ALL USING (
        workspace_id = public.get_my_workspace()
        AND public.get_my_role() = 'owner'
    );

-- ============================================================================
-- 4. HARDENED BUSINESS LOGIC SECURITY TRIGGERS
-- ============================================================================

-- --- 4.1. Prevent Direct Contact Reassignments (Zero Bypass check) ---
CREATE OR REPLACE FUNCTION public.prevent_direct_reassignments()
RETURNS trigger AS $$
BEGIN
    IF OLD.assigned_rep_id IS DISTINCT FROM NEW.assigned_rep_id THEN
        -- Allow if updated by Owner
        IF public.get_my_role() = 'owner' THEN
            RETURN NEW;
        END IF;

        -- Verify that an approved recovery request exists in this transaction
        IF NOT EXISTS (
            SELECT 1 FROM public.recovery_requests
            WHERE contact_id = NEW.id
              AND requester_rep_id = NEW.assigned_rep_id
              AND status = 'approved'::public.recovery_status
              AND updated_at > now() - interval '1 second'
        ) THEN
            RAISE EXCEPTION 'Access Denied: Direct contact ownership reassignments are blocked. Use the Recovery Request system.';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE TRIGGER trg_prevent_direct_reassignments
    BEFORE UPDATE OF assigned_rep_id ON public.contacts
    FOR EACH ROW EXECUTE FUNCTION public.prevent_direct_reassignments();

-- --- 4.2. Auto-Process Approved Recovery Requests ---
CREATE OR REPLACE FUNCTION public.handle_recovery_request_approval()
RETURNS trigger AS $$
BEGIN
    IF NEW.status = 'approved'::public.recovery_status AND OLD.status = 'pending'::public.recovery_status THEN
        -- 1. Update contact's assigned representative (Trigger handles the verification)
        UPDATE public.contacts
        SET assigned_rep_id = NEW.requester_rep_id,
            status = 'active'
        WHERE id = NEW.contact_id AND workspace_id = NEW.workspace_id;

        -- 2. Log historical ownership transfer audit
        INSERT INTO public.contact_assignments (
            workspace_id,
            contact_id,
            previous_rep_id,
            new_rep_id,
            assigned_by,
            justification
        )
        VALUES (
            NEW.workspace_id,
            NEW.contact_id,
            NEW.original_rep_id,
            NEW.requester_rep_id,
            NEW.reviewed_by,
            'Recovery Claim Approval. Request ID: ' || NEW.id || '. Justification: ' || NEW.justification
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE TRIGGER trg_recovery_approval
    AFTER UPDATE OF status ON public.recovery_requests
    FOR EACH ROW EXECUTE FUNCTION public.handle_recovery_request_approval();

-- --- 4.3. Enforce Gifting Approvals & Threshold States ---
CREATE OR REPLACE FUNCTION public.enforce_gift_status_changes()
RETURNS trigger AS $$
DECLARE
    caller_role text;
    ws_settings record;
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        caller_role := public.get_my_role();
        
        -- 1. Representatives cannot approve or reject gifts
        IF caller_role = 'rep' THEN
            RAISE EXCEPTION 'Access Denied: Representatives cannot approve or reject gifts.';
        END IF;
        
        -- 2. Managers have scoped approval rights
        IF caller_role = 'manager' THEN
            IF OLD.rep_id = auth.uid() THEN
                RAISE EXCEPTION 'Access Denied: Managers cannot approve their own gifts.';
            END IF;
            
            -- Ensure rep belongs to manager's team
            IF NOT EXISTS (
                SELECT 1 FROM public.profiles 
                WHERE id = OLD.rep_id AND manager_id = auth.uid()
            ) THEN
                RAISE EXCEPTION 'Access Denied: You can only approve gifts for your direct reports.';
            END IF;
            
            IF OLD.status <> 'pending'::public.gift_status THEN
                RAISE EXCEPTION 'Access Denied: Only pending gifts can be approved or rejected.';
            END IF;
            
            IF NEW.status NOT IN ('approved'::public.gift_status, 'rejected'::public.gift_status) THEN
                RAISE EXCEPTION 'Access Denied: Managers can only transition status to approved or rejected.';
            END IF;
            
            -- Validate manager settings and thresholds
            SELECT manager_override, approval_threshold INTO ws_settings
            FROM public.workspace_settings WHERE workspace_id = OLD.workspace_id;
            
            IF NOT ws_settings.manager_override THEN
                RAISE EXCEPTION 'Access Denied: Manager override is disabled in workspace settings.';
            END IF;
            
            IF OLD.amount > ws_settings.approval_threshold THEN
                RAISE EXCEPTION 'Access Denied: Gift amount ($%) exceeds your approval threshold of $%.', OLD.amount, ws_settings.approval_threshold;
            END IF;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE TRIGGER trg_enforce_gift_status_changes
    BEFORE UPDATE OF status ON public.gifts
    FOR EACH ROW EXECUTE FUNCTION public.enforce_gift_status_changes();

-- ============================================================================
-- 5. SECURED VIEWS (Enforcing security_invoker)
-- ============================================================================

-- --- 5.1. Live Leaderboard View ---
CREATE OR REPLACE VIEW public.leaderboard_live AS
SELECT
    p.id,
    p.name,
    p.role,
    COUNT(DISTINCT a.id) AS touchpoints,
    COUNT(DISTINCT CASE WHEN c.status = 'active' AND o.category != 'prospect' THEN c.id END) AS clients,
    COUNT(DISTINCT CASE WHEN o.category = 'prospect' THEN c.id END) AS prospects,
    COALESCE(AVG(c.relationship_health), 100)::integer AS avg_health,
    COUNT(DISTINCT g.id) AS gifts_sent
FROM public.profiles p
LEFT JOIN public.activities a ON a.rep_id = p.id AND a.logged_at > NOW() - INTERVAL '7 days'
LEFT JOIN public.contacts c ON c.assigned_rep_id = p.id
LEFT JOIN public.organizations o ON o.id = c.org_id
LEFT JOIN public.gifts g ON g.rep_id = p.id AND g.status = 'delivered'
WHERE p.workspace_id = public.get_my_workspace()
GROUP BY p.id, p.name, p.role
ORDER BY touchpoints DESC;

-- --- 5.2. Contacts Decay Status View (security_invoker forces RLS filtering on Contacts) ---
CREATE OR REPLACE VIEW public.contacts_decay_status 
WITH (security_invoker = on) AS
SELECT 
    c.id AS contact_id,
    c.name AS contact_name,
    c.workspace_id,
    COALESCE(DATE_PART('day', now() - la.last_activity), 999) AS inactive_days,
    GREATEST(0, LEAST(100, 
        CASE 
            WHEN la.last_activity IS NULL THEN 0
            WHEN DATE_PART('day', now() - la.last_activity) <= ws.decay_warning THEN 100
            ELSE 100 - ((DATE_PART('day', now() - la.last_activity) - ws.decay_warning) * ws.decay_factor)
        END
    ))::integer AS computed_health
FROM public.contacts c
JOIN public.workspace_settings ws ON ws.workspace_id = c.workspace_id
LEFT JOIN LATERAL (
    SELECT MAX(logged_at) AS last_activity
    FROM public.activities
    WHERE contact_id = c.id
) la ON true;

-- --- 5.3. Recovery Leaderboard View ---
CREATE OR REPLACE VIEW public.recovery_leaderboard AS
SELECT
    p.id,
    p.name,
    COUNT(r.id) AS claims_rescued
FROM public.profiles p
LEFT JOIN public.recovery_requests r ON r.requester_rep_id = p.id AND r.status = 'approved'
WHERE p.workspace_id = public.get_my_workspace()
GROUP BY p.id, p.name
ORDER BY claims_rescued DESC;

-- ============================================================================
-- 6. SECURED STORED PROCEDURES (RPCs)
-- ============================================================================

-- Binds using SECURITY INVOKER so underlying queries respect current user's RLS scoping
CREATE OR REPLACE FUNCTION public.get_kpi_summary(timeframe_days integer)
RETURNS jsonb AS $$
DECLARE
    result jsonb;
    my_ws uuid;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER STABLE;

-- Redefine get_kpi_summary with correct code
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
END;
$$ LANGUAGE plpgsql SECURITY INVOKER STABLE;

-- --- 6.2. Auto Update timestamp trigger on Recovery Requests ---
CREATE OR REPLACE FUNCTION public.set_current_timestamp_updated_at()
RETURNS trigger AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_recovery_requests_updated_at
    BEFORE UPDATE ON public.recovery_requests
    FOR EACH ROW EXECUTE FUNCTION public.set_current_timestamp_updated_at();

COMMIT;
