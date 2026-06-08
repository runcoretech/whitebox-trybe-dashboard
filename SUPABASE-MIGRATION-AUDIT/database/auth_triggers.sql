-- ============================================================
-- SUPABASE AUTH SYNCHRONIZATION TRIGGER
-- ============================================================

-- Function triggered on auth.users insert to auto-create public.profiles
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
DECLARE
    default_workspace_id uuid;
BEGIN
    -- Resolve workspace_id from metadata or fetch first workspace as default
    IF (new.raw_user_meta_data->>'workspace_id') IS NOT NULL THEN
        default_workspace_id := (new.raw_user_meta_data->>'workspace_id')::uuid;
    ELSE
        SELECT id INTO default_workspace_id FROM public.workspaces LIMIT 1;
    END IF;

    -- Insert into public.profiles
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
        COALESCE(new.raw_user_meta_data->>'role', 'rep'),
        default_workspace_id,
        (new.raw_user_meta_data->>'manager_id')::uuid,
        new.raw_user_meta_data->>'avatar_url',
        'active'
    );
    
    RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Bind trigger
CREATE OR REPLACE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
