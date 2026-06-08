-- ============================================================
-- ROW LEVEL SECURITY (RLS) POLICIES & HELPER FUNCTIONS
-- ============================================================

-- Helper functions to get current context securely
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS text AS $$
    SELECT role FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION public.get_my_workspace()
RETURNS uuid AS $$
    SELECT workspace_id FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- 1. Profiles Policies
CREATE POLICY "workspace_profiles" ON public.profiles
    FOR SELECT USING (
        workspace_id = public.get_my_workspace()
    );

CREATE POLICY "owners_manage_profiles" ON public.profiles
    FOR ALL USING (
        workspace_id = public.get_my_workspace()
        AND public.get_my_role() = 'owner'
    );

-- 2. Workspaces Policies
CREATE POLICY "user_workspace_view" ON public.workspaces
    FOR SELECT USING (
        id = public.get_my_workspace()
    );

CREATE POLICY "owners_update_workspace" ON public.workspaces
    FOR UPDATE USING (
        id = public.get_my_workspace()
        AND public.get_my_role() = 'owner'
    );

-- 3. Workspace Settings Policies
CREATE POLICY "all_read_settings" ON public.workspace_settings
    FOR SELECT USING (
        workspace_id = public.get_my_workspace()
    );

CREATE POLICY "owners_manage_settings" ON public.workspace_settings
    FOR ALL USING (
        workspace_id = public.get_my_workspace()
        AND public.get_my_role() = 'owner'
    );

-- 4. Organizations Policies
CREATE POLICY "rep_read_orgs" ON public.organizations
    FOR SELECT USING (
        workspace_id = public.get_my_workspace()
        AND public.get_my_role() = 'rep'
    );

CREATE POLICY "manager_read_write_orgs" ON public.organizations
    FOR ALL USING (
        workspace_id = public.get_my_workspace()
        AND public.get_my_role() = 'manager'
    );

CREATE POLICY "admin_all_orgs" ON public.organizations
    FOR ALL USING (
        workspace_id = public.get_my_workspace()
        AND public.get_my_role() IN ('owner', 'hr')
    );

-- 5. Contacts Policies
CREATE POLICY "reps_own_contacts" ON public.contacts
    FOR ALL USING (
        workspace_id = public.get_my_workspace()
        AND assigned_rep_id = auth.uid()
        AND public.get_my_role() = 'rep'
    );

CREATE POLICY "managers_team_contacts" ON public.contacts
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

CREATE POLICY "admins_all_contacts" ON public.contacts
    FOR ALL USING (
        workspace_id = public.get_my_workspace()
        AND public.get_my_role() IN ('owner', 'hr')
    );

-- 6. Activities Policies
CREATE POLICY "reps_own_activities" ON public.activities
    FOR ALL USING (
        workspace_id = public.get_my_workspace()
        AND rep_id = auth.uid()
        AND public.get_my_role() = 'rep'
    );

CREATE POLICY "managers_team_activities" ON public.activities
    FOR ALL USING (
        workspace_id = public.get_my_workspace()
        AND (
            rep_id = auth.uid()
            OR rep_id IN (
                SELECT id FROM public.profiles WHERE manager_id = auth.uid()
            )
        )
        AND public.get_my_role() = 'manager'
    );

CREATE POLICY "admins_all_activities" ON public.activities
    FOR ALL USING (
        workspace_id = public.get_my_workspace()
        AND public.get_my_role() IN ('owner', 'hr')
    );

-- 7. Gifts Policies
CREATE POLICY "reps_own_gifts" ON public.gifts
    FOR ALL USING (
        workspace_id = public.get_my_workspace()
        AND rep_id = auth.uid()
        AND public.get_my_role() = 'rep'
    );

CREATE POLICY "managers_team_gifts" ON public.gifts
    FOR ALL USING (
        workspace_id = public.get_my_workspace()
        AND (
            rep_id = auth.uid()
            OR rep_id IN (
                SELECT id FROM public.profiles WHERE manager_id = auth.uid()
            )
        )
        AND public.get_my_role() = 'manager'
    );

CREATE POLICY "admins_read_gifts" ON public.gifts
    FOR SELECT USING (
        workspace_id = public.get_my_workspace()
        AND public.get_my_role() IN ('owner', 'hr')
    );

CREATE POLICY "owners_approve_gifts" ON public.gifts
    FOR ALL USING (
        workspace_id = public.get_my_workspace()
        AND public.get_my_role() = 'owner'
    );

-- 8. Calendar Events Policies
CREATE POLICY "reps_own_events" ON public.calendar_events
    FOR ALL USING (
        workspace_id = public.get_my_workspace()
        AND profile_id = auth.uid()
        AND public.get_my_role() = 'rep'
    );

CREATE POLICY "managers_team_events" ON public.calendar_events
    FOR ALL USING (
        workspace_id = public.get_my_workspace()
        AND (
            profile_id = auth.uid()
            OR profile_id IN (
                SELECT id FROM public.profiles WHERE manager_id = auth.uid()
            )
        )
        AND public.get_my_role() = 'manager'
    );

CREATE POLICY "admins_all_events" ON public.calendar_events
    FOR ALL USING (
        workspace_id = public.get_my_workspace()
        AND public.get_my_role() IN ('owner', 'hr')
    );

-- 9. Nudges Policies
CREATE POLICY "user_own_nudges" ON public.nudges
    FOR ALL USING (
        workspace_id = public.get_my_workspace()
        AND profile_id = auth.uid()
    );

-- 10. Cosmo Audits Policies
CREATE POLICY "reps_cosmo_audits" ON public.cosmo_audits
    FOR SELECT USING (
        workspace_id = public.get_my_workspace()
        AND contact_id IN (
            SELECT id FROM public.contacts WHERE assigned_rep_id = auth.uid()
        )
        AND public.get_my_role() = 'rep'
    );

CREATE POLICY "managers_cosmo_audits" ON public.cosmo_audits
    FOR SELECT USING (
        workspace_id = public.get_my_workspace()
        AND contact_id IN (
            SELECT id FROM public.contacts WHERE assigned_rep_id = auth.uid()
            OR assigned_rep_id IN (
                SELECT id FROM public.profiles WHERE manager_id = auth.uid()
            )
        )
        AND public.get_my_role() = 'manager'
    );

CREATE POLICY "admins_cosmo_audits" ON public.cosmo_audits
    FOR ALL USING (
        workspace_id = public.get_my_workspace()
        AND public.get_my_role() IN ('owner', 'hr')
    );
