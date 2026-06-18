-- 0006_per_relationship_decay.sql
-- Decay = days since ANYONE last touched the account (relationship recency),
-- not days since the *viewing* rep touched it. A manager's (or anyone's) touch
-- now resets the clock/health for everyone, incl. the assigned rep.
--
-- Why a DB change: the decay view runs with the caller's permissions
-- (security_invoker), and a rep can only see their OWN activities via RLS, so it
-- was effectively counting only the rep's touches. We move the "last touch"
-- calculation into a SECURITY DEFINER helper so it counts EVERY touch on the
-- contact — but scoped to the caller's workspace so it can't probe other tenants.
-- Additive + reversible (CREATE OR REPLACE; no data is modified).

-- 1) Last touch on a contact across all reps, workspace-scoped.
create or replace function public.contact_last_touch(cid uuid)
returns timestamptz
language sql
stable
security definer
set search_path = public
as $$
  select max(logged_at)
  from public.activities
  where contact_id = cid
    and workspace_id = public.get_my_workspace();
$$;

-- 2) Decay view now derives recency from contact_last_touch() (all touches).
--    Contact VISIBILITY is unchanged (security_invoker => the caller still only
--    sees contacts their RLS allows); only the recency math changed.
create or replace view public.contacts_decay_status
with (security_invoker = on) as
select
  c.id as contact_id,
  c.name as contact_name,
  c.workspace_id,
  -- Keep double precision (the column's existing type) so CREATE OR REPLACE VIEW
  -- is allowed — it cannot change an existing column's data type. Invisible to
  -- the app (JS reads it as a number regardless).
  coalesce(date_part('day', now() - la.last_activity), 999::double precision) as inactive_days,
  greatest(0, least(100,
    case
      when la.last_activity is null then 0
      when date_part('day', now() - la.last_activity) <= ws.decay_warning then 100
      else 100 - ((date_part('day', now() - la.last_activity) - ws.decay_warning) * ws.decay_factor)
    end))::integer as computed_health
from public.contacts c
join public.workspace_settings ws on ws.workspace_id = c.workspace_id
left join lateral (select public.contact_last_touch(c.id) as last_activity) la on true;
