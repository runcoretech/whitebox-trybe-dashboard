-- ============================================================
-- DATABASE SEED DATA SCRIPT
-- ============================================================

-- 1. Seed Workspace
INSERT INTO public.workspaces (id, name, subdomain)
VALUES ('d290f1ee-6c54-4b01-90e6-d701748f0851', 'WhiteBox Headquarters', 'app');

-- 2. Seed Settings
INSERT INTO public.workspace_settings (workspace_id, decay_warning, decay_critical, target_conversion, budget_monthly, budget_milestone)
VALUES ('d290f1ee-6c54-4b01-90e6-d701748f0851', 30, 60, 48, 10000.00, 45.00);

-- 3. Seed Auth Users (Will trigger profile creation via public.handle_new_user trigger)
-- Assumes pgcrypto extension is active for password crypt hashing
CREATE EXTENSION IF NOT EXISTS pgcrypto;

INSERT INTO auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
VALUES
  (
    'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'authenticated', 'authenticated', 
    'owner@whitebox.com', crypt('wb_owner_2026!', gen_salt('bf')), now(), 
    '{"provider":"email","providers":["email"]}', 
    '{"name":"Paul K.","role":"owner","workspace_id":"d290f1ee-6c54-4b01-90e6-d701748f0851"}', 
    now(), now()
  ),
  (
    'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a12', 'authenticated', 'authenticated', 
    'executive@whitebox.com', crypt('wb_exec_2026!', gen_salt('bf')), now(), 
    '{"provider":"email","providers":["email"]}', 
    '{"name":"Sarah Lansky","role":"hr","workspace_id":"d290f1ee-6c54-4b01-90e6-d701748f0851"}', 
    now(), now()
  ),
  (
    'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a13', 'authenticated', 'authenticated', 
    'manager@whitebox.com', crypt('wb_mgr_2026!', gen_salt('bf')), now(), 
    '{"provider":"email","providers":["email"]}', 
    '{"name":"Marcus Dupond","role":"manager","workspace_id":"d290f1ee-6c54-4b01-90e6-d701748f0851","manager_id":"a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11"}', 
    now(), now()
  ),
  (
    'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a14', 'authenticated', 'authenticated', 
    'rep@whitebox.com', crypt('wb_rep_2026!', gen_salt('bf')), now(), 
    '{"provider":"email","providers":["email"]}', 
    '{"name":"Tom Collins","role":"rep","workspace_id":"d290f1ee-6c54-4b01-90e6-d701748f0851","manager_id":"a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a13"}', 
    now(), now()
  );

-- 4. Seed Organizations
INSERT INTO public.organizations (id, name, sector, category, workspace_id)
VALUES
  ('c0a80101-0000-0000-0000-000000000001', 'Chevron Logistics', 'Logistics', 'enterprise', 'd290f1ee-6c54-4b01-90e6-d701748f0851'),
  ('c0a80101-0000-0000-0000-000000000002', 'Apex Global Retail', 'Retail', 'enterprise', 'd290f1ee-6c54-4b01-90e6-d701748f0851'),
  ('c0a80101-0000-0000-0000-000000000003', 'Vanguard Health', 'Healthcare', 'enterprise', 'd290f1ee-6c54-4b01-90e6-d701748f0851'),
  ('c0a80101-0000-0000-0000-000000000004', 'Stripe Canada', 'Finance', 'enterprise', 'd290f1ee-6c54-4b01-90e6-d701748f0851'),
  ('c0a80101-0000-0000-0000-000000000005', 'Nova Financial', 'Finance', 'enterprise', 'd290f1ee-6c54-4b01-90e6-d701748f0851'),
  ('c0a80101-0000-0000-0000-000000000006', 'Globex International', 'Conglomerate', 'smb', 'd290f1ee-6c54-4b01-90e6-d701748f0851'),
  ('c0a80101-0000-0000-0000-000000000007', 'Initech Software', 'Technology', 'smb', 'd290f1ee-6c54-4b01-90e6-d701748f0851'),
  ('c0a80101-0000-0000-0000-000000000008', 'OmniCorp Tech', 'Technology', 'prospect', 'd290f1ee-6c54-4b01-90e6-d701748f0851'),
  ('c0a80101-0000-0000-0000-000000000009', 'TechFlow Inc', 'Software', 'prospect', 'd290f1ee-6c54-4b01-90e6-d701748f0851');

-- 5. Seed Contacts
INSERT INTO public.contacts (id, org_id, name, email, phone, assigned_rep_id, status, relationship_health, workspace_id)
VALUES
  ('c0a80202-0000-0000-0000-000000000001', 'c0a80101-0000-0000-0000-000000000001', 'Chevron Operations Team', 'chevron@whitebox.com', '555-0101', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a14', 'active', 82, 'd290f1ee-6c54-4b01-90e6-d701748f0851'),
  ('c0a80202-0000-0000-0000-000000000002', 'c0a80101-0000-0000-0000-000000000002', 'Apex Executive Suite', 'apex@whitebox.com', '555-0102', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a14', 'active', 94, 'd290f1ee-6c54-4b01-90e6-d701748f0851'),
  ('c0a80202-0000-0000-0000-000000000003', 'c0a80101-0000-0000-0000-000000000003', 'Vanguard Management', 'vanguard@whitebox.com', '555-0103', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a14', 'inactive', 45, 'd290f1ee-6c54-4b01-90e6-d701748f0851'),
  ('c0a80202-0000-0000-0000-000000000004', 'c0a80101-0000-0000-0000-000000000004', 'Stripe CS Dept', 'stripe@whitebox.com', '555-0104', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a14', 'active', 96, 'd290f1ee-6c54-4b01-90e6-d701748f0851'),
  ('c0a80202-0000-0000-0000-000000000005', 'c0a80101-0000-0000-0000-000000000005', 'Nova Financial CS', 'nova@whitebox.com', '555-0105', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a14', 'active', 91, 'd290f1ee-6c54-4b01-90e6-d701748f0851');

-- 6. Seed Touchpoints Activities
INSERT INTO public.activities (contact_id, rep_id, type, grade, notes, workspace_id, logged_at)
VALUES
  ('c0a80202-0000-0000-0000-000000000001', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a14', 'Call', 'A', 'Touchpoint conversation. Very receptive and aligned.', 'd290f1ee-6c54-4b01-90e6-d701748f0851', now() - interval '2 days'),
  ('c0a80202-0000-0000-0000-000000000002', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a14', 'Meeting', 'B', 'Strategic QBR review. Formulated Q3 targets.', 'd290f1ee-6c54-4b01-90e6-d701748f0851', now() - interval '5 days'),
  ('c0a80202-0000-0000-0000-000000000003', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a14', 'Email', 'F', 'Outreach email bounced. Inactivity alarm active.', 'd290f1ee-6c54-4b01-90e6-d701748f0851', now() - interval '34 days');

-- 7. Seed Gifts (Active & Historical Dispatches)
INSERT INTO public.gifts (contact_id, rep_id, confection_type, category, amount, status, sender_label, reason, workspace_id, dispatched_at)
VALUES
  ('c0a80202-0000-0000-0000-000000000002', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a14', 'Premium Box', 'retain', 180.00, 'delivered', 'WhiteBox Team', 'Strategic Partner Q2 Milestone Appreciation', 'd290f1ee-6c54-4b01-90e6-d701748f0851', now() - interval '10 days'),
  ('c0a80202-0000-0000-0000-000000000001', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a14', 'Sweet Box', 'reach', 45.00, 'delivered', 'WhiteBox Team', 'Quarterly Service Excellence Appreciation', 'd290f1ee-6c54-4b01-90e6-d701748f0851', now() - interval '4 days'),
  ('c0a80202-0000-0000-0000-000000000004', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a14', 'Pack Box', 'reward', 90.00, 'pending', 'WhiteBox Team', 'Milestone Celebration Box', 'd290f1ee-6c54-4b01-90e6-d701748f0851', now() - interval '1 hour');

-- 8. Seed Nudges
INSERT INTO public.nudges (profile_id, message, severity, workspace_id)
VALUES
  ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a14', 'Vanguard Health has entered Red Alert zone due to 34 days of inactivity.', 'critical', 'd290f1ee-6c54-4b01-90e6-d701748f0851');

-- 9. Seed Cosmo AI Audits
INSERT INTO public.cosmo_audits (contact_id, narrative, severity, workspace_id)
VALUES
  ('c0a80202-0000-0000-0000-000000000001', 'Chevron Logistics has decayed to 82% health with zero manual touches in 42 days. We recommend a physical premium box dispatch to reset momentum.', 'warning', 'd290f1ee-6c54-4b01-90e6-d701748f0851');
