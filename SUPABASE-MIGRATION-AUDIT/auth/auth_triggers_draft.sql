-- ============================================================================
-- WHITEBOX RMOS AUTH SYNCHRONIZATION & ESCALATION TRIGGERS (PHASE 2 FINAL)
-- ============================================================================

-- Helper functions to get current context securely (re-declared for trigger compiling safety)
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS text AS $$
    SELECT role::text FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION public.get_my_workspace()
RETURNS uuid AS $$
    SELECT workspace_id FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- 1. PROFILE SYNCHRONIZATION FUNCTION (auth.users -> public.profiles)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
DECLARE
    default_workspace_id uuid;
    target_workspace_id uuid;
    target_role public.user_role;
    creator_role text;
BEGIN
    -- Bootstrap Verification Check:
    -- Verify that at least one workspace is seeded before allowing signups
    SELECT id INTO default_workspace_id FROM public.workspaces ORDER BY created_at ASC LIMIT 1;
    IF default_workspace_id IS NULL THEN
        RAISE EXCEPTION 'Bootstrap Error: No active workspaces found in public.workspaces. Seed a workspace first.';
    END IF;

    -- Resolve creator's role if a session exists (invited flows)
    IF auth.uid() IS NOT NULL THEN
        SELECT role::text INTO creator_role FROM public.profiles WHERE id = auth.uid();
    END IF;

    -- Role Escalation Prevention:
    -- Trust metadata role only if invited by a workspace Owner. Self-signups are forced to 'rep'.
    IF creator_role = 'owner' THEN
        target_role := COALESCE((new.raw_user_meta_data->>'role')::public.user_role, 'rep'::public.user_role);
    ELSE
        target_role := 'rep'::public.user_role;
    END IF;

    -- Workspace Assignment Isolation Lock:
    -- If created by an active admin session, force target workspace to match creator's workspace.
    -- If self-signup (anon), fallback to default bootstrap workspace.
    IF auth.uid() IS NOT NULL THEN
        target_workspace_id := public.get_my_workspace();
    ELSE
        target_workspace_id := default_workspace_id;
    END IF;

    -- Insert profile mapping
    INSERT INTO public.profiles (
        id,
        email,
        name,
        role,
        workspace_id,
        manager_id,
        avatar_url,
        status
    )
    VALUES (
        new.id,
        new.email,
        COALESCE(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
        target_role,
        target_workspace_id,
        (new.raw_user_meta_data->>'manager_id')::uuid,
        new.raw_user_meta_data->>'avatar_url',
        'active'::public.profile_status
    );
    
    RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger binding
CREATE OR REPLACE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================================
-- 2. ROLE ESCALATION & PROFILE MODIFICATION LOCKS
-- ============================================================================

CREATE OR REPLACE FUNCTION public.prevent_role_escalation()
RETURNS trigger AS $$
BEGIN
    -- Rule 1: Cross-Tenant Isolation Lock (Security Definitive Bypasses Block)
    -- Explicitly reject update transactions if targeted profile belongs to another workspace.
    IF OLD.workspace_id <> public.get_my_workspace() OR NEW.workspace_id <> public.get_my_workspace() THEN
        RAISE EXCEPTION 'Access Denied: Cross-tenant profile modifications are strictly prohibited.';
    END IF;

    -- Rule 2: Role column modifications are restricted strictly to workspace Owners
    IF OLD.role IS DISTINCT FROM NEW.role AND public.get_my_role() <> 'owner' THEN
        RAISE EXCEPTION 'Access Denied: Only Owners can modify profile role levels.';
    END IF;

    -- Rule 3: Workspace isolation locks (cannot move profiles between workspaces after creation)
    IF OLD.workspace_id IS DISTINCT FROM NEW.workspace_id AND public.get_my_role() <> 'owner' THEN
        RAISE EXCEPTION 'Access Denied: Cannot modify user workspace assignments.';
    END IF;

    -- Rule 4: Single-Owner Lockout Protection
    -- Prevent demoting or deactivating the last active Owner in a workspace
    IF OLD.role = 'owner'::public.user_role AND 
       (NEW.role <> 'owner'::public.user_role OR NEW.status = 'revoked'::public.profile_status) THEN
        IF (
            SELECT COUNT(*) 
            FROM public.profiles 
            WHERE workspace_id = OLD.workspace_id 
              AND role = 'owner'::public.user_role 
              AND status = 'active'::public.profile_status
        ) <= 1 THEN
            RAISE EXCEPTION 'Constraint Error: Cannot demote or revoke the last remaining Owner in the workspace.';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Bind role checks trigger
CREATE OR REPLACE TRIGGER check_role_escalation
    BEFORE UPDATE OF role, status, workspace_id ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.prevent_role_escalation();
