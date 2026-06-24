-- 0014_orders.sql
-- ORDERS LEDGER — the hard-dollars record, kept SEPARATE from `activities` on
-- purpose. A touchpoint = "I tended the relationship" (graded, drives health +
-- the activity score). An order = "they bought" (a dollar amount). Keeping money
-- in its own table means logging a sale never inflates the touchpoint/activity/
-- achievement metrics, and it's the clean foundation for the dollar-based
-- ranking + future billing (recurring just = log it again).
--
-- RLS MIRRORS public.activities exactly (owner all; rep/manager/exec insert;
-- rep sees own, manager sees own + direct reports, owner/exec see workspace).
-- Financial data is workspace-isolated like everything else.

create table if not exists public.orders (
  id           uuid primary key default gen_random_uuid(),
  contact_id   uuid not null references public.contacts(id) on delete cascade,
  rep_id       uuid not null references public.profiles(id),
  workspace_id uuid not null,
  amount       numeric(14,2) not null check (amount >= 0),
  notes        text,
  placed_at    timestamptz not null default now()
);

create index if not exists orders_contact_idx   on public.orders (contact_id);
create index if not exists orders_rep_idx        on public.orders (rep_id);
create index if not exists orders_workspace_idx  on public.orders (workspace_id);

alter table public.orders enable row level security;

-- Owner: full access within their workspace.
drop policy if exists orders_owner_all on public.orders;
create policy orders_owner_all on public.orders
  for all
  using (workspace_id = public.get_my_workspace() and public.get_my_role() = 'owner');

-- Insert: must be in your workspace; a rep can only file orders under their own
-- id; manager/exec/owner may file on behalf of others.
drop policy if exists orders_insert on public.orders;
create policy orders_insert on public.orders
  for insert
  with check (
    workspace_id = public.get_my_workspace()
    and (rep_id = auth.uid() or public.get_my_role() = any (array['owner','executive','manager']))
  );

-- Select: owner/exec see the workspace; manager sees own + direct reports; rep
-- sees their own. (Identical shape to activities_select.)
drop policy if exists orders_select on public.orders;
create policy orders_select on public.orders
  for select
  using (
    workspace_id = public.get_my_workspace()
    and (
      public.get_my_role() = any (array['owner','executive'])
      or (public.get_my_role() = 'manager' and (
            rep_id = auth.uid()
            or rep_id in (select id from public.profiles where manager_id = auth.uid())
          ))
      or (public.get_my_role() = 'rep' and rep_id = auth.uid())
    )
  );

grant select, insert, update, delete on public.orders to authenticated;
revoke all on public.orders from anon;
