-- 0015_workspace_settings.sql
-- Add show_prestige to the EXISTING workspace_settings (the company-config table).
-- It already has the right RLS (settings_select = workspace reads;
-- settings_owner_all = owner writes) and a unique workspace_id, so we only add
-- the column. Default OFF (opt-in): the sales-dollar rank badges next to names
-- stay hidden until the owner switches them on.

alter table public.workspace_settings
  add column if not exists show_prestige boolean not null default false;

-- An earlier draft of this migration created duplicate policies before we
-- realized the table already existed; drop them (settings_select /
-- settings_owner_all already cover read + owner-write).
drop policy if exists ws_select on public.workspace_settings;
drop policy if exists ws_owner_write on public.workspace_settings;
