# 14 — Supabase Schema Blueprint & RLS Policies

## A. Table Schemas

### 1. `profiles` (User Accounts)

```sql
CREATE TABLE public.profiles (
    id uuid REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
    email text UNIQUE NOT NULL,
    name text NOT NULL,
    role text NOT NULL CHECK (role IN ('owner', 'hr', 'manager', 'rep')),
    manager_id uuid REFERENCES public.profiles(id),
    workspace_id uuid REFERENCES public.workspaces(id) NOT NULL,
    avatar_url text,
    status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'revoked')),
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
```

### 2. `workspaces` (Multi-Tenant Workspaces)

```sql
CREATE TABLE public.workspaces (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,
    subdomain text UNIQUE,
    logo_url text,
    theme jsonb DEFAULT '{}',
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);
ALTER TABLE public.workspaces ENABLE ROW LEVEL SECURITY;
```

### 3. `workspace_settings` (Configurable Operating Parameters)

```sql
CREATE TABLE public.workspace_settings (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    workspace_id uuid REFERENCES public.workspaces(id) ON DELETE CASCADE UNIQUE NOT NULL,
    decay_warning integer DEFAULT 30,
    decay_critical integer DEFAULT 60,
    target_conversion integer DEFAULT 48,
    hours_start time DEFAULT '09:00',
    hours_end time DEFAULT '17:00',
    nudge_cap integer DEFAULT 5,
    auto_neglect boolean DEFAULT true,
    manager_override boolean DEFAULT true,
    alert_routing boolean DEFAULT true,
    budget_milestone numeric(10,2) DEFAULT 45.00,
    budget_monthly numeric(10,2) DEFAULT 500.00,
    approval_gate boolean DEFAULT true,
    approval_threshold numeric(10,2) DEFAULT 100.00,
    auto_gifting boolean DEFAULT true,
    webhook_slack text DEFAULT '',
    webhook_teams text DEFAULT '',
    integrations jsonb DEFAULT '{"salesforce":false,"hubspot":false,"twilio":false,"ringcentral":false,"gmail":false,"outlook":false}',
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);
ALTER TABLE public.workspace_settings ENABLE ROW LEVEL SECURITY;
```

### 4. `organizations` (Client Organizations)

```sql
CREATE TABLE public.organizations (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,
    sector text,
    category text NOT NULL CHECK (category IN ('enterprise', 'smb', 'prospect')),
    street_address text,
    city text,
    province text,
    postal_code text,
    phone text,
    email text,
    workspace_id uuid REFERENCES public.workspaces(id) ON DELETE CASCADE NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(name, workspace_id)
);
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;
```

### 5. `contacts` (Customers & Prospects)

```sql
CREATE TABLE public.contacts (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    org_id uuid REFERENCES public.organizations(id) ON DELETE CASCADE,
    name text NOT NULL,
    email text,
    phone text,
    assigned_rep_id uuid REFERENCES public.profiles(id),
    status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'neglected')),
    relationship_health integer DEFAULT 100 CHECK (relationship_health BETWEEN 0 AND 100),
    ai_recommendation text,
    workspace_id uuid REFERENCES public.workspaces(id) ON DELETE CASCADE NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);
ALTER TABLE public.contacts ENABLE ROW LEVEL SECURITY;
```

### 6. `activities` (Touchpoints / Timeline)

```sql
CREATE TABLE public.activities (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    contact_id uuid REFERENCES public.contacts(id) ON DELETE CASCADE,
    rep_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    type text NOT NULL CHECK (type IN ('Call', 'Email', 'Meeting', 'Proposal', 'Gift', 'Note')),
    grade text CHECK (grade IN ('A', 'B', 'C', 'D', 'F')),
    notes text,
    workspace_id uuid REFERENCES public.workspaces(id) ON DELETE CASCADE NOT NULL,
    logged_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);
ALTER TABLE public.activities ENABLE ROW LEVEL SECURITY;
```

### 7. `gifts` (Gifting Orders)

```sql
CREATE TABLE public.gifts (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    contact_id uuid REFERENCES public.contacts(id) ON DELETE SET NULL,
    rep_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    confection_type text NOT NULL,
    category text NOT NULL CHECK (category IN ('reach', 'retain', 'remember', 'reward')),
    amount numeric(10, 2),
    status text NOT NULL DEFAULT 'pending' CHECK (status IN (
        'pending', 'awaiting_approval', 'awaiting_design', 'quote_ready',
        'approved', 'dispatched', 'delivered', 'rejected'
    )),
    sender_label text,
    reason text,
    workspace_id uuid REFERENCES public.workspaces(id) ON DELETE CASCADE NOT NULL,
    dispatched_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);
ALTER TABLE public.gifts ENABLE ROW LEVEL SECURITY;
```

### 8. `calendar_events` (Executive/Owner Calendar)

```sql
CREATE TABLE public.calendar_events (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    profile_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
    type text NOT NULL,
    target text NOT NULL,
    event_date date NOT NULL,
    event_time time,
    agenda text,
    workspace_id uuid REFERENCES public.workspaces(id) ON DELETE CASCADE NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);
ALTER TABLE public.calendar_events ENABLE ROW LEVEL SECURITY;
```

### 9. `nudges` (Operational Warnings)

```sql
CREATE TABLE public.nudges (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    profile_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
    message text NOT NULL,
    severity text NOT NULL DEFAULT 'warning' CHECK (severity IN ('info', 'warning', 'critical')),
    is_read boolean DEFAULT false,
    workspace_id uuid REFERENCES public.workspaces(id) ON DELETE CASCADE NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);
ALTER TABLE public.nudges ENABLE ROW LEVEL SECURITY;
```

---

## B. Row Level Security (RLS) Policies

### Helper: Get Current User's Role

```sql
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS text AS $$
    SELECT role FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION public.get_my_workspace()
RETURNS uuid AS $$
    SELECT workspace_id FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;
```

### Contacts RLS

```sql
-- Reps: see only their assigned contacts
CREATE POLICY "reps_own_contacts" ON public.contacts
    FOR SELECT USING (
        assigned_rep_id = auth.uid()
        AND workspace_id = public.get_my_workspace()
    );

-- Managers: see their own + their direct reports' contacts
CREATE POLICY "managers_team_contacts" ON public.contacts
    FOR SELECT USING (
        workspace_id = public.get_my_workspace()
        AND (
            assigned_rep_id = auth.uid()
            OR assigned_rep_id IN (
                SELECT id FROM public.profiles WHERE manager_id = auth.uid()
            )
        )
        AND public.get_my_role() = 'manager'
    );

-- Owners and Executives: full org-wide access
CREATE POLICY "admins_all_contacts" ON public.contacts
    FOR SELECT USING (
        workspace_id = public.get_my_workspace()
        AND public.get_my_role() IN ('owner', 'hr')
    );
```

### Activities RLS

```sql
-- Same pattern as contacts — scope by rep assignment
CREATE POLICY "reps_own_activities" ON public.activities
    FOR SELECT USING (
        rep_id = auth.uid()
        AND workspace_id = public.get_my_workspace()
    );

CREATE POLICY "managers_team_activities" ON public.activities
    FOR SELECT USING (
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
    FOR SELECT USING (
        workspace_id = public.get_my_workspace()
        AND public.get_my_role() IN ('owner', 'hr')
    );
```

### Gifts RLS

```sql
-- Same pattern as contacts/activities
CREATE POLICY "reps_own_gifts" ON public.gifts
    FOR SELECT USING (
        rep_id = auth.uid()
        AND workspace_id = public.get_my_workspace()
    );

CREATE POLICY "managers_team_gifts" ON public.gifts
    FOR SELECT USING (
        workspace_id = public.get_my_workspace()
        AND (
            rep_id = auth.uid()
            OR rep_id IN (
                SELECT id FROM public.profiles WHERE manager_id = auth.uid()
            )
        )
        AND public.get_my_role() = 'manager'
    );

CREATE POLICY "admins_all_gifts" ON public.gifts
    FOR SELECT USING (
        workspace_id = public.get_my_workspace()
        AND public.get_my_role() IN ('owner', 'hr')
    );

-- Only owners can approve/reject gifts
CREATE POLICY "owners_manage_gifts" ON public.gifts
    FOR UPDATE USING (
        workspace_id = public.get_my_workspace()
        AND public.get_my_role() = 'owner'
    );
```

### Workspace Settings RLS

```sql
-- Only owners can modify settings
CREATE POLICY "owners_manage_settings" ON public.workspace_settings
    FOR ALL USING (
        workspace_id = public.get_my_workspace()
        AND public.get_my_role() = 'owner'
    );

-- All authenticated users can read settings (needed for thresholds)
CREATE POLICY "all_read_settings" ON public.workspace_settings
    FOR SELECT USING (
        workspace_id = public.get_my_workspace()
    );
```

### Profiles RLS

```sql
-- All users in same workspace can see each other's profiles
CREATE POLICY "workspace_profiles" ON public.profiles
    FOR SELECT USING (
        workspace_id = public.get_my_workspace()
    );

-- Only owners can modify profiles (seat provisioning)
CREATE POLICY "owners_manage_profiles" ON public.profiles
    FOR ALL USING (
        workspace_id = public.get_my_workspace()
        AND public.get_my_role() = 'owner'
    );
```

---

## C. Computed Views (Replacing Hardcoded KPIs)

### Leaderboard View

```sql
CREATE OR REPLACE VIEW public.leaderboard_live AS
SELECT
    p.id,
    p.name,
    p.role,
    COUNT(DISTINCT a.id) AS touchpoints,
    COUNT(DISTINCT CASE WHEN c.status = 'active' AND o.category != 'prospect' THEN c.id END) AS clients,
    COUNT(DISTINCT CASE WHEN o.category = 'prospect' THEN c.id END) AS prospects,
    AVG(c.relationship_health) AS avg_health,
    COUNT(DISTINCT g.id) AS gifts_sent
FROM public.profiles p
LEFT JOIN public.activities a ON a.rep_id = p.id AND a.logged_at > NOW() - INTERVAL '7 days'
LEFT JOIN public.contacts c ON c.assigned_rep_id = p.id
LEFT JOIN public.organizations o ON o.id = c.org_id
LEFT JOIN public.gifts g ON g.rep_id = p.id AND g.status = 'delivered'
WHERE p.workspace_id = public.get_my_workspace()
GROUP BY p.id, p.name, p.role
ORDER BY touchpoints DESC;
```

### Inactivity Check

```sql
-- Find contacts whose last activity exceeds the workspace critical threshold
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
```
