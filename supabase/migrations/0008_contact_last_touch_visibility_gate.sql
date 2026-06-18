-- 0008_contact_last_touch_visibility_gate.sql
-- Hardens the 0006 SECURITY DEFINER function for two issues found by the
-- 2026-06-18 adversarial security review (both CONFIRMED reproducible).
-- Cross-tenant isolation was NEVER affected and remains intact (proven via the
-- "Eve Tenant" canary in a second workspace).
--
--   (LOW)  Intra-workspace timestamp leak: any authenticated user could call
--          contact_last_touch(cid) directly (bypassing the contacts_decay_status
--          view) and learn the LAST-TOUCH TIMESTAMP of a contact that RLS hides
--          from them, if they knew its (unguessable, random v4) UUID. Only a
--          timestamp leaks — never name/contact/notes/owner. Verified: rep "Tom"
--          gets 0 rows for "Apex Pipeline" via the view, but a timestamp via RPC.
--   (INFO) Least-privilege: anon/PUBLIC held EXECUTE with no legitimate use
--          (they get NULL today, but it is needless surface).
--
-- FIX (part 1): gate the function to return a value ONLY for contacts the CALLER
-- may SELECT, by re-checking the contacts visibility rule with session-scoped
-- functions (auth.uid()/get_my_role()/is_contact_claimable). These return the
-- CALLER's values even inside a SECURITY DEFINER function, so the check is real.
-- (A SECURITY INVOKER *helper* called from inside this DEFINER function would NOT
-- work — it inherits the elevated context — which is why we gate inline here.)
-- The function still bypasses the per-rep RLS on `activities` (its purpose:
-- all-touch recency) but no longer bypasses the rule on which CONTACTS are visible.
--
-- !! MIRRORS the `contacts_select` policy from migration 0003. If that policy
--    changes, update this gate to match. !!
--
-- Verified 2026-06-18: contacts_decay_status output is identical for all roles
-- before/after (the view only ever lists visible contacts); the direct-RPC leak
-- returns NULL after; cross-tenant stays sealed; a manager touch still resets the
-- rep's clock. Additive + reversible (CREATE OR REPLACE).

create or replace function public.contact_last_touch(cid uuid)
returns timestamptz
language sql
stable
security definer
set search_path = public
as $$
  select max(a.logged_at)
  from public.activities a
  where a.contact_id = cid
    and a.workspace_id = public.get_my_workspace()
    and exists (
      select 1
      from public.contacts c
      where c.id = cid
        and c.workspace_id = public.get_my_workspace()
        and (
          public.get_my_role() = any (array['owner','executive'])
          or (public.get_my_role() = 'manager' and (
                c.assigned_rep_id = auth.uid()
                or c.assigned_rep_id in (select id from public.profiles where manager_id = auth.uid())
                or public.is_contact_claimable(c.id) = true))
          or (public.get_my_role() = 'rep' and (
                c.assigned_rep_id = auth.uid()
                or public.is_contact_claimable(c.id) = true))
        )
    );
$$;

-- FIX (part 2): least-privilege. Only logged-in users need this; the view
-- (security_invoker) requires the CALLER to hold EXECUTE, so we keep authenticated.
revoke execute on function public.contact_last_touch(uuid) from public;
revoke execute on function public.contact_last_touch(uuid) from anon;
grant  execute on function public.contact_last_touch(uuid) to authenticated;
