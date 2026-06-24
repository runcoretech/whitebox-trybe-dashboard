-- 0019_orders_insert_own_account.sql
-- SECURITY FIX (found by adversarial review): a rep could credit themselves
-- revenue by logging an order on an account that ISN'T theirs — specifically a
-- claimable Recovery-pool account (a colleague's 75-day-neglected account, which
-- contacts_select makes visible). The old orders_insert only checked
-- workspace + rep_id = auth.uid(), not that the contact was assigned to them.
--
-- Fix: a rep may only file an order (rep_id = themselves) on a contact ASSIGNED
-- to them. To sell to a claimable account they must CLAIM it first (then it's
-- theirs). Owner/executive/manager keep the on-behalf path (trusted roles).

drop policy if exists orders_insert on public.orders;
create policy orders_insert on public.orders
  for insert
  with check (
    workspace_id = public.get_my_workspace()
    and (
      (
        rep_id = auth.uid()
        and contact_id in (
          select id from public.contacts
          where assigned_rep_id = auth.uid()
            and workspace_id = public.get_my_workspace()
        )
      )
      or public.get_my_role() = any (array['owner', 'executive', 'manager'])
    )
  );
