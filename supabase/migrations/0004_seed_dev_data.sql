-- ============================================================================
-- WHITEBOX RMOS DATABASE SEED SCRIPT (PHASE 4 - LOCAL DEVELOPMENT ONLY)
-- WARNING: THIS MIGRATION IS STRICTLY FOR LOCAL DEVELOPMENT ENVIRONMENTS.
-- DO NOT RUN OR DEPLOY THIS SCRIPT IN STAGING, UAT, OR PRODUCTION ENVIRONMENTS.
-- ALL PASSWORDS IN THIS MIGRATION ARE DETERMINISTIC MOCK DEVELOPMENT CONFIGURATIONS.
-- ============================================================================

-- Wrap in a single transaction for safety
BEGIN;

-- ----------------------------------------------------------------------------
-- 0. TEMPORARY TRIGGER LOCKOUTS & BYPASSES
-- ----------------------------------------------------------------------------
-- Redefine handle_new_user() temporarily to prevent automatic profile creation
-- when seeding auth.users directly. This avoids duplicate key violations and circular triggers.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Disable role checks on profiles (allowed under postgres role)
ALTER TABLE public.profiles DISABLE TRIGGER check_role_escalation;

-- ----------------------------------------------------------------------------
-- 1. SEED WORKSPACES & SETTINGS
-- ----------------------------------------------------------------------------
-- Live Default Workspace UUID and Tenant 2 Workspace UUID for RLS Testing
DO $$
DECLARE
    ws1_id uuid := 'd9b0a1a0-0000-0000-0000-000000000001';
    ws2_id uuid := 'd9b0a1a0-0000-0000-0000-000000000002';
BEGIN
    -- Workspace 1: Default (Renaming to business-facing name if it exists, or inserting)
    INSERT INTO public.workspaces (id, name, subdomain, logo_url, theme)
    VALUES (
        ws1_id,
        'WhiteBox Giftworks',
        'hq',
        'https://whiteboxworks.com/assets/logo.png',
        '{"primary": "#1E293B", "secondary": "#64748B"}'::jsonb
    ) ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;

    -- Workspace 2: Cross-Tenant Isolation Test Workspace
    INSERT INTO public.workspaces (id, name, subdomain, logo_url, theme)
    VALUES (
        ws2_id,
        'Cross-Tenant Test Corp',
        'crosstenant',
        'https://app.whiteboxworks.com/assets/logo-whitebox.png',
        '{"primary": "#ef4444", "dark_mode": true}'::jsonb
    ) ON CONFLICT (id) DO NOTHING;

    -- Settings for Workspace 1
    INSERT INTO public.workspace_settings (
        workspace_id, decay_warning, decay_critical, decay_factor, target_conversion,
        hours_start, hours_end, nudge_cap, auto_neglect, manager_override, alert_routing,
        budget_milestone, budget_monthly, approval_gate, approval_threshold, auto_gifting,
        webhook_slack, webhook_teams, integrations
    )
    VALUES (
        ws1_id, 30, 60, 1.50, 48,
        '09:00:00', '17:00:00', 5, true, true, true,
        45.00, 500.00, true, 100.00, true,
        'https://hooks.slack.com/services/mock_slack_webhook',
        'https://outlook.office.com/webhook/mock_teams_webhook',
        '{"salesforce":false,"hubspot":false,"twilio":false,"ringcentral":false,"gmail":false,"outlook":false}'::jsonb
    ) ON CONFLICT (workspace_id) DO NOTHING;

    -- Settings for Workspace 2
    INSERT INTO public.workspace_settings (
        workspace_id, decay_warning, decay_critical, decay_factor, target_conversion,
        hours_start, hours_end, nudge_cap, auto_neglect, manager_override, alert_routing,
        budget_milestone, budget_monthly, approval_gate, approval_threshold, auto_gifting,
        webhook_slack, webhook_teams, integrations
    )
    VALUES (
        ws2_id, 30, 60, 1.50, 48,
        '09:00:00', '17:00:00', 5, true, true, true,
        45.00, 500.00, true, 100.00, true,
        'https://hooks.slack.com/services/mock_slack_webhook2',
        'https://outlook.office.com/webhook/mock_teams_webhook2',
        '{"salesforce":false,"hubspot":false,"twilio":false,"ringcentral":false,"gmail":false,"outlook":false}'::jsonb
    ) ON CONFLICT (workspace_id) DO NOTHING;
END;
$$;

-- ----------------------------------------------------------------------------
-- 2. SEED BOXES (PRODUCT DIRECTORY CATALOG)
-- ----------------------------------------------------------------------------
INSERT INTO public.boxes (id, workspace_id, name, description, theme_color, price, is_active)
VALUES 
    ('9b1933c0-0f0e-4361-b472-3c8cfa2b9821', 'd9b0a1a0-0000-0000-0000-000000000001', 'Sweet Box', 'Premium assortment of cookies and confections.', '#fbbf24', 90.00, true),
    ('9b1933c0-0f0e-4361-b472-3c8cfa2b9822', 'd9b0a1a0-0000-0000-0000-000000000001', 'Pack Box', 'Shared corporate confectionery snack pack.', '#3b82f6', 80.00, true),
    ('9b1933c0-0f0e-4361-b472-3c8cfa2b9823', 'd9b0a1a0-0000-0000-0000-000000000001', 'Premium Box', 'Luxury chocolate collections and premium branded gifts.', '#8b5cf6', 300.00, true),
    -- Box for Workspace 2
    ('9b1933c0-0f0e-4361-b472-3c8cfa2b9921', 'd9b0a1a0-0000-0000-0000-000000000002', 'Tenant2 Sweet Box', 'Bespoke corporate sweets for Tenant 2.', '#10b981', 120.00, true)
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 3. SEED AUTH USERS & PROFILES (ROLE HIERARCHY PRESERVING)
-- Passwords are intentionally seeded as NULL — NO shared/default credential is
-- shipped in source control. On a fresh database, provision each login via the
-- in-app password-reset flow (/forgot-password) or scripts/rotate-auth-passwords.mjs.
-- (Historically this seeded one shared bcrypt hash for all users; that shared
-- demo password has been retired — see the 2d auth work — and removed here.)
-- ----------------------------------------------------------------------------
-- 3.1. Insert auth.users (confirmed_at is generated, so it is omitted here)
INSERT INTO auth.users (
    id, email, encrypted_password, email_confirmed_at, 
    raw_user_meta_data, raw_app_meta_data, is_super_admin, aud, role, 
    is_sso_user, is_anonymous, created_at, updated_at, instance_id
)
VALUES
    -- Workspace 1 Users
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9801', 'owner@whitebox.com', NULL, now(), '{"name": "Paul K.", "role": "owner"}'::jsonb, '{"provider": "email", "providers": ["email"]}'::jsonb, false, 'authenticated', 'authenticated', false, false, now(), now(), '00000000-0000-0000-0000-000000000000'::uuid),
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9802', 'g.sterling@whitebox.com', NULL, now(), '{"name": "Gregory Sterling", "role": "executive"}'::jsonb, '{"provider": "email", "providers": ["email"]}'::jsonb, false, 'authenticated', 'authenticated', false, false, now(), now(), '00000000-0000-0000-0000-000000000000'::uuid),
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9803', 'executive@whitebox.com', NULL, now(), '{"name": "Sarah Lansky", "role": "executive"}'::jsonb, '{"provider": "email", "providers": ["email"]}'::jsonb, false, 'authenticated', 'authenticated', false, false, now(), now(), '00000000-0000-0000-0000-000000000000'::uuid),
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9804', 'e.davis@whitebox.com', NULL, now(), '{"name": "Emily Davis", "role": "executive"}'::jsonb, '{"provider": "email", "providers": ["email"]}'::jsonb, false, 'authenticated', 'authenticated', false, false, now(), now(), '00000000-0000-0000-0000-000000000000'::uuid),
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9805', 'manager@whitebox.com', NULL, now(), '{"name": "Marcus Dupond", "role": "manager"}'::jsonb, '{"provider": "email", "providers": ["email"]}'::jsonb, false, 'authenticated', 'authenticated', false, false, now(), now(), '00000000-0000-0000-0000-000000000000'::uuid),
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9806', 'j.smith@whitebox.com', NULL, now(), '{"name": "Jane Smith", "role": "manager"}'::jsonb, '{"provider": "email", "providers": ["email"]}'::jsonb, false, 'authenticated', 'authenticated', false, false, now(), now(), '00000000-0000-0000-0000-000000000000'::uuid),
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9807', 'rep@whitebox.com', NULL, now(), '{"name": "Tom Collins", "role": "rep"}'::jsonb, '{"provider": "email", "providers": ["email"]}'::jsonb, false, 'authenticated', 'authenticated', false, false, now(), now(), '00000000-0000-0000-0000-000000000000'::uuid),
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9808', 'd.schrute@whitebox.com', NULL, now(), '{"name": "Dwight Schrute", "role": "rep"}'::jsonb, '{"provider": "email", "providers": ["email"]}'::jsonb, false, 'authenticated', 'authenticated', false, false, now(), now(), '00000000-0000-0000-0000-000000000000'::uuid),
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9809', 'j.doe@whitebox.com', NULL, now(), '{"name": "John Doe", "role": "rep"}'::jsonb, '{"provider": "email", "providers": ["email"]}'::jsonb, false, 'authenticated', 'authenticated', false, false, now(), now(), '00000000-0000-0000-0000-000000000000'::uuid),
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9810', 'a.cooper@whitebox.com', NULL, now(), '{"name": "Alice Cooper", "role": "rep"}'::jsonb, '{"provider": "email", "providers": ["email"]}'::jsonb, false, 'authenticated', 'authenticated', false, false, now(), now(), '00000000-0000-0000-0000-000000000000'::uuid),
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9811', 'b.martin@whitebox.com', NULL, now(), '{"name": "Bob Martin", "role": "rep"}'::jsonb, '{"provider": "email", "providers": ["email"]}'::jsonb, false, 'authenticated', 'authenticated', false, false, now(), now(), '00000000-0000-0000-0000-000000000000'::uuid),
    -- Charlie Brown is seeded as a test case for RLS exclusion (Revoked profile)
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9812', 'c.brown@whitebox.com', NULL, now(), '{"name": "Charlie Brown", "role": "rep"}'::jsonb, '{"provider": "email", "providers": ["email"]}'::jsonb, false, 'authenticated', 'authenticated', false, false, now(), now(), '00000000-0000-0000-0000-000000000000'::uuid),

    -- Workspace 2 Users
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9999', 'eve.tenant@whitebox.com', NULL, now(), '{"name": "Eve Tenant", "role": "rep"}'::jsonb, '{"provider": "email", "providers": ["email"]}'::jsonb, false, 'authenticated', 'authenticated', false, false, now(), now(), '00000000-0000-0000-0000-000000000000'::uuid)
ON CONFLICT (id) DO NOTHING;

-- 3.2. Insert public.profiles (Recreating hierarchy tree mapped to workspaces)
INSERT INTO public.profiles (id, email, name, role, workspace_id, manager_id, avatar_url, status)
VALUES
    -- Workspace 1 Profiles
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9801', 'owner@whitebox.com', 'Paul K.', 'owner', 'd9b0a1a0-0000-0000-0000-000000000001', NULL, NULL, 'active'),
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9802', 'g.sterling@whitebox.com', 'Gregory Sterling', 'executive', 'd9b0a1a0-0000-0000-0000-000000000001', NULL, NULL, 'active'),
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9803', 'executive@whitebox.com', 'Sarah Lansky', 'executive', 'd9b0a1a0-0000-0000-0000-000000000001', '8b1933c0-0f0e-4361-b472-3c8cfa2b9802', NULL, 'active'),
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9804', 'e.davis@whitebox.com', 'Emily Davis', 'executive', 'd9b0a1a0-0000-0000-0000-000000000001', '8b1933c0-0f0e-4361-b472-3c8cfa2b9803', NULL, 'active'),
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9805', 'manager@whitebox.com', 'Marcus Dupond', 'manager', 'd9b0a1a0-0000-0000-0000-000000000001', '8b1933c0-0f0e-4361-b472-3c8cfa2b9801', NULL, 'active'),
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9806', 'j.smith@whitebox.com', 'Jane Smith', 'manager', 'd9b0a1a0-0000-0000-0000-000000000001', '8b1933c0-0f0e-4361-b472-3c8cfa2b9801', NULL, 'active'),
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9807', 'rep@whitebox.com', 'Tom Collins', 'rep', 'd9b0a1a0-0000-0000-0000-000000000001', '8b1933c0-0f0e-4361-b472-3c8cfa2b9805', NULL, 'active'),
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9808', 'd.schrute@whitebox.com', 'Dwight Schrute', 'rep', 'd9b0a1a0-0000-0000-0000-000000000001', '8b1933c0-0f0e-4361-b472-3c8cfa2b9805', NULL, 'active'),
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9809', 'j.doe@whitebox.com', 'John Doe', 'rep', 'd9b0a1a0-0000-0000-0000-000000000001', '8b1933c0-0f0e-4361-b472-3c8cfa2b9805', NULL, 'active'),
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9810', 'a.cooper@whitebox.com', 'Alice Cooper', 'rep', 'd9b0a1a0-0000-0000-0000-000000000001', '8b1933c0-0f0e-4361-b472-3c8cfa2b9804', NULL, 'active'),
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9811', 'b.martin@whitebox.com', 'Bob Martin', 'rep', 'd9b0a1a0-0000-0000-0000-000000000001', '8b1933c0-0f0e-4361-b472-3c8cfa2b9804', NULL, 'active'),
    -- Charlie Brown is seeded as 'revoked' status (revoked user RLS test case)
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9812', 'c.brown@whitebox.com', 'Charlie Brown', 'rep', 'd9b0a1a0-0000-0000-0000-000000000001', '8b1933c0-0f0e-4361-b472-3c8cfa2b9804', NULL, 'revoked'),

    -- Workspace 2 Profiles
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9999', 'eve.tenant@whitebox.com', 'Eve Tenant', 'rep', 'd9b0a1a0-0000-0000-0000-000000000002', NULL, NULL, 'active')
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 4. SEED ORGANIZATIONS
-- ----------------------------------------------------------------------------
INSERT INTO public.organizations (id, name, sector, category, workspace_id)
VALUES
    -- Workspace 1 Organizations
    ('3c1933c0-0f0e-4361-b472-3c8cfa2b9831', 'Apex Global Retail', 'Enterprise B2B', 'enterprise', 'd9b0a1a0-0000-0000-0000-000000000001'),
    ('3c1933c0-0f0e-4361-b472-3c8cfa2b9832', 'Chevron Solutions', 'Enterprise B2B', 'enterprise', 'd9b0a1a0-0000-0000-0000-000000000001'),
    ('3c1933c0-0f0e-4361-b472-3c8cfa2b9833', 'Initech Software', 'Enterprise B2B', 'smb', 'd9b0a1a0-0000-0000-0000-000000000001'),
    ('3c1933c0-0f0e-4361-b472-3c8cfa2b9834', 'Wayne Enterprises', 'Enterprise B2B', 'enterprise', 'd9b0a1a0-0000-0000-0000-000000000001'),
    ('3c1933c0-0f0e-4361-b472-3c8cfa2b9835', 'Stark Industries', 'Enterprise B2B', 'enterprise', 'd9b0a1a0-0000-0000-0000-000000000001'),
    ('3c1933c0-0f0e-4361-b472-3c8cfa2b9836', 'Tyrell Corporation', 'Enterprise B2B', 'enterprise', 'd9b0a1a0-0000-0000-0000-000000000001'),
    ('3c1933c0-0f0e-4361-b472-3c8cfa2b9837', 'Apex Systems', 'Prospect', 'prospect', 'd9b0a1a0-0000-0000-0000-000000000001'),
    ('3c1933c0-0f0e-4361-b472-3c8cfa2b9838', 'Zenith Corp', 'Prospect', 'prospect', 'd9b0a1a0-0000-0000-0000-000000000001'),
    ('3c1933c0-0f0e-4361-b472-3c8cfa2b9839', 'Vanguard Health', 'Prospect', 'prospect', 'd9b0a1a0-0000-0000-0000-000000000001'),
    ('3c1933c0-0f0e-4361-b472-3c8cfa2b9840', 'OmniCorp', 'Prospect', 'prospect', 'd9b0a1a0-0000-0000-0000-000000000001'),
    ('3c1933c0-0f0e-4361-b472-3c8cfa2b9841', 'Chevron Logistics', 'Prospect', 'prospect', 'd9b0a1a0-0000-0000-0000-000000000001'),
    ('3c1933c0-0f0e-4361-b472-3c8cfa2b9842', 'TechFlow Inc', 'Prospect', 'prospect', 'd9b0a1a0-0000-0000-0000-000000000001'),
    ('3c1933c0-0f0e-4361-b472-3c8cfa2b9843', 'Pinnacle Brands', 'Enterprise B2B', 'smb', 'd9b0a1a0-0000-0000-0000-000000000001'),
    ('3c1933c0-0f0e-4361-b472-3c8cfa2b9844', 'Orion Biotech', 'Prospect', 'prospect', 'd9b0a1a0-0000-0000-0000-000000000001'),
    ('3c1933c0-0f0e-4361-b472-3c8cfa2b9845', 'Nova Financial', 'Enterprise B2B', 'enterprise', 'd9b0a1a0-0000-0000-0000-000000000001'),
    ('3c1933c0-0f0e-4361-b472-3c8cfa2b9846', 'BlueStar Retail', 'Enterprise B2B', 'smb', 'd9b0a1a0-0000-0000-0000-000000000001'),
    ('3c1933c0-0f0e-4361-b472-3c8cfa2b9847', 'Peak Financial', 'Enterprise B2B', 'enterprise', 'd9b0a1a0-0000-0000-0000-000000000001'),
    ('3c1933c0-0f0e-4361-b472-3c8cfa2b9848', 'Silverline Tech', 'Enterprise B2B', 'smb', 'd9b0a1a0-0000-0000-0000-000000000001'),
    ('3c1933c0-0f0e-4361-b472-3c8cfa2b9849', 'Helix Labs', 'Enterprise B2B', 'smb', 'd9b0a1a0-0000-0000-0000-000000000001'),
    ('3c1933c0-0f0e-4361-b472-3c8cfa2b9850', 'Alpha Digital', 'Enterprise B2B', 'smb', 'd9b0a1a0-0000-0000-0000-000000000001'),
    ('3c1933c0-0f0e-4361-b472-3c8cfa2b9851', 'Quantum Tech', 'Enterprise B2B', 'smb', 'd9b0a1a0-0000-0000-0000-000000000001'),
    
    -- Workspace 2 Organization (Cross-tenant RLS validation)
    ('3c1933c0-0f0e-4361-b472-3c8cfa2b9931', 'Tenant2 Org Ltd', 'Logistics B2B', 'enterprise', 'd9b0a1a0-0000-0000-0000-000000000002')
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 5. SEED CONTACTS (INDIVIDUAL CLIENTS ASSIGNED TO REPS)
-- Note: Mapped contact assigned_rep_id ONLY to active rep profiles (Correction 5).
-- Contacts are scoped strictly to their respective workspace.
-- ----------------------------------------------------------------------------
INSERT INTO public.contacts (id, org_id, name, email, phone, assigned_rep_id, status, relationship_health, ai_recommendation, workspace_id)
VALUES
    -- Workspace 1 Contacts
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9861', '3c1933c0-0f0e-4361-b472-3c8cfa2b9831', 'Apex Global CS', 'cs@apexglobal.com', '(800) 555-0101', '8b1933c0-0f0e-4361-b472-3c8cfa2b9810', 'active', 96, 'Schedule quarterly check-in sync', 'd9b0a1a0-0000-0000-0000-000000000001'),
    -- Changed assigned_rep_id from Marcus (manager) to Dwight Schrute (rep)
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9862', '3c1933c0-0f0e-4361-b472-3c8cfa2b9832', 'Chevron Operations', 'ops@chevron.com', '(800) 555-0102', '8b1933c0-0f0e-4361-b472-3c8cfa2b9808', 'active', 98, 'Send milestone appreciation box', 'd9b0a1a0-0000-0000-0000-000000000001'),
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9863', '3c1933c0-0f0e-4361-b472-3c8cfa2b9833', 'Ted Initech', 'ted@initech.com', '(512) 555-0133', '8b1933c0-0f0e-4361-b472-3c8cfa2b9807', 'active', 74, 'Recommend Sweet Box to warm relationship', 'd9b0a1a0-0000-0000-0000-000000000001'),
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9864', '3c1933c0-0f0e-4361-b472-3c8cfa2b9834', 'Bruce Wayne', 'bruce@wayne.com', '(607) 555-0144', '8b1933c0-0f0e-4361-b472-3c8cfa2b9808', 'active', 98, 'Verify Premium Executive Box arrival', 'd9b0a1a0-0000-0000-0000-000000000001'),
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9865', '3c1933c0-0f0e-4361-b472-3c8cfa2b9835', 'Pepper Potts', 'pepper@stark.com', '(212) 555-0199', '8b1933c0-0f0e-4361-b472-3c8cfa2b9809', 'active', 98, 'Log quarterly alignment notes', 'd9b0a1a0-0000-0000-0000-000000000001'),
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9866', '3c1933c0-0f0e-4361-b472-3c8cfa2b9836', 'Eldon Tyrell', 'tyrell@tyrell.com', '(213) 555-0160', '8b1933c0-0f0e-4361-b472-3c8cfa2b9811', 'neglected', 38, 'Critical neglect risk: schedule call', 'd9b0a1a0-0000-0000-0000-000000000001'),
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9867', '3c1933c0-0f0e-4361-b472-3c8cfa2b9837', 'Apex Pipeline', 'pipeline@apex.com', '(800) 555-0177', '8b1933c0-0f0e-4361-b472-3c8cfa2b9810', 'active', 74, 'Send Outbound Prospect Nudge', 'd9b0a1a0-0000-0000-0000-000000000001'),
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9868', '3c1933c0-0f0e-4361-b472-3c8cfa2b9838', 'Zenith Lead', 'lead@zenith.com', '(206) 555-0180', '8b1933c0-0f0e-4361-b472-3c8cfa2b9807', 'active', 74, 'Send automated introductory catalog', 'd9b0a1a0-0000-0000-0000-000000000001'),
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9869', '3c1933c0-0f0e-4361-b472-3c8cfa2b9839', 'Vanguard Admin', 'admin@vanguard.com', '(312) 555-0199', '8b1933c0-0f0e-4361-b472-3c8cfa2b9808', 'neglected', 0, 'Reassign account ownership: 84 days quiet', 'd9b0a1a0-0000-0000-0000-000000000001'),
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9870', '3c1933c0-0f0e-4361-b472-3c8cfa2b9840', 'Omni Lead', 'info@omnicorp.com', '(800) 555-0122', '8b1933c0-0f0e-4361-b472-3c8cfa2b9809', 'active', 74, 'Log follow up call request', 'd9b0a1a0-0000-0000-0000-000000000001'),
    -- Changed assigned_rep_id from Marcus (manager) to Tom Collins (rep)
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9871', '3c1933c0-0f0e-4361-b472-3c8cfa2b9841', 'Chevron Logistics CS', 'ops@chevronlogistics.com', '(800) 555-0155', '8b1933c0-0f0e-4361-b472-3c8cfa2b9807', 'neglected', 54, 'Exceeded warning limit: trigger recovery', 'd9b0a1a0-0000-0000-0000-000000000001'),
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9872', '3c1933c0-0f0e-4361-b472-3c8cfa2b9842', 'TechFlow Contact', 'ops@techflow.com', '(800) 555-0166', '8b1933c0-0f0e-4361-b472-3c8cfa2b9811', 'active', 74, 'Send Sweet Box for outreach', 'd9b0a1a0-0000-0000-0000-000000000001'),
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9873', '3c1933c0-0f0e-4361-b472-3c8cfa2b9843', 'Lisa Kudrow', 'sales@pinnacle.com', '(213) 555-0177', '8b1933c0-0f0e-4361-b472-3c8cfa2b9807', 'neglected', 62, 'Decayed health: send Premium Box', 'd9b0a1a0-0000-0000-0000-000000000001'),
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9874', '3c1933c0-0f0e-4361-b472-3c8cfa2b9844', 'Dr. Robert Vance', 'rnd@orion.com', '(617) 555-0167', '8b1933c0-0f0e-4361-b472-3c8cfa2b9807', 'neglected', 54, 'Critical neglect: reassign request', 'd9b0a1a0-0000-0000-0000-000000000001'),
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9875', '3c1933c0-0f0e-4361-b472-3c8cfa2b9845', 'Dr. Aris', 'admin@nova.com', '(206) 555-0144', '8b1933c0-0f0e-4361-b472-3c8cfa2b9807', 'active', 74, 'Send Remember Premium Box', 'd9b0a1a0-0000-0000-0000-000000000001'),
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9876', '3c1933c0-0f0e-4361-b472-3c8cfa2b9846', 'BlueStar CS', 'buyer@bluestar.com', '(800) 555-0188', '8b1933c0-0f0e-4361-b472-3c8cfa2b9807', 'active', 90, 'Verify Sweet Box Anniversary reception', 'd9b0a1a0-0000-0000-0000-000000000001'),
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9877', '3c1933c0-0f0e-4361-b472-3c8cfa2b9847', 'Peak Finance Rep', 'billing@peakfinancial.com', '(800) 555-0199', '8b1933c0-0f0e-4361-b472-3c8cfa2b9807', 'active', 85, 'Awaiting Custom Box design layout', 'd9b0a1a0-0000-0000-0000-000000000001'),
    -- Changed assigned_rep_id from Marcus (manager) to Tom Collins (rep)
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9878', '3c1933c0-0f0e-4361-b472-3c8cfa2b9848', 'Silverline Rep', 'ops@silverlinetech.com', '(800) 555-0211', '8b1933c0-0f0e-4361-b472-3c8cfa2b9807', 'active', 92, 'Check Sweet Box Anniversary status', 'd9b0a1a0-0000-0000-0000-000000000001'),
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9879', '3c1933c0-0f0e-4361-b472-3c8cfa2b9849', 'Helix Labs Ops', 'team@helixlabs.com', '(800) 555-0222', '8b1933c0-0f0e-4361-b472-3c8cfa2b9807', 'active', 90, 'Milestone celebration complete', 'd9b0a1a0-0000-0000-0000-000000000001'),
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9880', '3c1933c0-0f0e-4361-b472-3c8cfa2b9850', 'Alpha Dig Lead', 'marketing@alphadigital.com', '(800) 555-0233', '8b1933c0-0f0e-4361-b472-3c8cfa2b9807', 'active', 95, 'Verify cold warming campaign complete', 'd9b0a1a0-0000-0000-0000-000000000001'),
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9881', '3c1933c0-0f0e-4361-b472-3c8cfa2b9851', 'Quantum Eng Lead', 'eng@quantumtech.com', '(800) 555-0244', '8b1933c0-0f0e-4361-b472-3c8cfa2b9807', 'active', 90, 'Engineering Nudge sweet box confirmed', 'd9b0a1a0-0000-0000-0000-000000000001'),

    -- Workspace 2 Contact
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9961', '3c1933c0-0f0e-4361-b472-3c8cfa2b9931', 'Tenant2 Contact', 'tenant2@contact.com', '(800) 555-9999', '8b1933c0-0f0e-4361-b472-3c8cfa2b9999', 'active', 92, 'First touchpoint complete', 'd9b0a1a0-0000-0000-0000-000000000002')
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 6. SEED CRM ACTIVITIES (DETERMINISTIC UUIDS AND ON CONFLICT id SAFE)
-- ----------------------------------------------------------------------------
INSERT INTO public.activities (id, contact_id, rep_id, type, grade, notes, workspace_id, logged_at)
VALUES
    -- Workspace 1 Activities
    ('a11933c0-0f0e-4361-b472-3c8cfa2b9801', '5d1933c0-0f0e-4361-b472-3c8cfa2b9861', '8b1933c0-0f0e-4361-b472-3c8cfa2b9803', 'Call', 'A', 'Discussed Q2 renewal pipeline with procurement VP.', 'd9b0a1a0-0000-0000-0000-000000000001', now() - INTERVAL '5 days'),
    ('a11933c0-0f0e-4361-b472-3c8cfa2b9802', '5d1933c0-0f0e-4361-b472-3c8cfa2b9861', '8b1933c0-0f0e-4361-b472-3c8cfa2b9803', 'Email', 'A', 'Follow-up on signed agreement. Shared fulfillment timeline.', 'd9b0a1a0-0000-0000-0000-000000000001', now() - INTERVAL '10 days'),
    ('a11933c0-0f0e-4361-b472-3c8cfa2b9803', '5d1933c0-0f0e-4361-b472-3c8cfa2b9862', '8b1933c0-0f0e-4361-b472-3c8cfa2b9805', 'Meeting', 'A', 'Onsite B2B strategic review with regional leadership.', 'd9b0a1a0-0000-0000-0000-000000000001', now() - INTERVAL '12 days'),
    ('a11933c0-0f0e-4361-b472-3c8cfa2b9804', '5d1933c0-0f0e-4361-b472-3c8cfa2b9869', '8b1933c0-0f0e-4361-b472-3c8cfa2b9808', 'Call', 'C', 'Voicemail left with administrative supervisor.', 'd9b0a1a0-0000-0000-0000-000000000001', now() - INTERVAL '84 days'),
    ('a11933c0-0f0e-4361-b472-3c8cfa2b9805', '5d1933c0-0f0e-4361-b472-3c8cfa2b9874', '8b1933c0-0f0e-4361-b472-3c8cfa2b9807', 'Email', 'C', 'Routine touchpoint regarding pricing catalogs.', 'd9b0a1a0-0000-0000-0000-000000000001', now() - INTERVAL '64 days'),
    ('a11933c0-0f0e-4361-b472-3c8cfa2b9806', '5d1933c0-0f0e-4361-b472-3c8cfa2b9871', '8b1933c0-0f0e-4361-b472-3c8cfa2b9805', 'Call', 'D', 'Brief callback, contact requested email updates next month.', 'd9b0a1a0-0000-0000-0000-000000000001', now() - INTERVAL '42 days'),
    ('a11933c0-0f0e-4361-b472-3c8cfa2b9807', '5d1933c0-0f0e-4361-b472-3c8cfa2b9873', '8b1933c0-0f0e-4361-b472-3c8cfa2b9807', 'Call', 'C', 'Follow-up regarding B2B contract terms, no signature yet.', 'd9b0a1a0-0000-0000-0000-000000000001', now() - INTERVAL '68 days'),
    ('a11933c0-0f0e-4361-b472-3c8cfa2b9808', '5d1933c0-0f0e-4361-b472-3c8cfa2b9863', '8b1933c0-0f0e-4361-b472-3c8cfa2b9807', 'Meeting', 'B', 'Client sync: discussed Q2 billing changes.', 'd9b0a1a0-0000-0000-0000-000000000001', now() - INTERVAL '3 days'),
    ('a11933c0-0f0e-4361-b472-3c8cfa2b9809', '5d1933c0-0f0e-4361-b472-3c8cfa2b9864', '8b1933c0-0f0e-4361-b472-3c8cfa2b9808', 'Meeting', 'A', 'Met with director regarding enterprise confections proposal.', 'd9b0a1a0-0000-0000-0000-000000000001', now() - INTERVAL '6 days'),
    
    -- Workspace 2 Activity (Cross-tenant RLS validation)
    ('a11933c0-0f0e-4361-b472-3c8cfa2b9901', '5d1933c0-0f0e-4361-b472-3c8cfa2b9961', '8b1933c0-0f0e-4361-b472-3c8cfa2b9999', 'Call', 'B', 'Introduction call with Tenant 2 contact.', 'd9b0a1a0-0000-0000-0000-000000000002', now() - INTERVAL '1 day')
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 7. SEED GIFTS & ACTIVE ORDERS (DECOUPLED HISTORICAL PRICING, DETERMINISTIC UUIDS)
-- ----------------------------------------------------------------------------
INSERT INTO public.gifts (id, contact_id, rep_id, box_id, category, amount, status, shipping_street, shipping_city, shipping_province, shipping_postal, carrier, tracking_number, sender_label, reason, workspace_id, dispatched_at)
VALUES
    -- Workspace 1 Gifts
    ('7b1933c0-0f0e-4361-b472-3c8cfa2b9801', '5d1933c0-0f0e-4361-b472-3c8cfa2b9862', '8b1933c0-0f0e-4361-b472-3c8cfa2b9805', '9b1933c0-0f0e-4361-b472-3c8cfa2b9821', 'reward', 90.00, 'delivered', '200 Main St', 'Detroit', 'MI', '48226', 'FedEx', '987654321011', 'Marcus Dupond (Manager)', 'Employee Milestone: May B2B Sales Volume Record', 'd9b0a1a0-0000-0000-0000-000000000001', now() - INTERVAL '10 days'),
    ('7b1933c0-0f0e-4361-b472-3c8cfa2b9802', '5d1933c0-0f0e-4361-b472-3c8cfa2b9875', '8b1933c0-0f0e-4361-b472-3c8cfa2b9805', '9b1933c0-0f0e-4361-b472-3c8cfa2b9821', 'remember', 90.00, 'delivered', '500 Finance Blvd', 'Boston', 'MA', '02109', 'UPS', '1Z9A29810300123456', 'Marcus Dupond (Manager)', 'Employee Birthday Recognition', 'd9b0a1a0-0000-0000-0000-000000000001', now() - INTERVAL '7 days'),
    ('7b1933c0-0f0e-4361-b472-3c8cfa2b9803', '5d1933c0-0f0e-4361-b472-3c8cfa2b9861', '8b1933c0-0f0e-4361-b472-3c8cfa2b9805', '9b1933c0-0f0e-4361-b472-3c8cfa2b9823', 'reward', 300.00, 'delivered', '99 Brand St', 'Los Angeles', 'CA', '90015', 'FedEx', '987654321012', 'Marcus Dupond (Manager)', 'CEO Excellence Award: HR System Deployment', 'd9b0a1a0-0000-0000-0000-000000000001', now() - INTERVAL '6 days'),
    ('7b1933c0-0f0e-4361-b472-3c8cfa2b9804', '5d1933c0-0f0e-4361-b472-3c8cfa2b9876', '8b1933c0-0f0e-4361-b472-3c8cfa2b9807', '9b1933c0-0f0e-4361-b472-3c8cfa2b9821', 'retain', 90.00, 'delivered', '78 Retail Way', 'Seattle', 'WA', '98101', 'UPS', '1Z9A29810300123457', 'Tom Collins (Rep)', 'Customer Retention: Contract Anniversary', 'd9b0a1a0-0000-0000-0000-000000000001', now() - INTERVAL '6 days'),
    ('7b1933c0-0f0e-4361-b472-3c8cfa2b9805', '5d1933c0-0f0e-4361-b472-3c8cfa2b9862', '8b1933c0-0f0e-4361-b472-3c8cfa2b9805', '9b1933c0-0f0e-4361-b472-3c8cfa2b9822', 'reward', 80.00, 'delivered', '200 Main St', 'Detroit', 'MI', '48226', 'FedEx', '987654321013', 'Marcus Dupond (Manager)', 'Team Celebration: Q1 Operations Target Met', 'd9b0a1a0-0000-0000-0000-000000000001', now() - INTERVAL '9 days'),
    ('7b1933c0-0f0e-4361-b472-3c8cfa2b9806', '5d1933c0-0f0e-4361-b472-3c8cfa2b9868', '8b1933c0-0f0e-4361-b472-3c8cfa2b9801', '9b1933c0-0f0e-4361-b472-3c8cfa2b9823', 'reach', 300.00, 'delivered', '206 Lead St', 'Seattle', 'WA', '98101', 'UPS', '1Z9A29810300123458', 'AI Automated Engine', 'Executive Outreach: Cold Account Warming', 'd9b0a1a0-0000-0000-0000-000000000001', now() - INTERVAL '8 days'),
    ('7b1933c0-0f0e-4361-b472-3c8cfa2b9807', '5d1933c0-0f0e-4361-b472-3c8cfa2b9878', '8b1933c0-0f0e-4361-b472-3c8cfa2b9805', '9b1933c0-0f0e-4361-b472-3c8cfa2b9822', 'retain', 80.00, 'delivered', '800 Tech Rd', 'San Francisco', 'CA', '94107', 'UPS', '1Z9A29810300123459', 'Marcus Dupond (Manager)', 'Customer Success: 3-Year Enterprise Anniversary', 'd9b0a1a0-0000-0000-0000-000000000001', now() - INTERVAL '7 days'),
    ('7b1933c0-0f0e-4361-b472-3c8cfa2b9808', '5d1933c0-0f0e-4361-b472-3c8cfa2b9879', '8b1933c0-0f0e-4361-b472-3c8cfa2b9801', '9b1933c0-0f0e-4361-b472-3c8cfa2b9822', 'remember', 80.00, 'delivered', '222 Helix Way', 'Cambridge', 'MA', '02139', 'FedEx', '987654321014', 'AI Automated Engine', 'Partner Founding Anniversary', 'd9b0a1a0-0000-0000-0000-000000000001', now() - INTERVAL '5 days'),
    ('7b1933c0-0f0e-4361-b472-3c8cfa2b9809', '5d1933c0-0f0e-4361-b472-3c8cfa2b9880', '8b1933c0-0f0e-4361-b472-3c8cfa2b9801', '9b1933c0-0f0e-4361-b472-3c8cfa2b9823', 'reach', 300.00, 'delivered', '300 Alpha Plaza', 'Denver', 'CO', '80202', 'FedEx', '987654321015', 'AI Automated Engine', 'Executive Branding campaign', 'd9b0a1a0-0000-0000-0000-000000000001', now() - INTERVAL '4 days'),
    ('7b1933c0-0f0e-4361-b472-3c8cfa2b9810', '5d1933c0-0f0e-4361-b472-3c8cfa2b9881', '8b1933c0-0f0e-4361-b472-3c8cfa2b9801', '9b1933c0-0f0e-4361-b472-3c8cfa2b9822', 'reach', 80.00, 'delivered', '101 Quantum Rd', 'Austin', 'TX', '78701', 'UPS', '1Z9A29810300123460', 'AI Automated Engine', 'Engineering Lead Nudge', 'd9b0a1a0-0000-0000-0000-000000000001', now() - INTERVAL '3 days'),
    ('6f1933c0-0f0e-4361-b472-3c8cfa2b9891', '5d1933c0-0f0e-4361-b472-3c8cfa2b9867', '8b1933c0-0f0e-4361-b472-3c8cfa2b9801', '9b1933c0-0f0e-4361-b472-3c8cfa2b9821', 'reach', 90.00, 'pending', '100 Tech Way', 'San Jose', 'CA', '95112', NULL, NULL, 'AI Automated Engine', 'Outbound Pipeline: Warm Prospect Nudge', 'd9b0a1a0-0000-0000-0000-000000000001', NULL),
    ('6f1933c0-0f0e-4361-b472-3c8cfa2b9892', '5d1933c0-0f0e-4361-b472-3c8cfa2b9877', '8b1933c0-0f0e-4361-b472-3c8cfa2b9807', '9b1933c0-0f0e-4361-b472-3c8cfa2b9823', 'retain', 300.00, 'awaiting_design', '44 Financial Dr', 'New York', 'NY', '10005', NULL, NULL, 'Tom Collins (Rep)', 'Contract renewal appreciation', 'd9b0a1a0-0000-0000-0000-000000000001', NULL),
    ('6f1933c0-0f0e-4361-b472-3c8cfa2b9893', '5d1933c0-0f0e-4361-b472-3c8cfa2b9875', '8b1933c0-0f0e-4361-b472-3c8cfa2b9801', '9b1933c0-0f0e-4361-b472-3c8cfa2b9823', 'remember', 300.00, 'quote_ready', '200 Health Ave', 'Seattle', 'WA', '98104', NULL, NULL, 'AI Automated Engine', 'B2B Relationship Anniversary', 'd9b0a1a0-0000-0000-0000-000000000001', NULL),
    ('6f1933c0-0f0e-4361-b472-3c8cfa2b9894', '5d1933c0-0f0e-4361-b472-3c8cfa2b9871', '8b1933c0-0f0e-4361-b472-3c8cfa2b9807', '9b1933c0-0f0e-4361-b472-3c8cfa2b9822', 'reach', 80.00, 'pending', '78 Logistics Way', 'Chicago', 'IL', '60606', NULL, NULL, 'Tom Collins (Rep)', '1 year partnership anniversary', 'd9b0a1a0-0000-0000-0000-000000000001', NULL),

    -- Workspace 2 Gift (Cross-tenant RLS validation)
    ('7b1933c0-0f0e-4361-b472-3c8cfa2b9901', '5d1933c0-0f0e-4361-b472-3c8cfa2b9961', '8b1933c0-0f0e-4361-b472-3c8cfa2b9999', '9b1933c0-0f0e-4361-b472-3c8cfa2b9921', 'reach', 120.00, 'delivered', '789 Trade St', 'Austin', 'TX', '78701', 'UPS', '1Z9A29810300129999', 'Eve Tenant (Rep)', 'Initial B2B outreach pack', 'd9b0a1a0-0000-0000-0000-000000000002', now() - INTERVAL '1 day')
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 8. SEED CALENDAR EVENTS (DETERMINISTIC UUIDs, ON CONFLICT id SAFE)
-- ----------------------------------------------------------------------------
INSERT INTO public.calendar_events (id, profile_id, type, target, event_date, event_time, agenda, workspace_id)
VALUES
    -- Workspace 1 Calendar Events
    ('c11933c0-0f0e-4361-b472-3c8cfa2b9801', '8b1933c0-0f0e-4361-b472-3c8cfa2b9801', 'Performance Review', 'Tom Collins', '2026-05-27', '10:00:00', 'Review sales pipelines and healthcare account activity. Focus on conversion drop.', 'd9b0a1a0-0000-0000-0000-000000000001'),
    ('c11933c0-0f0e-4361-b472-3c8cfa2b9802', '8b1933c0-0f0e-4361-b472-3c8cfa2b9801', 'Client Strategic Meeting', 'Nova Healthcare', '2026-05-29', '14:30:00', 'Discuss premium confections shipment and Q2 contract renewal.', 'd9b0a1a0-0000-0000-0000-000000000001'),
    ('c11933c0-0f0e-4361-b472-3c8cfa2b9803', '8b1933c0-0f0e-4361-b472-3c8cfa2b9801', 'Performance Review', 'Sarah Lansky', '2026-06-02', '11:00:00', 'HR workflow assessment and workload balance check-in. Sentiment is high risk.', 'd9b0a1a0-0000-0000-0000-000000000001'),
    ('c11933c0-0f0e-4361-b472-3c8cfa2b9804', '8b1933c0-0f0e-4361-b472-3c8cfa2b9801', 'Milestone Gift Delivery', 'Aero Dynamics', '2026-06-05', '13:00:00', 'Verify VIP customer anniversary sweet box reception.', 'd9b0a1a0-0000-0000-0000-000000000001'),
    
    -- Workspace 2 Calendar Event
    ('c11933c0-0f0e-4361-b472-3c8cfa2b9901', '8b1933c0-0f0e-4361-b472-3c8cfa2b9999', 'Introductory Meetup', 'Tenant 2 VP', '2026-06-10', '15:00:00', 'Review custom orders details.', 'd9b0a1a0-0000-0000-0000-000000000002')
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 9. SEED OPERATIONAL NUDGES (DETERMINISTIC UUIDs, ON CONFLICT id SAFE)
-- ----------------------------------------------------------------------------
INSERT INTO public.nudges (id, profile_id, message, severity, is_read, workspace_id)
VALUES
    -- Workspace 1 Nudges
    ('001933c0-0f0e-4361-b472-3c8cfa2b9801', '8b1933c0-0f0e-4361-b472-3c8cfa2b9801', 'Vanguard Health has exceeded 84 days of inactivity. Touchpoint recommended.', 'critical', false, 'd9b0a1a0-0000-0000-0000-000000000001'),
    ('001933c0-0f0e-4361-b472-3c8cfa2b9802', '8b1933c0-0f0e-4361-b472-3c8cfa2b9801', 'Sarah Lansky resolved 14 warnings in 4 days. Monitor team burnout.', 'warning', false, 'd9b0a1a0-0000-0000-0000-000000000001'),
    ('001933c0-0f0e-4361-b472-3c8cfa2b9803', '8b1933c0-0f0e-4361-b472-3c8cfa2b9801', 'Tom Collins conversion rate dropped 12% in healthcare accounts.', 'critical', false, 'd9b0a1a0-0000-0000-0000-000000000001'),
    
    -- Workspace 2 Nudge
    ('001933c0-0f0e-4361-b472-3c8cfa2b9901', '8b1933c0-0f0e-4361-b472-3c8cfa2b9999', 'Setup integrations for Tenant 2.', 'info', false, 'd9b0a1a0-0000-0000-0000-000000000002')
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 10. SEED COSMO JARVIS AI AUDITS (DETERMINISTIC UUIDs, ON CONFLICT id SAFE)
-- ----------------------------------------------------------------------------
INSERT INTO public.cosmo_audits (id, contact_id, narrative, severity, workspace_id)
VALUES
    -- Workspace 1 Cosmo Audits
    ('e11933c0-0f0e-4361-b472-3c8cfa2b9801', '5d1933c0-0f0e-4361-b472-3c8cfa2b9869', 'Vanguard Health exceeded threshold inactivity levels (34 days neglected). Systematic review of healthcare AE pipelines recommended.', 'critical', 'd9b0a1a0-0000-0000-0000-000000000001'),
    ('e11933c0-0f0e-4361-b472-3c8cfa2b9802', '5d1933c0-0f0e-4361-b472-3c8cfa2b9875', 'Nova Financial has Q3 contract renewal approaching in June. Health index is strong at 91%. Suggest milestone Sweet Box dispatch to lock retention.', 'info', 'd9b0a1a0-0000-0000-0000-000000000001'),
    ('e11933c0-0f0e-4361-b472-3c8cfa2b9803', '5d1933c0-0f0e-4361-b472-3c8cfa2b9871', 'Chevron Logistics has remained a prospect for 42 days with zero manual touches. Recommend outbound AE warming outreach.', 'warning', 'd9b0a1a0-0000-0000-0000-000000000001'),
    
    -- Workspace 2 Cosmo Audit
    ('e11933c0-0f0e-4361-b472-3c8cfa2b9901', '5d1933c0-0f0e-4361-b472-3c8cfa2b9961', 'New account setup check complete for Tenant 2.', 'info', 'd9b0a1a0-0000-0000-0000-000000000002')
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 11. SEED FUMBLE RECOVERY BOARD REQUESTS (DETERMINISTIC UUIDs, ON CONFLICT id SAFE)
-- ----------------------------------------------------------------------------
INSERT INTO public.recovery_requests (id, contact_id, original_rep_id, requester_rep_id, justification, status, workspace_id)
VALUES
    -- Vanguard Health in recovery board, claimed by Marcus Dupond
    ('0e1933c0-0f0e-4361-b472-3c8cfa2b9801', '5d1933c0-0f0e-4361-b472-3c8cfa2b9869', '8b1933c0-0f0e-4361-b472-3c8cfa2b9808', '8b1933c0-0f0e-4361-b472-3c8cfa2b9805', 'Outlined 3-step outbound gifting sequence to restore relationship.', 'pending', 'd9b0a1a0-0000-0000-0000-000000000001'),
    -- Chevron Logistics in recovery board, claimed by Tom Collins
    ('0e1933c0-0f0e-4361-b472-3c8cfa2b9802', '5d1933c0-0f0e-4361-b472-3c8cfa2b9871', '8b1933c0-0f0e-4361-b472-3c8cfa2b9805', '8b1933c0-0f0e-4361-b472-3c8cfa2b9807', 'Targeting VP of procurement with warm cold warming executive box.', 'pending', 'd9b0a1a0-0000-0000-0000-000000000001')
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 12. SEED REASSIGNMENT HISTORY (CONTACT ASSIGNMENTS - DETERMINISTIC UUIDs, ON CONFLICT id SAFE)
-- ----------------------------------------------------------------------------
INSERT INTO public.contact_assignments (id, workspace_id, contact_id, previous_rep_id, new_rep_id, assigned_by, justification)
VALUES
    ('d11933c0-0f0e-4361-b472-3c8cfa2b9801', 'd9b0a1a0-0000-0000-0000-000000000001', '5d1933c0-0f0e-4361-b472-3c8cfa2b9869', '8b1933c0-0f0e-4361-b472-3c8cfa2b9807', '8b1933c0-0f0e-4361-b472-3c8cfa2b9801', '8b1933c0-0f0e-4361-b472-3c8cfa2b9801', 'Owner emergency intervention: account inactive for 84 days.')
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 13. SEED AUDIT LOGS (PARTITION COMPATIBLE - DETERMINISTIC UUIDS, ON CONFLICT id SAFE)
-- ----------------------------------------------------------------------------
INSERT INTO public.audit_logs (id, workspace_id, actor_id, actor_name, role, action, entity_type, entity_id, new_values, created_at)
VALUES
    ('f11933c0-0f0e-4361-b472-3c8cfa2b9801', 'd9b0a1a0-0000-0000-0000-000000000001', '8b1933c0-0f0e-4361-b472-3c8cfa2b9801', 'Paul K.', 'owner'::public.user_role, 'SEED_DEVELOPMENT_ENVIRONMENT', 'workspace', 'd9b0a1a0-0000-0000-0000-000000000001', '{"description": "Initial development preset database seeding."}'::jsonb, '2026-06-08 12:00:00+00'::timestamp with time zone)
ON CONFLICT (id, created_at) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 14. RE-ENABLE TRIGGERS & RESTORE TRIGGER FUNCTIONS
-- ----------------------------------------------------------------------------
-- Re-enable role checks on profiles
ALTER TABLE public.profiles ENABLE TRIGGER check_role_escalation;

-- Restore handle_new_user() trigger function to its secure production-ready state
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    default_workspace_id uuid;
BEGIN
    -- Bootstrap Verification Check:
    -- Verify that at least one workspace is seeded before allowing signups
    SELECT id INTO default_workspace_id FROM public.workspaces ORDER BY created_at ASC LIMIT 1;
    IF default_workspace_id IS NULL THEN
        RAISE EXCEPTION 'Bootstrap Error: No active workspaces found in public.workspaces. Seed a workspace first.';
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
        'rep'::public.user_role,
        default_workspace_id,
        NULL,
        new.raw_user_meta_data->>'avatar_url',
        'active'::public.profile_status
    );
    
    RETURN new;
END;
$function$;

-- Commit database changes
COMMIT;

/*
-- ============================================================================
-- ROLLBACK SCRIPT FOR PHASE 4 SEED DATA
-- RUN THIS SCRIPT TO FULLY REMOVE ALL SEEDED RECORDS
-- ============================================================================

BEGIN;

-- Delete seeded audit logs
DELETE FROM public.audit_logs WHERE id = 'f11933c0-0f0e-4361-b472-3c8cfa2b9801';

-- Delete seeded contact assignments
DELETE FROM public.contact_assignments WHERE id = 'd11933c0-0f0e-4361-b472-3c8cfa2b9801';

-- Delete seeded recovery requests
DELETE FROM public.recovery_requests WHERE id IN ('0e1933c0-0f0e-4361-b472-3c8cfa2b9801', '0e1933c0-0f0e-4361-b472-3c8cfa2b9802');

-- Delete seeded cosmo audits
DELETE FROM public.cosmo_audits WHERE id IN ('e11933c0-0f0e-4361-b472-3c8cfa2b9801', 'e11933c0-0f0e-4361-b472-3c8cfa2b9802', 'e11933c0-0f0e-4361-b472-3c8cfa2b9803', 'e11933c0-0f0e-4361-b472-3c8cfa2b9901');

-- Delete seeded nudges
DELETE FROM public.nudges WHERE id IN ('001933c0-0f0e-4361-b472-3c8cfa2b9801', '001933c0-0f0e-4361-b472-3c8cfa2b9802', '001933c0-0f0e-4361-b472-3c8cfa2b9803', '001933c0-0f0e-4361-b472-3c8cfa2b9901');

-- Delete seeded calendar events
DELETE FROM public.calendar_events WHERE id IN ('c11933c0-0f0e-4361-b472-3c8cfa2b9801', 'c11933c0-0f0e-4361-b472-3c8cfa2b9802', 'c11933c0-0f0e-4361-b472-3c8cfa2b9803', 'c11933c0-0f0e-4361-b472-3c8cfa2b9804', 'c11933c0-0f0e-4361-b472-3c8cfa2b9901');

-- Delete seeded gifts
DELETE FROM public.gifts WHERE id IN (
    '7b1933c0-0f0e-4361-b472-3c8cfa2b9801', '7b1933c0-0f0e-4361-b472-3c8cfa2b9802', 
    '7b1933c0-0f0e-4361-b472-3c8cfa2b9803', '7b1933c0-0f0e-4361-b472-3c8cfa2b9804', 
    '7b1933c0-0f0e-4361-b472-3c8cfa2b9805', '7b1933c0-0f0e-4361-b472-3c8cfa2b9806', 
    '7b1933c0-0f0e-4361-b472-3c8cfa2b9807', '7b1933c0-0f0e-4361-b472-3c8cfa2b9808', 
    '7b1933c0-0f0e-4361-b472-3c8cfa2b9809', '7b1933c0-0f0e-4361-b472-3c8cfa2b9810',
    '7b1933c0-0f0e-4361-b472-3c8cfa2b9877',
    '6f1933c0-0f0e-4361-b472-3c8cfa2b9891', '6f1933c0-0f0e-4361-b472-3c8cfa2b9892', 
    '6f1933c0-0f0e-4361-b472-3c8cfa2b9893', '6f1933c0-0f0e-4361-b472-3c8cfa2b9894',
    '7b1933c0-0f0e-4361-b472-3c8cfa2b9901'
);

-- Delete seeded activities
DELETE FROM public.activities WHERE id IN (
    'a11933c0-0f0e-4361-b472-3c8cfa2b9801', 'a11933c0-0f0e-4361-b472-3c8cfa2b9802', 
    'a11933c0-0f0e-4361-b472-3c8cfa2b9803', 'a11933c0-0f0e-4361-b472-3c8cfa2b9804', 
    'a11933c0-0f0e-4361-b472-3c8cfa2b9805', 'a11933c0-0f0e-4361-b472-3c8cfa2b9806', 
    'a11933c0-0f0e-4361-b472-3c8cfa2b9807', 'a11933c0-0f0e-4361-b472-3c8cfa2b9808', 
    'a11933c0-0f0e-4361-b472-3c8cfa2b9809', 'a11933c0-0f0e-4361-b472-3c8cfa2b9901'
);

-- Delete seeded contacts
DELETE FROM public.contacts WHERE id IN (
    '5d1933c0-0f0e-4361-b472-3c8cfa2b9861', '5d1933c0-0f0e-4361-b472-3c8cfa2b9862', 
    '5d1933c0-0f0e-4361-b472-3c8cfa2b9863', '5d1933c0-0f0e-4361-b472-3c8cfa2b9864', 
    '5d1933c0-0f0e-4361-b472-3c8cfa2b9865', '5d1933c0-0f0e-4361-b472-3c8cfa2b9866', 
    '5d1933c0-0f0e-4361-b472-3c8cfa2b9867', '5d1933c0-0f0e-4361-b472-3c8cfa2b9868', 
    '5d1933c0-0f0e-4361-b472-3c8cfa2b9869', '5d1933c0-0f0e-4361-b472-3c8cfa2b9870', 
    '5d1933c0-0f0e-4361-b472-3c8cfa2b9871', '5d1933c0-0f0e-4361-b472-3c8cfa2b9872', 
    '5d1933c0-0f0e-4361-b472-3c8cfa2b9873', '5d1933c0-0f0e-4361-b472-3c8cfa2b9874', 
    '5d1933c0-0f0e-4361-b472-3c8cfa2b9875', '5d1933c0-0f0e-4361-b472-3c8cfa2b9876', 
    '5d1933c0-0f0e-4361-b472-3c8cfa2b9877', '5d1933c0-0f0e-4361-b472-3c8cfa2b9878', 
    '5d1933c0-0f0e-4361-b472-3c8cfa2b9879', '5d1933c0-0f0e-4361-b472-3c8cfa2b9880', 
    '5d1933c0-0f0e-4361-b472-3c8cfa2b9881', '5d1933c0-0f0e-4361-b472-3c8cfa2b9961'
);

-- Delete seeded organizations
DELETE FROM public.organizations WHERE id IN (
    '3c1933c0-0f0e-4361-b472-3c8cfa2b9831', '3c1933c0-0f0e-4361-b472-3c8cfa2b9832', 
    '3c1933c0-0f0e-4361-b472-3c8cfa2b9833', '3c1933c0-0f0e-4361-b472-3c8cfa2b9834', 
    '3c1933c0-0f0e-4361-b472-3c8cfa2b9835', '3c1933c0-0f0e-4361-b472-3c8cfa2b9836', 
    '3c1933c0-0f0e-4361-b472-3c8cfa2b9837', '3c1933c0-0f0e-4361-b472-3c8cfa2b9838', 
    '3c1933c0-0f0e-4361-b472-3c8cfa2b9839', '3c1933c0-0f0e-4361-b472-3c8cfa2b9840', 
    '3c1933c0-0f0e-4361-b472-3c8cfa2b9841', '3c1933c0-0f0e-4361-b472-3c8cfa2b9842', 
    '3c1933c0-0f0e-4361-b472-3c8cfa2b9843', '3c1933c0-0f0e-4361-b472-3c8cfa2b9844', 
    '3c1933c0-0f0e-4361-b472-3c8cfa2b9845', '3c1933c0-0f0e-4361-b472-3c8cfa2b9846', 
    '3c1933c0-0f0e-4361-b472-3c8cfa2b9847', '3c1933c0-0f0e-4361-b472-3c8cfa2b9848', 
    '3c1933c0-0f0e-4361-b472-3c8cfa2b9849', '3c1933c0-0f0e-4361-b472-3c8cfa2b9850', 
    '3c1933c0-0f0e-4361-b472-3c8cfa2b9851', '3c1933c0-0f0e-4361-b472-3c8cfa2b9931'
);

-- Delete seeded profiles
DELETE FROM public.profiles WHERE id IN (
    '8b1933c0-0f0e-4361-b472-3c8cfa2b9801', '8b1933c0-0f0e-4361-b472-3c8cfa2b9802', 
    '8b1933c0-0f0e-4361-b472-3c8cfa2b9803', '8b1933c0-0f0e-4361-b472-3c8cfa2b9804', 
    '8b1933c0-0f0e-4361-b472-3c8cfa2b9805', '8b1933c0-0f0e-4361-b472-3c8cfa2b9806', 
    '8b1933c0-0f0e-4361-b472-3c8cfa2b9807', '8b1933c0-0f0e-4361-b472-3c8cfa2b9808', 
    '8b1933c0-0f0e-4361-b472-3c8cfa2b9809', '8b1933c0-0f0e-4361-b472-3c8cfa2b9810', 
    '8b1933c0-0f0e-4361-b472-3c8cfa2b9811', '8b1933c0-0f0e-4361-b472-3c8cfa2b9812', 
    '8b1933c0-0f0e-4361-b472-3c8cfa2b9999'
);

-- Delete seeded auth.users
DELETE FROM auth.users WHERE id IN (
    '8b1933c0-0f0e-4361-b472-3c8cfa2b9801', '8b1933c0-0f0e-4361-b472-3c8cfa2b9802', 
    '8b1933c0-0f0e-4361-b472-3c8cfa2b9803', '8b1933c0-0f0e-4361-b472-3c8cfa2b9804', 
    '8b1933c0-0f0e-4361-b472-3c8cfa2b9805', '8b1933c0-0f0e-4361-b472-3c8cfa2b9806', 
    '8b1933c0-0f0e-4361-b472-3c8cfa2b9807', '8b1933c0-0f0e-4361-b472-3c8cfa2b9808', 
    '8b1933c0-0f0e-4361-b472-3c8cfa2b9809', '8b1933c0-0f0e-4361-b472-3c8cfa2b9810', 
    '8b1933c0-0f0e-4361-b472-3c8cfa2b9811', '8b1933c0-0f0e-4361-b472-3c8cfa2b9812', 
    '8b1933c0-0f0e-4361-b472-3c8cfa2b9999'
);

-- Delete seeded boxes
DELETE FROM public.boxes WHERE id IN (
    '9b1933c0-0f0e-4361-b472-3c8cfa2b9821', '9b1933c0-0f0e-4361-b472-3c8cfa2b9822', 
    '9b1933c0-0f0e-4361-b472-3c8cfa2b9823', '9b1933c0-0f0e-4361-b472-3c8cfa2b9921'
);

-- Delete settings for Workspace 1 and Workspace 2
DELETE FROM public.workspace_settings WHERE workspace_id IN ('d9b0a1a0-0000-0000-0000-000000000001', 'd9b0a1a0-0000-0000-0000-000000000002');

-- Delete Workspace 2
DELETE FROM public.workspaces WHERE id = 'd9b0a1a0-0000-0000-0000-000000000002';

COMMIT;
*/
