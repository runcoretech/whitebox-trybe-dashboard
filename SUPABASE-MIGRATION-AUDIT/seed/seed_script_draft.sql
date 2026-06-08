-- ============================================================================
-- WHITEBOX RMOS DATABASE SEED SCRIPT (PHASE 4 DRAFT - DEVELOPMENT PRESET)
-- ============================================================================

-- Wrap in a single transaction for safety
BEGIN;

-- ----------------------------------------------------------------------------
-- 0. TEMPORARY TRIGGER LOCKOUTS
-- Disable triggers during seed script execution to allow direct insertion of roles,
-- workspaces, and related entities without circular escalation/isolation checks.
-- ----------------------------------------------------------------------------
ALTER TABLE auth.users DISABLE TRIGGER on_auth_user_created;
ALTER TABLE public.profiles DISABLE TRIGGER check_role_escalation;

-- ----------------------------------------------------------------------------
-- 1. SEED WORKSPACES & SETTINGS
-- ----------------------------------------------------------------------------
-- Static Workspace UUID
DO $$
DECLARE
    ws_id uuid := '4a9df364-58ad-4fa9-83bc-2234559c5d01';
BEGIN
    INSERT INTO public.workspaces (id, name, subdomain, logo_url, theme)
    VALUES (
        ws_id,
        'WhiteBox Giftworks',
        'whitebox',
        'https://app.whiteboxworks.com/assets/logo-whitebox.png',
        '{"primary": "#6366f1", "dark_mode": true}'::jsonb
    ) ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.workspace_settings (
        workspace_id, decay_warning, decay_critical, decay_factor, target_conversion,
        hours_start, hours_end, nudge_cap, auto_neglect, manager_override, alert_routing,
        budget_milestone, budget_monthly, approval_gate, approval_threshold, auto_gifting,
        webhook_slack, webhook_teams, integrations
    )
    VALUES (
        ws_id, 30, 60, 1.50, 48,
        '09:00:00', '17:00:00', 5, true, true, true,
        45.00, 500.00, true, 100.00, true,
        'https://hooks.slack.com/services/mock_slack_webhook',
        'https://outlook.office.com/webhook/mock_teams_webhook',
        '{"salesforce":false,"hubspot":false,"twilio":false,"ringcentral":false,"gmail":false,"outlook":false}'::jsonb
    ) ON CONFLICT (workspace_id) DO NOTHING;
END;
$$;

-- ----------------------------------------------------------------------------
-- 2. SEED BOXES (PRODUCT DIRECTORY CATALOG)
-- ----------------------------------------------------------------------------
INSERT INTO public.boxes (id, workspace_id, name, description, theme_color, price, is_active)
VALUES 
    ('9b1933c0-0f0e-4361-b472-3c8cfa2b9821', '4a9df364-58ad-4fa9-83bc-2234559c5d01', 'Sweet Box', 'Premium assortment of cookies and hand-crafted confections.', '#fbbf24', 90.00, true),
    ('9b1933c0-0f0e-4361-b472-3c8cfa2b9822', '4a9df364-58ad-4fa9-83bc-2234559c5d01', 'Pack Box', 'Shared corporate confectionery snack pack.', '#3b82f6', 80.00, true),
    ('9b1933c0-0f0e-4361-b472-3c8cfa2b9823', '4a9df364-58ad-4fa9-83bc-2234559c5d01', 'Premium Box', 'Luxury chocolate collections and premium branded corporate gifts.', '#8b5cf6', 300.00, true)
ON CONFLICT (workspace_id, name) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 3. SEED AUTH USERS & PROFILES (ROLE HIERARCHY PRESERVING)
-- Using dummy Bcrypt hash representing development password 'wb_password_2026!'
-- ----------------------------------------------------------------------------
-- 3.1. Insert auth.users
INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, raw_user_meta_data, raw_app_meta_data, is_super_admin, aud, role)
VALUES
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9801', 'owner@whitebox.com', '$2a$10$U.yP0zM2Q7K3t.GgL2qL0.m3F07oU1N0S/4zYgO/q1rG/0Z/Gg3vS', now(), '{"name": "Paul K.", "role": "owner"}'::jsonb, '{"provider": "email"}'::jsonb, false, 'authenticated', 'authenticated'),
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9802', 'g.sterling@whitebox.com', '$2a$10$U.yP0zM2Q7K3t.GgL2qL0.m3F07oU1N0S/4zYgO/q1rG/0Z/Gg3vS', now(), '{"name": "Gregory Sterling", "role": "executive"}'::jsonb, '{"provider": "email"}'::jsonb, false, 'authenticated', 'authenticated'),
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9803', 'executive@whitebox.com', '$2a$10$U.yP0zM2Q7K3t.GgL2qL0.m3F07oU1N0S/4zYgO/q1rG/0Z/Gg3vS', now(), '{"name": "Sarah Lansky", "role": "executive"}'::jsonb, '{"provider": "email"}'::jsonb, false, 'authenticated', 'authenticated'),
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9804', 'e.davis@whitebox.com', '$2a$10$U.yP0zM2Q7K3t.GgL2qL0.m3F07oU1N0S/4zYgO/q1rG/0Z/Gg3vS', now(), '{"name": "Emily Davis", "role": "executive"}'::jsonb, '{"provider": "email"}'::jsonb, false, 'authenticated', 'authenticated'),
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9805', 'manager@whitebox.com', '$2a$10$U.yP0zM2Q7K3t.GgL2qL0.m3F07oU1N0S/4zYgO/q1rG/0Z/Gg3vS', now(), '{"name": "Marcus Dupond", "role": "manager"}'::jsonb, '{"provider": "email"}'::jsonb, false, 'authenticated', 'authenticated'),
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9806', 'j.smith@whitebox.com', '$2a$10$U.yP0zM2Q7K3t.GgL2qL0.m3F07oU1N0S/4zYgO/q1rG/0Z/Gg3vS', now(), '{"name": "Jane Smith", "role": "manager"}'::jsonb, '{"provider": "email"}'::jsonb, false, 'authenticated', 'authenticated'),
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9807', 'rep@whitebox.com', '$2a$10$U.yP0zM2Q7K3t.GgL2qL0.m3F07oU1N0S/4zYgO/q1rG/0Z/Gg3vS', now(), '{"name": "Tom Collins", "role": "rep"}'::jsonb, '{"provider": "email"}'::jsonb, false, 'authenticated', 'authenticated'),
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9808', 'd.schrute@whitebox.com', '$2a$10$U.yP0zM2Q7K3t.GgL2qL0.m3F07oU1N0S/4zYgO/q1rG/0Z/Gg3vS', now(), '{"name": "Dwight Schrute", "role": "rep"}'::jsonb, '{"provider": "email"}'::jsonb, false, 'authenticated', 'authenticated'),
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9809', 'j.doe@whitebox.com', '$2a$10$U.yP0zM2Q7K3t.GgL2qL0.m3F07oU1N0S/4zYgO/q1rG/0Z/Gg3vS', now(), '{"name": "John Doe", "role": "rep"}'::jsonb, '{"provider": "email"}'::jsonb, false, 'authenticated', 'authenticated'),
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9810', 'a.cooper@whitebox.com', '$2a$10$U.yP0zM2Q7K3t.GgL2qL0.m3F07oU1N0S/4zYgO/q1rG/0Z/Gg3vS', now(), '{"name": "Alice Cooper", "role": "rep"}'::jsonb, '{"provider": "email"}'::jsonb, false, 'authenticated', 'authenticated'),
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9811', 'b.martin@whitebox.com', '$2a$10$U.yP0zM2Q7K3t.GgL2qL0.m3F07oU1N0S/4zYgO/q1rG/0Z/Gg3vS', now(), '{"name": "Bob Martin", "role": "rep"}'::jsonb, '{"provider": "email"}'::jsonb, false, 'authenticated', 'authenticated'),
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9812', 'c.brown@whitebox.com', '$2a$10$U.yP0zM2Q7K3t.GgL2qL0.m3F07oU1N0S/4zYgO/q1rG/0Z/Gg3vS', now(), '{"name": "Charlie Brown", "role": "rep"}'::jsonb, '{"provider": "email"}'::jsonb, false, 'authenticated', 'authenticated')
ON CONFLICT (id) DO NOTHING;

-- 3.2. Insert public.profiles (Recreating managers hierarchy tree)
INSERT INTO public.profiles (id, email, name, role, workspace_id, manager_id, avatar_url, status)
VALUES
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9801', 'owner@whitebox.com', 'Paul K.', 'owner', '4a9df364-58ad-4fa9-83bc-2234559c5d01', NULL, NULL, 'active'),
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9802', 'g.sterling@whitebox.com', 'Gregory Sterling', 'executive', '4a9df364-58ad-4fa9-83bc-2234559c5d01', NULL, NULL, 'active'),
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9803', 'executive@whitebox.com', 'Sarah Lansky', 'executive', '4a9df364-58ad-4fa9-83bc-2234559c5d01', '8b1933c0-0f0e-4361-b472-3c8cfa2b9802', NULL, 'active'),
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9804', 'e.davis@whitebox.com', 'Emily Davis', 'executive', '4a9df364-58ad-4fa9-83bc-2234559c5d01', '8b1933c0-0f0e-4361-b472-3c8cfa2b9803', NULL, 'active'),
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9805', 'manager@whitebox.com', 'Marcus Dupond', 'manager', '4a9df364-58ad-4fa9-83bc-2234559c5d01', '8b1933c0-0f0e-4361-b472-3c8cfa2b9801', NULL, 'active'),
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9806', 'j.smith@whitebox.com', 'Jane Smith', 'manager', '4a9df364-58ad-4fa9-83bc-2234559c5d01', '8b1933c0-0f0e-4361-b472-3c8cfa2b9801', NULL, 'active'),
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9807', 'rep@whitebox.com', 'Tom Collins', 'rep', '4a9df364-58ad-4fa9-83bc-2234559c5d01', '8b1933c0-0f0e-4361-b472-3c8cfa2b9805', NULL, 'active'),
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9808', 'd.schrute@whitebox.com', 'Dwight Schrute', 'rep', '4a9df364-58ad-4fa9-83bc-2234559c5d01', '8b1933c0-0f0e-4361-b472-3c8cfa2b9805', NULL, 'active'),
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9809', 'j.doe@whitebox.com', 'John Doe', 'rep', '4a9df364-58ad-4fa9-83bc-2234559c5d01', '8b1933c0-0f0e-4361-b472-3c8cfa2b9805', NULL, 'active'),
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9810', 'a.cooper@whitebox.com', 'Alice Cooper', 'rep', '4a9df364-58ad-4fa9-83bc-2234559c5d01', '8b1933c0-0f0e-4361-b472-3c8cfa2b9804', NULL, 'active'),
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9811', 'b.martin@whitebox.com', 'Bob Martin', 'rep', '4a9df364-58ad-4fa9-83bc-2234559c5d01', '8b1933c0-0f0e-4361-b472-3c8cfa2b9804', NULL, 'active'),
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9812', 'c.brown@whitebox.com', 'Charlie Brown', 'rep', '4a9df364-58ad-4fa9-83bc-2234559c5d01', '8b1933c0-0f0e-4361-b472-3c8cfa2b9804', NULL, 'active')
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 4. SEED ORGANIZATIONS
-- ----------------------------------------------------------------------------
INSERT INTO public.organizations (id, name, sector, category, workspace_id)
VALUES
    ('3c1933c0-0f0e-4361-b472-3c8cfa2b9831', 'Apex Global Retail', 'Enterprise B2B', 'enterprise', '4a9df364-58ad-4fa9-83bc-2234559c5d01'),
    ('3c1933c0-0f0e-4361-b472-3c8cfa2b9832', 'Chevron Solutions', 'Enterprise B2B', 'enterprise', '4a9df364-58ad-4fa9-83bc-2234559c5d01'),
    ('3c1933c0-0f0e-4361-b472-3c8cfa2b9833', 'Initech Software', 'Enterprise B2B', 'smb', '4a9df364-58ad-4fa9-83bc-2234559c5d01'),
    ('3c1933c0-0f0e-4361-b472-3c8cfa2b9834', 'Wayne Enterprises', 'Enterprise B2B', 'enterprise', '4a9df364-58ad-4fa9-83bc-2234559c5d01'),
    ('3c1933c0-0f0e-4361-b472-3c8cfa2b9835', 'Stark Industries', 'Enterprise B2B', 'enterprise', '4a9df364-58ad-4fa9-83bc-2234559c5d01'),
    ('3c1933c0-0f0e-4361-b472-3c8cfa2b9836', 'Tyrell Corporation', 'Enterprise B2B', 'enterprise', '4a9df364-58ad-4fa9-83bc-2234559c5d01'),
    ('3c1933c0-0f0e-4361-b472-3c8cfa2b9837', 'Apex Systems', 'Prospect', 'prospect', '4a9df364-58ad-4fa9-83bc-2234559c5d01'),
    ('3c1933c0-0f0e-4361-b472-3c8cfa2b9838', 'Zenith Corp', 'Prospect', 'prospect', '4a9df364-58ad-4fa9-83bc-2234559c5d01'),
    ('3c1933c0-0f0e-4361-b472-3c8cfa2b9839', 'Vanguard Health', 'Prospect', 'prospect', '4a9df364-58ad-4fa9-83bc-2234559c5d01'),
    ('3c1933c0-0f0e-4361-b472-3c8cfa2b9840', 'OmniCorp', 'Prospect', 'prospect', '4a9df364-58ad-4fa9-83bc-2234559c5d01'),
    ('3c1933c0-0f0e-4361-b472-3c8cfa2b9841', 'Chevron Logistics', 'Prospect', 'prospect', '4a9df364-58ad-4fa9-83bc-2234559c5d01'),
    ('3c1933c0-0f0e-4361-b472-3c8cfa2b9842', 'TechFlow Inc', 'Prospect', 'prospect', '4a9df364-58ad-4fa9-83bc-2234559c5d01'),
    -- Extra organizations referenced in detail timeline configs
    ('3c1933c0-0f0e-4361-b472-3c8cfa2b9843', 'Pinnacle Brands', 'Enterprise B2B', 'smb', '4a9df364-58ad-4fa9-83bc-2234559c5d01'),
    ('3c1933c0-0f0e-4361-b472-3c8cfa2b9844', 'Orion Biotech', 'Prospect', 'prospect', '4a9df364-58ad-4fa9-83bc-2234559c5d01'),
    ('3c1933c0-0f0e-4361-b472-3c8cfa2b9845', 'Nova Financial', 'Enterprise B2B', 'enterprise', '4a9df364-58ad-4fa9-83bc-2234559c5d01'),
    ('3c1933c0-0f0e-4361-b472-3c8cfa2b9846', 'BlueStar Retail', 'Enterprise B2B', 'smb', '4a9df364-58ad-4fa9-83bc-2234559c5d01'),
    ('3c1933c0-0f0e-4361-b472-3c8cfa2b9847', 'Peak Financial', 'Enterprise B2B', 'enterprise', '4a9df364-58ad-4fa9-83bc-2234559c5d01'),
    ('3c1933c0-0f0e-4361-b472-3c8cfa2b9848', 'Silverline Tech', 'Enterprise B2B', 'smb', '4a9df364-58ad-4fa9-83bc-2234559c5d01'),
    ('3c1933c0-0f0e-4361-b472-3c8cfa2b9849', 'Helix Labs', 'Enterprise B2B', 'smb', '4a9df364-58ad-4fa9-83bc-2234559c5d01'),
    ('3c1933c0-0f0e-4361-b472-3c8cfa2b9850', 'Alpha Digital', 'Enterprise B2B', 'smb', '4a9df364-58ad-4fa9-83bc-2234559c5d01'),
    ('3c1933c0-0f0e-4361-b472-3c8cfa2b9851', 'Quantum Tech', 'Enterprise B2B', 'smb', '4a9df364-58ad-4fa9-83bc-2234559c5d01')
ON CONFLICT (name, workspace_id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 5. SEED CONTACTS (INDIVIDUAL CLIENTS ASSIGNED TO REPS)
-- ----------------------------------------------------------------------------
INSERT INTO public.contacts (id, org_id, name, email, phone, assigned_rep_id, status, relationship_health, ai_recommendation, workspace_id)
VALUES
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9861', '3c1933c0-0f0e-4361-b472-3c8cfa2b9831', 'Apex Global CS', 'cs@apexglobal.com', '(800) 555-0101', '8b1933c0-0f0e-4361-b472-3c8cfa2b9803', 'active', 96, 'Schedule quarterly check-in sync', '4a9df364-58ad-4fa9-83bc-2234559c5d01'),
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9862', '3c1933c0-0f0e-4361-b472-3c8cfa2b9832', 'Chevron Operations', 'ops@chevron.com', '(800) 555-0102', '8b1933c0-0f0e-4361-b472-3c8cfa2b9805', 'active', 98, 'Send milestone appreciation box', '4a9df364-58ad-4fa9-83bc-2234559c5d01'),
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9863', '3c1933c0-0f0e-4361-b472-3c8cfa2b9833', 'Ted Initech', 'ted@initech.com', '(512) 555-0133', '8b1933c0-0f0e-4361-b472-3c8cfa2b9807', 'active', 74, 'Recommend Sweet Box to warm relationship', '4a9df364-58ad-4fa9-83bc-2234559c5d01'),
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9864', '3c1933c0-0f0e-4361-b472-3c8cfa2b9834', 'Bruce Wayne', 'bruce@wayne.com', '(607) 555-0144', '8b1933c0-0f0e-4361-b472-3c8cfa2b9808', 'active', 98, 'Verify Premium Executive Box arrival', '4a9df364-58ad-4fa9-83bc-2234559c5d01'),
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9865', '3c1933c0-0f0e-4361-b472-3c8cfa2b9835', 'Pepper Potts', 'pepper@stark.com', '(212) 555-0199', '8b1933c0-0f0e-4361-b472-3c8cfa2b9809', 'active', 98, 'Log quarterly alignment notes', '4a9df364-58ad-4fa9-83bc-2234559c5d01'),
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9866', '3c1933c0-0f0e-4361-b472-3c8cfa2b9836', 'Eldon Tyrell', 'tyrell@tyrell.com', '(213) 555-0160', '8b1933c0-0f0e-4361-b472-3c8cfa2b9811', 'neglected', 38, 'Critical neglect risk: schedule call', '4a9df364-58ad-4fa9-83bc-2234559c5d01'),
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9867', '3c1933c0-0f0e-4361-b472-3c8cfa2b9837', 'Apex Pipeline', 'pipeline@apex.com', '(800) 555-0177', '8b1933c0-0f0e-4361-b472-3c8cfa2b9803', 'active', 74, 'Send Outbound Prospect Nudge', '4a9df364-58ad-4fa9-83bc-2234559c5d01'),
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9868', '3c1933c0-0f0e-4361-b472-3c8cfa2b9838', 'Zenith Lead', 'lead@zenith.com', '(206) 555-0180', '8b1933c0-0f0e-4361-b472-3c8cfa2b9807', 'active', 74, 'Send automated introductory catalog', '4a9df364-58ad-4fa9-83bc-2234559c5d01'),
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9869', '3c1933c0-0f0e-4361-b472-3c8cfa2b9839', 'Vanguard Admin', 'admin@vanguard.com', '(312) 555-0199', '8b1933c0-0f0e-4361-b472-3c8cfa2b9808', 'neglected', 0, 'Reassign account ownership: 84 days quiet', '4a9df364-58ad-4fa9-83bc-2234559c5d01'),
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9870', '3c1933c0-0f0e-4361-b472-3c8cfa2b9840', 'Omni Lead', 'info@omnicorp.com', '(800) 555-0122', '8b1933c0-0f0e-4361-b472-3c8cfa2b9809', 'active', 74, 'Log follow up call request', '4a9df364-58ad-4fa9-83bc-2234559c5d01'),
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9871', '3c1933c0-0f0e-4361-b472-3c8cfa2b9841', 'Chevron Logistics CS', 'ops@chevronlogistics.com', '(800) 555-0155', '8b1933c0-0f0e-4361-b472-3c8cfa2b9805', 'neglected', 54, 'Exceeded warning limit: trigger recovery', '4a9df364-58ad-4fa9-83bc-2234559c5d01'),
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9872', '3c1933c0-0f0e-4361-b472-3c8cfa2b9842', 'TechFlow Contact', 'ops@techflow.com', '(800) 555-0166', '8b1933c0-0f0e-4361-b472-3c8cfa2b9811', 'active', 74, 'Send Sweet Box for outreach', '4a9df364-58ad-4fa9-83bc-2234559c5d01'),
    -- Extra specific contacts matching dashboard layout
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9873', '3c1933c0-0f0e-4361-b472-3c8cfa2b9843', 'Lisa Kudrow', 'sales@pinnacle.com', '(213) 555-0177', '8b1933c0-0f0e-4361-b472-3c8cfa2b9807', 'neglected', 62, 'Decayed health: send Premium Box', '4a9df364-58ad-4fa9-83bc-2234559c5d01'),
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9874', '3c1933c0-0f0e-4361-b472-3c8cfa2b9844', 'Dr. Robert Vance', 'rnd@orion.com', '(617) 555-0167', '8b1933c0-0f0e-4361-b472-3c8cfa2b9807', 'neglected', 54, 'Critical neglect: reassign request', '4a9df364-58ad-4fa9-83bc-2234559c5d01'),
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9875', '3c1933c0-0f0e-4361-b472-3c8cfa2b9845', 'Dr. Aris', 'admin@nova.com', '(206) 555-0144', '8b1933c0-0f0e-4361-b472-3c8cfa2b9807', 'active', 74, 'Send Remember Premium Box', '4a9df364-58ad-4fa9-83bc-2234559c5d01'),
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9876', '3c1933c0-0f0e-4361-b472-3c8cfa2b9846', 'BlueStar CS', 'buyer@bluestar.com', '(800) 555-0188', '8b1933c0-0f0e-4361-b472-3c8cfa2b9807', 'active', 90, 'Verify Sweet Box Anniversary reception', '4a9df364-58ad-4fa9-83bc-2234559c5d01'),
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9877', '3c1933c0-0f0e-4361-b472-3c8cfa2b9847', 'Peak Finance Rep', 'billing@peakfinancial.com', '(800) 555-0199', '8b1933c0-0f0e-4361-b472-3c8cfa2b9807', 'active', 85, 'Awaiting Custom Box design layout', '4a9df364-58ad-4fa9-83bc-2234559c5d01'),
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9878', '3c1933c0-0f0e-4361-b472-3c8cfa2b9848', 'Silverline Rep', 'ops@silverlinetech.com', '(800) 555-0211', '8b1933c0-0f0e-4361-b472-3c8cfa2b9805', 'active', 92, 'Check Sweet Box Anniversary status', '4a9df364-58ad-4fa9-83bc-2234559c5d01'),
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9879', '3c1933c0-0f0e-4361-b472-3c8cfa2b9849', 'Helix Labs Ops', 'team@helixlabs.com', '(800) 555-0222', '8b1933c0-0f0e-4361-b472-3c8cfa2b9807', 'active', 90, 'Milestone celebration complete', '4a9df364-58ad-4fa9-83bc-2234559c5d01'),
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9880', '3c1933c0-0f0e-4361-b472-3c8cfa2b9850', 'Alpha Dig Lead', 'marketing@alphadigital.com', '(800) 555-0233', '8b1933c0-0f0e-4361-b472-3c8cfa2b9807', 'active', 95, 'Verify cold warming campaign complete', '4a9df364-58ad-4fa9-83bc-2234559c5d01'),
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9881', '3c1933c0-0f0e-4361-b472-3c8cfa2b9851', 'Quantum Eng Lead', 'eng@quantumtech.com', '(800) 555-0244', '8b1933c0-0f0e-4361-b472-3c8cfa2b9807', 'active', 90, 'Engineering Nudge sweet box confirmed', '4a9df364-58ad-4fa9-83bc-2234559c5d01')
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 6. SEED CRM ACTIVITIES (TOUCHPOINT TIMELINES BACKDATED FOR INACTIVITY)
-- ----------------------------------------------------------------------------
INSERT INTO public.activities (contact_id, rep_id, type, grade, notes, workspace_id, logged_at)
VALUES
    -- Apex Global Retail (Sarah Lansky AE - 5 days ago)
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9861', '8b1933c0-0f0e-4361-b472-3c8cfa2b9803', 'Call', 'A', 'Discussed Q2 renewal pipeline with procurement VP.', '4a9df364-58ad-4fa9-83bc-2234559c5d01', now() - INTERVAL '5 days'),
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9861', '8b1933c0-0f0e-4361-b472-3c8cfa2b9803', 'Email', 'A', 'Follow-up on signed agreement. Shared fulfillment timeline.', '4a9df364-58ad-4fa9-83bc-2234559c5d01', now() - INTERVAL '10 days'),
    -- Chevron Solutions (Marcus Dupond - 12 days ago)
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9862', '8b1933c0-0f0e-4361-b472-3c8cfa2b9805', 'Meeting', 'A', 'Onsite B2B strategic review with regional leadership.', '4a9df364-58ad-4fa9-83bc-2234559c5d01', now() - INTERVAL '12 days'),
    -- Vanguard Health (Dwight Schrute - Neglected for 84 days)
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9869', '8b1933c0-0f0e-4361-b472-3c8cfa2b9808', 'Call', 'C', 'Voicemail left with administrative supervisor.', '4a9df364-58ad-4fa9-83bc-2234559c5d01', now() - INTERVAL '84 days'),
    -- Orion Biotech (Tom Collins - Neglected for 64 days)
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9874', '8b1933c0-0f0e-4361-b472-3c8cfa2b9807', 'Email', 'C', 'Routine touchpoint regarding pricing catalogs.', '4a9df364-58ad-4fa9-83bc-2234559c5d01', now() - INTERVAL '64 days'),
    -- Chevron Logistics (Marcus Dupond - Warning zone for 42 days)
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9871', '8b1933c0-0f0e-4361-b472-3c8cfa2b9805', 'Call', 'D', 'Brief callback, contact requested email updates next month.', '4a9df364-58ad-4fa9-83bc-2234559c5d01', now() - INTERVAL '42 days'),
    -- Pinnacle Brands (Tom Collins - Neglected for 68 days)
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9873', '8b1933c0-0f0e-4361-b472-3c8cfa2b9807', 'Call', 'C', 'Follow-up regarding B2B contract terms, no signature yet.', '4a9df364-58ad-4fa9-83bc-2234559c5d01', now() - INTERVAL '68 days'),
    -- Initech Software (Tom Collins - Active)
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9863', '8b1933c0-0f0e-4361-b472-3c8cfa2b9807', 'Meeting', 'B', 'Client sync: discussed Q2 billing changes.', '4a9df364-58ad-4fa9-83bc-2234559c5d01', now() - INTERVAL '3 days'),
    -- Wayne Enterprises (Dwight Schrute - Active)
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9864', '8b1933c0-0f0e-4361-b472-3c8cfa2b9808', 'Meeting', 'A', 'Met with director regarding enterprise confections proposal.', '4a9df364-58ad-4fa9-83bc-2234559c5d01', now() - INTERVAL '6 days')
;

-- ----------------------------------------------------------------------------
-- 7. SEED GIFTS & ACTIVE ORDERS
-- ----------------------------------------------------------------------------
INSERT INTO public.gifts (id, contact_id, rep_id, box_id, category, amount, status, shipping_street, shipping_city, shipping_province, shipping_postal, carrier, tracking_number, sender_label, reason, workspace_id, dispatched_at)
VALUES
    -- Marcus Dupond: reward, Sweet Box, Gregory Sterling, $90.00
    (gen_random_uuid(), '5d1933c0-0f0e-4361-b472-3c8cfa2b9862', '8b1933c0-0f0e-4361-b472-3c8cfa2b9802', '9b1933c0-0f0e-4361-b472-3c8cfa2b9821', 'reward', 90.00, 'delivered', '200 Main St', 'Detroit', 'MI', '48226', 'FedEx', '987654321011', 'Gregory Sterling (CEO)', 'Employee Milestone: May B2B Sales Volume Record', '4a9df364-58ad-4fa9-83bc-2234559c5d01', now() - INTERVAL '10 days'),
    -- Tom Collins: remember, Sweet Box, HR Department, $90.00
    (gen_random_uuid(), '5d1933c0-0f0e-4361-b472-3c8cfa2b9875', '8b1933c0-0f0e-4361-b472-3c8cfa2b9803', '9b1933c0-0f0e-4361-b472-3c8cfa2b9821', 'remember', 90.00, 'delivered', '500 Finance Blvd', 'Boston', 'MA', '02109', 'UPS', '1Z9A29810300123456', 'HR Department', 'Employee Birthday Recognition', '4a9df364-58ad-4fa9-83bc-2234559c5d01', now() - INTERVAL '7 days'),
    -- Sarah Lansky: reward, Premium Box, Gregory Sterling, $300.00
    (gen_random_uuid(), '5d1933c0-0f0e-4361-b472-3c8cfa2b9861', '8b1933c0-0f0e-4361-b472-3c8cfa2b9802', '9b1933c0-0f0e-4361-b472-3c8cfa2b9823', 'reward', 300.00, 'delivered', '99 Brand St', 'Los Angeles', 'CA', '90015', 'FedEx', '987654321012', 'Gregory Sterling (CEO)', 'CEO Excellence Award: HR System Deployment', '4a9df364-58ad-4fa9-83bc-2234559c5d01', now() - INTERVAL '6 days'),
    -- BlueStar Retail: retain, Sweet Box, Tom Collins, $90.00
    (gen_random_uuid(), '5d1933c0-0f0e-4361-b472-3c8cfa2b9876', '8b1933c0-0f0e-4361-b472-3c8cfa2b9807', '9b1933c0-0f0e-4361-b472-3c8cfa2b9821', 'retain', 90.00, 'delivered', '78 Retail Way', 'Seattle', 'WA', '98101', 'UPS', '1Z9A29810300123457', 'Tom Collins (Rep)', 'Customer Retention: Contract Anniversary', '4a9df364-58ad-4fa9-83bc-2234559c5d01', now() - INTERVAL '6 days'),
    -- Apex Solutions: reach, Sweet Box, System Engine, Awaiting Owner Approval, Custom ($90.00)
    ('6f1933c0-0f0e-4361-b472-3c8cfa2b9891', '5d1933c0-0f0e-4361-b472-3c8cfa2b9867', '8b1933c0-0f0e-4361-b472-3c8cfa2b9801', '9b1933c0-0f0e-4361-b472-3c8cfa2b9821', 'reach', 90.00, 'awaiting_approval', '100 Tech Way', 'San Jose', 'CA', '95112', NULL, NULL, 'AI Automated Engine', 'Outbound Pipeline: Warm Prospect Nudge', '4a9df364-58ad-4fa9-83bc-2234559c5d01', NULL),
    -- Peak Financial: retain, Premium Box, Tom Collins, Awaiting Design & Quote, Custom ($300.00)
    ('6f1933c0-0f0e-4361-b472-3c8cfa2b9892', '5d1933c0-0f0e-4361-b472-3c8cfa2b9877', '8b1933c0-0f0e-4361-b472-3c8cfa2b9807', '9b1933c0-0f0e-4361-b472-3c8cfa2b9823', 'retain', 300.00, 'awaiting_design', '44 Financial Dr', 'New York', 'NY', '10005', NULL, NULL, 'Tom Collins (Rep)', 'Contract renewal appreciation', '4a9df364-58ad-4fa9-83bc-2234559c5d01', NULL),
    -- Nova Financial: remember, Premium Box, System Engine, Quote Ready, $300.00
    ('6f1933c0-0f0e-4361-b472-3c8cfa2b9893', '5d1933c0-0f0e-4361-b472-3c8cfa2b9875', '8b1933c0-0f0e-4361-b472-3c8cfa2b9801', '9b1933c0-0f0e-4361-b472-3c8cfa2b9823', 'remember', 300.00, 'quote_ready', '200 Health Ave', 'Seattle', 'WA', '98104', NULL, NULL, 'AI Automated Engine', 'B2B Relationship Anniversary', '4a9df364-58ad-4fa9-83bc-2234559c5d01', NULL),
    -- Chevron Logistics: reach, Pack Box, Tom Collins, Awaiting Owner Approval, Custom ($80.00)
    ('6f1933c0-0f0e-4361-b472-3c8cfa2b9894', '5d1933c0-0f0e-4361-b472-3c8cfa2b9871', '8b1933c0-0f0e-4361-b472-3c8cfa2b9807', '9b1933c0-0f0e-4361-b472-3c8cfa2b9822', 'reach', 80.00, 'awaiting_approval', '78 Logistics Way', 'Chicago', 'IL', '60606', NULL, NULL, 'Tom Collins (Rep)', '1 year partnership anniversary', '4a9df364-58ad-4fa9-83bc-2234559c5d01', NULL)
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 8. SEED CALENDAR EVENTS
-- ----------------------------------------------------------------------------
INSERT INTO public.calendar_events (profile_id, type, target, event_date, event_time, agenda, workspace_id)
VALUES
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9801', 'Performance Review', 'Tom Collins', '2026-05-27', '10:00:00', 'Review sales pipelines and healthcare account activity. Focus on conversion drop.', '4a9df364-58ad-4fa9-83bc-2234559c5d01'),
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9801', 'Client Strategic Meeting', 'Nova Healthcare', '2026-05-29', '14:30:00', 'Discuss premium confections shipment and Q2 contract renewal.', '4a9df364-58ad-4fa9-83bc-2234559c5d01'),
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9801', 'Performance Review', 'Sarah Lansky', '2026-06-02', '11:00:00', 'HR workflow assessment and workload balance check-in. Sentiment is high risk.', '4a9df364-58ad-4fa9-83bc-2234559c5d01'),
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9801', 'Milestone Gift Delivery', 'Aero Dynamics', '2026-06-05', '13:00:00', 'Verify VIP customer anniversary sweet box reception.', '4a9df364-58ad-4fa9-83bc-2234559c5d01')
;

-- ----------------------------------------------------------------------------
-- 9. SEED OPERATIONAL NUDGES
-- ----------------------------------------------------------------------------
INSERT INTO public.nudges (profile_id, message, severity, is_read, workspace_id)
VALUES
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9801', 'Vanguard Health has exceeded 84 days of inactivity. Touchpoint recommended.', 'critical', false, '4a9df364-58ad-4fa9-83bc-2234559c5d01'),
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9801', 'Sarah Lansky resolved 14 warnings in 4 days. Monitor team burnout.', 'warning', false, '4a9df364-58ad-4fa9-83bc-2234559c5d01'),
    ('8b1933c0-0f0e-4361-b472-3c8cfa2b9801', 'Tom Collins conversion rate dropped 12% in healthcare accounts.', 'critical', false, '4a9df364-58ad-4fa9-83bc-2234559c5d01')
;

-- ----------------------------------------------------------------------------
-- 10. SEED COSMO JARVIS AI AUDITS
-- ----------------------------------------------------------------------------
INSERT INTO public.cosmo_audits (contact_id, narrative, severity, workspace_id)
VALUES
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9869', 'Vanguard Health exceeded threshold inactivity levels (34 days neglected). Systematic review of healthcare AE pipelines recommended.', 'critical', '4a9df364-58ad-4fa9-83bc-2234559c5d01'),
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9875', 'Nova Financial has Q3 contract renewal approaching in June. Health index is strong at 91%. Suggest milestone Sweet Box dispatch to lock retention.', 'info', '4a9df364-58ad-4fa9-83bc-2234559c5d01'),
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9871', 'Chevron Logistics has remained a prospect for 42 days with zero manual touches. Recommend outbound AE warming outreach.', 'warning', '4a9df364-58ad-4fa9-83bc-2234559c5d01')
;

-- ----------------------------------------------------------------------------
-- 11. SEED FUMBLE RECOVERY BOARD REQUESTS
-- ----------------------------------------------------------------------------
INSERT INTO public.recovery_requests (contact_id, original_rep_id, requester_rep_id, justification, status, workspace_id)
VALUES
    -- Vanguard Health in recovery board, claimed by Marcus Dupond
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9869', '8b1933c0-0f0e-4361-b472-3c8cfa2b9808', '8b1933c0-0f0e-4361-b472-3c8cfa2b9805', 'Outlined 3-step outbound gifting sequence to restore relationship.', 'pending', '4a9df364-58ad-4fa9-83bc-2234559c5d01'),
    -- Chevron Logistics in recovery board, claimed by Tom Collins
    ('5d1933c0-0f0e-4361-b472-3c8cfa2b9871', '8b1933c0-0f0e-4361-b472-3c8cfa2b9805', '8b1933c0-0f0e-4361-b472-3c8cfa2b9807', 'Targeting VP of procurement with warm cold warming executive box.', 'pending', '4a9df364-58ad-4fa9-83bc-2234559c5d01')
;

-- ----------------------------------------------------------------------------
-- 12. SEED REASSIGNMENT HISTORY (CONTACT ASSIGNMENTS)
-- ----------------------------------------------------------------------------
INSERT INTO public.contact_assignments (workspace_id, contact_id, previous_rep_id, new_rep_id, assigned_by, justification)
VALUES
    ('4a9df364-58ad-4fa9-83bc-2234559c5d01', '5d1933c0-0f0e-4361-b472-3c8cfa2b9869', '8b1933c0-0f0e-4361-b472-3c8cfa2b9807', '8b1933c0-0f0e-4361-b472-3c8cfa2b9801', '8b1933c0-0f0e-4361-b472-3c8cfa2b9801', 'Owner emergency intervention: account inactive for 84 days.')
;

-- ----------------------------------------------------------------------------
-- 13. RE-ENABLE TRIGGERS
-- Restore trigger activity post-seeding to ensure normal security enforcement.
-- ----------------------------------------------------------------------------
ALTER TABLE auth.users ENABLE TRIGGER on_auth_user_created;
ALTER TABLE public.profiles ENABLE TRIGGER check_role_escalation;

-- Commit database changes
COMMIT;
