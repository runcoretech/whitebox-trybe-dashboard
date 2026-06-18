-- 0009_rep_scoreboard.sql
-- Leaderboard rebuild (item 5, folds in item 2). Two parts.
--
-- PART 1 — a SAFE, privileged "scoreboard" so the rep leaderboard can rank reps
-- by the real Performance Score WITHOUT opening the locked customer-data door,
-- AND without exposing peers' raw stats (book size, activity volume, etc.).
--
-- Problem: to rank reps by score, the system must know EVERY rep's score — but a
-- rep's RLS hides colleagues' books/activities, so the app can't compute others'
-- scores when a rep is logged in. Solution: this view runs with the owner's
-- privileges (default — NOT security_invoker), so it aggregates across the whole
-- workspace. It is scoped to the caller's workspace via get_my_workspace() (RLS
-- is bypassed, so this scope is load-bearing — mirrors the get_kpi_summary
-- pattern). Crucially it emits ONLY {id, name, score} — the standings. The raw
-- aggregates are computed in internal CTEs and never leave the view, so even a
-- direct API call reveals nothing but each rep's final score (the "standings
-- only" privacy decision, enforced at the data layer, not just the UI).
--
-- !! The score formula below MIRRORS lib/dashboard-data.ts (repPerformance +
--    bookHealthPctFrom + relQualityFrom + activityScoreFromCount + GRADE_SCORE +
--    getInactivityStatus's 30/60 bands + ACTIVITY_TARGET=20). If any of those
--    change, update this view to match. This duplication is the price of NOT
--    exposing raw peer stats, and it is GUARDED by an automated consistency check
--    (scripts/verify-leaderboard-consistency.mjs) that fails if a rep's
--    leaderboard score ever diverges from their Overview score. Reps are scored
--    on their OWN three pillars only (no manager/exec rollups here). !!
--
-- PART 2 — harden leaderboard_live: turn ON security_invoker so a rep can no
-- longer read every colleague's raw numbers by querying that view directly. The
-- owner/exec Overview is unaffected (their RLS spans the workspace); the manager
-- Overview only uses rows for their own reports (which their RLS can see); the
-- rep leaderboard no longer touches this view. Verified before/after.
--
-- Reversible: re-running drops + recreates the view; leaderboard_live can be
-- reset with ALTER VIEW ... RESET (security_invoker).

-- ===== PART 1: rep_scoreboard (standings only) =============================
drop view if exists public.rep_scoreboard;

create view public.rep_scoreboard as
with agg as (
  select
    p.id,
    p.name,
    coalesce(bk.book_total, 0)  as bt,
    coalesce(bk.book_green, 0)  as bg,
    coalesce(bk.book_orange, 0) as bo,
    ql.qual_sum                 as qs,   -- null when no graded touchpoints
    coalesce(ql.qual_count, 0)  as qc,
    coalesce(ac.act_count, 0)   as ac
  from public.profiles p
  -- BOOK HEALTH inputs: per assigned contact, days since ANYONE last touched it
  -- (all-touch recency, matching 0006), bucketed by the SAME 30/60 thresholds
  -- as getInactivityStatus().
  left join lateral (
    select
      count(*)                                                       as book_total,
      count(*) filter (where d.last_days < 30)                       as book_green,
      count(*) filter (where d.last_days >= 30 and d.last_days < 60) as book_orange
    from (
      select coalesce(date_part('day', now() - max(a.logged_at)), 999) as last_days
      from public.contacts c
      left join public.activities a
        on a.contact_id = c.id and a.workspace_id = p.workspace_id
      where c.assigned_rep_id = p.id and c.workspace_id = p.workspace_id
      group by c.id
    ) d
  ) bk on true
  -- RELATIONSHIP QUALITY inputs: grade->score values MIRROR GRADE_SCORE
  -- (A=100,B=100,C=60,D=20,F=20); unknown grades ignored, same as TS.
  left join lateral (
    select
      sum(case g.grade
            when 'A' then 100 when 'B' then 100 when 'C' then 60
            when 'D' then 20  when 'F' then 20  else null end)::numeric as qual_sum,
      count(*) filter (where g.grade in ('A','B','C','D','F'))          as qual_count
    from public.activities g
    where g.rep_id = p.id and g.workspace_id = p.workspace_id and g.grade is not null
  ) ql on true
  -- ACTIVITY input: total touchpoints authored by the rep.
  left join lateral (
    select count(*) as act_count
    from public.activities a2
    where a2.rep_id = p.id and a2.workspace_id = p.workspace_id
  ) ac on true
  where p.role = 'rep'
    and p.status = 'active'
    and p.workspace_id = public.get_my_workspace()  -- load-bearing tenant scope
),
pillars as (
  select
    id, name,
    case when bt > 0 then round((bg + bo * 0.5) / bt * 100) end  as book, -- Book Health %
    case when qc > 0 then round(qs / qc) end                     as rel,  -- Relationship Quality
    case when ac > 0 then least(100, round(ac / 20.0 * 100)) end as act   -- Activity (target 20)
  from agg
)
select
  id,
  name,
  -- weighted blend (0.40 book / 0.35 quality / 0.25 activity), renormalized over
  -- whichever pillars are present; null when the rep has no data at all.
  case
    when book is null and rel is null and act is null then null
    else round(
      (coalesce(book,0) * 0.40 + coalesce(rel,0) * 0.35 + coalesce(act,0) * 0.25)
      / ( (case when book is not null then 0.40 else 0 end)
        + (case when rel  is not null then 0.35 else 0 end)
        + (case when act  is not null then 0.25 else 0 end) )
    )::int
  end as score
from pillars;

-- Least-privilege: logged-in users read the standings; nobody else.
revoke all on public.rep_scoreboard from public;
revoke all on public.rep_scoreboard from anon;
grant select on public.rep_scoreboard to authenticated;

-- ===== PART 2: harden leaderboard_live =====================================
alter view public.leaderboard_live set (security_invoker = on);
