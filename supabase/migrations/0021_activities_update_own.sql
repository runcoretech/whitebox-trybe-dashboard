-- 0021_activities_update_own.sql
-- Let a rep EDIT a touchpoint they logged (type / grade / notes). Activities were
-- insert-only for reps; add an UPDATE policy scoped to the author within their
-- workspace. The with_check keeps the row owned by the same rep + workspace (a
-- rep can't reassign a touchpoint to someone else or move it cross-tenant). The
-- app action only changes type/grade/notes (never logged_at — the decay clock
-- stays honest). Owner keeps full access via activities_owner_all.

drop policy if exists activities_update on public.activities;
create policy activities_update on public.activities
  for update
  using (workspace_id = public.get_my_workspace() and rep_id = auth.uid())
  with check (workspace_id = public.get_my_workspace() and rep_id = auth.uid());
