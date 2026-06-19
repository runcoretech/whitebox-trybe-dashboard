-- 0011_claimable_excludes_self.sql
-- Fix: the Recovery "fumble queue" hid an account from the very rep claiming it.
--
-- is_contact_claimable() is the RLS gate that lets a rep SELECT a neglected
-- account they don't own (so it can appear on the Recovery Board and its profile
-- can load). It measured neglect from the LAST touch by ANYONE. But the claim flow
-- requires the rep to log a fresh 'Call' before claiming — and that call is itself
-- a touch, so the moment they logged it the account flipped to "not claimable",
-- RLS stopped surfacing it, the profile re-fetched as null, and the Claim panel
-- vanished mid-claim.
--
-- The claim FUNCTION (claim_contact) and the profile UI (daysFromOthers) already
-- judge staleness by "neglect BY SOMEONE ELSE" — i.e. they ignore the claimant's
-- own touches. This brings the RLS gate in line: neglect is measured from the last
-- touch by anyone OTHER than the viewer (rep_id IS DISTINCT FROM auth.uid()), so a
-- rep's own fresh claim-call no longer un-stales the account and hides it from
-- them. Everything else about the function is preserved verbatim.
--
-- Why this is safe app-wide: for a rep's OWN accounts this gate is irrelevant (a
-- separate RLS clause already grants them their own book). It only governs the
-- shared claimable pool, where "has the OWNER (and everyone but me) neglected this
-- 75+ days?" is exactly the right question.

create or replace function public.is_contact_claimable(cid uuid)
 returns boolean
 language plpgsql
 stable security definer
 set search_path to 'public'
as $function$
declare
    inactive_days integer;
    critical_days integer;
    my_ws uuid;
    contact_exists boolean;
begin
    my_ws := public.get_my_workspace();
    if my_ws is null then
        return false;
    end if;

    -- Tenant Isolation Lock: Ensure contact belongs to current workspace
    select exists (
        select 1 from public.contacts
        where id = cid and workspace_id = my_ws
    ) into contact_exists;

    if not contact_exists then
        return false;
    end if;

    -- Days since the last touch BY SOMEONE OTHER THAN THE VIEWER. Excluding the
    -- viewer's own touches means their fresh claim-call doesn't reset this and hide
    -- the account from them mid-claim (matches claim_contact + the profile UI).
    select coalesce(date_part('day', now() - max(logged_at)), 999) into inactive_days
    from public.activities
    where contact_id = cid and workspace_id = my_ws
      and rep_id is distinct from auth.uid();

    -- Fetch workspace settings critical neglect threshold
    select decay_critical into critical_days
    from public.workspace_settings where workspace_id = my_ws;

    -- Open pool triggers 15 days after critical neglect threshold (e.g., 75 days if critical=60)
    if inactive_days >= (critical_days + 15) then
        return true;
    end if;
    return false;
end;
$function$;
