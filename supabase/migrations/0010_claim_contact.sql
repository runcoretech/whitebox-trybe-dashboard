-- 0010_claim_contact.sql
-- Recovery Board "fumble queue" claim.
--
-- A rep/manager CLAIMS a neglected account (75+ days untouched, owned by someone
-- else) by actually phoning the contact: they log a fresh 'Call', then claim,
-- which reassigns the account to them. A rep's RLS cannot UPDATE an account they
-- don't own, so this SECURITY DEFINER function performs the reassignment with all
-- the gates checked INSIDE it (so it cannot be abused to grab arbitrary accounts).
--
-- Gates (all must pass): caller is an active rep/manager in the workspace; the
-- contact is in that workspace and not already theirs; the account is CLAIMABLE
-- (most recent touch BY SOMEONE ELSE is >= decay_critical+15 days ago, or none —
-- the caller's own fresh call is excluded so logging it doesn't un-stale it); and
-- the caller logged a 'Call' on this contact in the last 60 minutes ("you must
-- actually phone them to claim it"). Returns a status text for the UI.

create or replace function public.claim_contact(cid uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  caller   uuid := auth.uid();
  my_ws    uuid := public.get_my_workspace();
  my_role  text := public.get_my_role();
  threshold integer;
  current_owner uuid;
  contact_in_ws boolean;
  last_other timestamptz;
  has_fresh_call boolean;
begin
  -- Active rep/manager only.
  if my_ws is null or my_role is null or my_role not in ('rep', 'manager') then
    return 'denied';
  end if;

  select exists(select 1 from public.contacts where id = cid and workspace_id = my_ws)
    into contact_in_ws;
  if not contact_in_ws then
    return 'not_found';
  end if;

  select assigned_rep_id into current_owner
  from public.contacts where id = cid and workspace_id = my_ws;
  if current_owner = caller then
    return 'already_yours';
  end if;

  -- CLAIMABLE: most recent touch by SOMEONE ELSE >= threshold days ago (or none).
  select decay_critical + 15 into threshold
  from public.workspace_settings where workspace_id = my_ws;
  select max(a.logged_at) into last_other
  from public.activities a
  where a.contact_id = cid and a.workspace_id = my_ws and a.rep_id is distinct from caller;
  if not (last_other is null or date_part('day', now() - last_other) >= coalesce(threshold, 75)) then
    return 'not_claimable';
  end if;

  -- FRESH CALL gate: a 'Call' by the caller on this contact in the last 60 minutes.
  select exists(
    select 1 from public.activities a
    where a.contact_id = cid and a.workspace_id = my_ws
      and a.rep_id = caller and a.type = 'Call'
      and a.logged_at >= now() - interval '60 minutes'
  ) into has_fresh_call;
  if not has_fresh_call then
    return 'must_call';
  end if;

  -- All gates passed — claim it. The contacts reassignment guard
  -- (prevent_direct_reassignments) blocks direct assigned_rep_id changes; this
  -- transaction-local flag marks THIS as the sanctioned claim path.
  perform set_config('app.allow_claim', '1', true);
  update public.contacts set assigned_rep_id = caller
  where id = cid and workspace_id = my_ws;
  return 'claimed';
end;
$$;

revoke execute on function public.claim_contact(uuid) from anon, public;
grant execute on function public.claim_contact(uuid) to authenticated;

-- Extend the existing reassignment guard to ALSO allow the sanctioned claim path
-- (claim_contact sets app.allow_claim after its own gates). All prior protections
-- — owner bypass, approved-recovery-request bypass, and the hard block for
-- everyone else — are preserved verbatim.
create or replace function public.prevent_direct_reassignments()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
begin
    if old.assigned_rep_id is distinct from new.assigned_rep_id then
        -- Sanctioned Recovery claim (claim_contact passed claimable + fresh-call gates).
        if coalesce(current_setting('app.allow_claim', true), '') = '1' then
            return new;
        end if;

        -- Allow if updated by Owner
        if public.get_my_role() = 'owner' then
            return new;
        end if;

        -- Verify that an approved recovery request exists in this transaction
        if not exists (
            select 1 from public.recovery_requests
            where contact_id = new.id
              and requester_rep_id = new.assigned_rep_id
              and status = 'approved'::public.recovery_status
              and updated_at > now() - interval '1 second'
        ) then
            raise exception 'Access Denied: Direct contact ownership reassignments are blocked. Use the Recovery Request system.';
        end if;
    end if;
    return new;
end;
$function$;
