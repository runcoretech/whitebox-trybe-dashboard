-- ============================================================================
-- WHITEBOX RMOS DATABASE INITIALIZATION SCHEMA (PHASE 1 FINAL - REVISED)
-- ============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- ENUM TYPES (SAFE CREATION WRAPPERS)
-- ============================================================================

DO $$ BEGIN
    CREATE TYPE public.user_role AS ENUM ('owner', 'executive', 'manager', 'rep');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE public.org_category AS ENUM ('enterprise', 'smb', 'prospect');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE public.activity_type AS ENUM ('Call', 'Email', 'Meeting', 'Proposal', 'Gift', 'Note', 'System');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE public.activity_grade AS ENUM ('A', 'B', 'C', 'D', 'F');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE public.gift_category AS ENUM ('reach', 'retain', 'remember', 'reward');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE public.gift_status AS ENUM (
        'pending',
        'awaiting_approval',
        'awaiting_design',
        'quote_ready',
        'approved',
        'dispatched',
        'delivered',
        'failed',
        'rejected'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE public.severity_level AS ENUM ('info', 'warning', 'critical');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE public.recovery_status AS ENUM ('pending', 'approved', 'rejected', 'expired');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE public.profile_status AS ENUM ('active', 'revoked');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- ============================================================================
-- TABLES DEFINITION
-- ============================================================================

-- 1. workspaces (Multi-Tenant Workspace Scopes)
CREATE TABLE public.workspaces (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,
    subdomain text UNIQUE,
    logo_url text,
    theme jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. profiles (User/Staff Profiles linked to Supabase Auth)
CREATE TABLE public.profiles (
    id uuid REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
    email text UNIQUE NOT NULL,
    name text NOT NULL,
    role public.user_role DEFAULT 'rep'::public.user_role NOT NULL,
    manager_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    workspace_id uuid REFERENCES public.workspaces(id) ON DELETE CASCADE NOT NULL,
    avatar_url text,
    status public.profile_status DEFAULT 'active'::public.profile_status NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. workspace_settings (Configurable Workspace Parameters)
CREATE TABLE public.workspace_settings (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    workspace_id uuid REFERENCES public.workspaces(id) ON DELETE CASCADE UNIQUE NOT NULL,
    decay_warning integer DEFAULT 30 NOT NULL CHECK (decay_warning >= 0),
    decay_critical integer DEFAULT 60 NOT NULL CHECK (decay_critical > decay_warning),
    decay_factor numeric(4,2) DEFAULT 1.50 NOT NULL CHECK (decay_factor >= 0),
    target_conversion integer DEFAULT 48 NOT NULL CHECK (target_conversion BETWEEN 0 AND 100),
    hours_start time DEFAULT '09:00'::time NOT NULL,
    hours_end time DEFAULT '17:00'::time NOT NULL,
    nudge_cap integer DEFAULT 5 NOT NULL CHECK (nudge_cap >= 0),
    auto_neglect boolean DEFAULT true NOT NULL,
    manager_override boolean DEFAULT true NOT NULL,
    alert_routing boolean DEFAULT true NOT NULL,
    budget_milestone numeric(10,2) DEFAULT 45.00 NOT NULL CHECK (budget_milestone >= 0),
    budget_monthly numeric(10,2) DEFAULT 500.00 NOT NULL CHECK (budget_monthly >= 0),
    approval_gate boolean DEFAULT true NOT NULL,
    approval_threshold numeric(10,2) DEFAULT 100.00 NOT NULL CHECK (approval_threshold >= 0),
    auto_gifting boolean DEFAULT true NOT NULL,
    webhook_slack text DEFAULT ''::text NOT NULL,
    webhook_teams text DEFAULT ''::text NOT NULL,
    integrations jsonb DEFAULT '{"salesforce":false,"hubspot":false,"twilio":false,"ringcentral":false,"gmail":false,"outlook":false}'::jsonb NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT chk_hours_range CHECK (hours_start < hours_end)
);

-- 4. organizations (Client Organizations)
CREATE TABLE public.organizations (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,
    sector text,
    category public.org_category DEFAULT 'prospect'::public.org_category NOT NULL,
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

-- 5. contacts (Individual Customers & Prospects)
CREATE TABLE public.contacts (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    org_id uuid REFERENCES public.organizations(id) ON DELETE CASCADE,
    name text NOT NULL,
    email text,
    phone text,
    assigned_rep_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'neglected')),
    relationship_health integer DEFAULT 100 NOT NULL CHECK (relationship_health BETWEEN 0 AND 100),
    ai_recommendation text,
    workspace_id uuid REFERENCES public.workspaces(id) ON DELETE CASCADE NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 6. activities (Touchpoints & CRM Timeline Log)
CREATE TABLE public.activities (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    contact_id uuid REFERENCES public.contacts(id) ON DELETE CASCADE,
    rep_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    type public.activity_type NOT NULL,
    grade public.activity_grade,
    notes text,
    workspace_id uuid REFERENCES public.workspaces(id) ON DELETE CASCADE NOT NULL,
    logged_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 7. boxes (Inventory Product Directory for Gifting)
CREATE TABLE public.boxes (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    workspace_id uuid REFERENCES public.workspaces(id) ON DELETE CASCADE NOT NULL,
    name text NOT NULL,
    description text,
    theme_color text,
    price numeric(10,2) NOT NULL CHECK (price >= 0),
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(workspace_id, name)
);

-- 8. gifts (Gifting Dispatches & Orders Pipeline)
CREATE TABLE public.gifts (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    contact_id uuid REFERENCES public.contacts(id) ON DELETE SET NULL,
    rep_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    box_id uuid REFERENCES public.boxes(id) ON DELETE RESTRICT NOT NULL,
    category public.gift_category NOT NULL,
    amount numeric(10, 2) NOT NULL CHECK (amount >= 0),
    status public.gift_status DEFAULT 'pending'::public.gift_status NOT NULL,
    shipping_street text,
    shipping_city text,
    shipping_province text,
    shipping_postal text,
    carrier text,
    tracking_number text,
    sender_label text,
    reason text,
    workspace_id uuid REFERENCES public.workspaces(id) ON DELETE CASCADE NOT NULL,
    dispatched_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 9. calendar_events (Milestones & Schedules)
CREATE TABLE public.calendar_events (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    profile_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    type text NOT NULL,
    target text NOT NULL,
    event_date date NOT NULL,
    event_time time,
    agenda text,
    workspace_id uuid REFERENCES public.workspaces(id) ON DELETE CASCADE NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 10. nudges (Operational CRM Warnings)
CREATE TABLE public.nudges (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    profile_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    message text NOT NULL,
    severity public.severity_level DEFAULT 'warning'::public.severity_level NOT NULL,
    is_read boolean DEFAULT false NOT NULL,
    workspace_id uuid REFERENCES public.workspaces(id) ON DELETE CASCADE NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 11. cosmo_audits (Cached AI Account Analysis Narratives)
CREATE TABLE public.cosmo_audits (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    contact_id uuid REFERENCES public.contacts(id) ON DELETE CASCADE NOT NULL,
    narrative text NOT NULL,
    severity public.severity_level DEFAULT 'info'::public.severity_level NOT NULL,
    workspace_id uuid REFERENCES public.workspaces(id) ON DELETE CASCADE NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 12. audit_logs (Enterprise Security & Action Logging Ledger - Partitioned)
CREATE TABLE public.audit_logs (
    id uuid DEFAULT gen_random_uuid(),
    workspace_id uuid REFERENCES public.workspaces(id) ON DELETE CASCADE NOT NULL,
    actor_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    actor_name text NOT NULL,
    role public.user_role NOT NULL,
    action text NOT NULL,
    entity_type text NOT NULL,
    entity_id uuid,
    client_ip text,
    user_agent text,
    old_values jsonb,
    new_values jsonb,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

-- Create default initial partition for partition safety
CREATE TABLE public.audit_logs_default PARTITION OF public.audit_logs DEFAULT;

-- 13. contact_assignments (Chronological Ownership Tracking & Transfer History)
CREATE TABLE public.contact_assignments (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    workspace_id uuid REFERENCES public.workspaces(id) ON DELETE CASCADE NOT NULL,
    contact_id uuid REFERENCES public.contacts(id) ON DELETE CASCADE NOT NULL,
    previous_rep_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    new_rep_id uuid REFERENCES public.profiles(id) ON DELETE RESTRICT NOT NULL, -- Fixed foreign key conflict
    assigned_by uuid REFERENCES public.profiles(id) ON DELETE RESTRICT NOT NULL, -- Fixed foreign key conflict
    justification text NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 14. recovery_requests (Fumble Recovery Reassignment Request Claims Board)
CREATE TABLE public.recovery_requests (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    workspace_id uuid REFERENCES public.workspaces(id) ON DELETE CASCADE NOT NULL,
    contact_id uuid REFERENCES public.contacts(id) ON DELETE CASCADE NOT NULL,
    original_rep_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    requester_rep_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL, -- Fixed foreign key conflict
    justification text NOT NULL,
    status public.recovery_status DEFAULT 'pending'::public.recovery_status NOT NULL,
    reviewed_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    rejection_reason text,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT chk_reviewer_is_distinct CHECK (requester_rep_id <> reviewed_by)
);

-- 15. integration_credentials (Encrypted API Connections per Workspace)
CREATE TABLE public.integration_credentials (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    workspace_id uuid REFERENCES public.workspaces(id) ON DELETE CASCADE NOT NULL,
    integration_name text NOT NULL CHECK (integration_name IN (
        'salesforce', 'hubspot', 'zoho', 'pipedrive', 'dynamics',
        'bamboohr', 'workday', 'adp', 'google', 'outlook',
        'slack', 'teams', 'ringcentral', 'zoomphone', 'mcleod', 'tailwind',
        'truckmate', 'roserocket', 'axon'
    )),
    auth_payload jsonb NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(workspace_id, integration_name)
);

-- 16. integration_mappings (External Entity Cross-Mapping Table)
CREATE TABLE public.integration_mappings (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    workspace_id uuid REFERENCES public.workspaces(id) ON DELETE CASCADE NOT NULL,
    local_entity_type text NOT NULL CHECK (local_entity_type IN ('contact', 'organization', 'profile', 'gift')),
    local_entity_id uuid NOT NULL,
    integration_name text NOT NULL,
    external_entity_id text NOT NULL,
    last_synced_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(workspace_id, local_entity_type, local_entity_id, integration_name)
);

-- ============================================================================
-- PERFORMANCE & OPERATIONAL INDEXES (WITH WORKSPACE ISOLATION INDEXES)
-- ============================================================================

-- Workspace isolation indexes (covers all tables for multi-tenant querying)
CREATE INDEX idx_profiles_workspace ON public.profiles(workspace_id);
CREATE INDEX idx_settings_workspace ON public.workspace_settings(workspace_id);
CREATE INDEX idx_orgs_workspace ON public.organizations(workspace_id);
CREATE INDEX idx_contacts_workspace ON public.contacts(workspace_id);
CREATE INDEX idx_activities_workspace ON public.activities(workspace_id);
CREATE INDEX idx_boxes_workspace ON public.boxes(workspace_id);
CREATE INDEX idx_gifts_workspace ON public.gifts(workspace_id);
CREATE INDEX idx_calendar_workspace ON public.calendar_events(workspace_id);
CREATE INDEX idx_nudges_workspace ON public.nudges(workspace_id);
CREATE INDEX idx_cosmo_workspace ON public.cosmo_audits(workspace_id);
CREATE INDEX idx_audit_logs_workspace ON public.audit_logs(workspace_id);
CREATE INDEX idx_assignments_workspace ON public.contact_assignments(workspace_id);
CREATE INDEX idx_requests_workspace ON public.recovery_requests(workspace_id);
CREATE INDEX idx_credentials_workspace ON public.integration_credentials(workspace_id);
CREATE INDEX idx_mappings_workspace ON public.integration_mappings(workspace_id);

-- Gifting pipeline optimization indexes
CREATE INDEX idx_gifts_status ON public.gifts(status);
CREATE INDEX idx_gifts_recipient ON public.gifts(contact_id);
CREATE INDEX idx_gifts_rep ON public.gifts(rep_id);

-- Fumble system & decay indexes
CREATE INDEX idx_contacts_rep_health ON public.contacts(assigned_rep_id, relationship_health);
CREATE INDEX idx_contacts_status ON public.contacts(status);
CREATE INDEX idx_activities_contact_logged ON public.activities(contact_id, logged_at DESC);
CREATE INDEX idx_recovery_requests_status ON public.recovery_requests(status);
CREATE INDEX idx_contact_assignments_contact ON public.contact_assignments(contact_id);

-- Integration & Sync Indexes
CREATE INDEX idx_mappings_local ON public.integration_mappings(local_entity_type, local_entity_id);
CREATE INDEX idx_mappings_external ON public.integration_mappings(integration_name, external_entity_id);
