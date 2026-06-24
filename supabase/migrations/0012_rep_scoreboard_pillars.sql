-- 0012_rep_scoreboard_pillars.sql
-- Expose the three Performance Score PILLARS on rep_scoreboard so the rep
-- "My Team" squad cards can show a score breakdown (Book Health 40% +
-- Relationship Quality 35% + Activity 25%), not just the final number.
--
-- WHAT CHANGES vs 0009: the `pillars` CTE ALREADY computes book/rel/act inside
-- the view; 0009 deliberately emitted only {id, name, score}. This adds the three
-- pillar sub-scores to the SELECT. The score FORMULA is unchanged (still mirrors
-- lib/dashboard-data.ts, still guarded by verify-leaderboard-consistency.mjs), so
-- the displayed breakdown is internally consistent with the score it explains.
--
-- LEAST-PRIVILEGE / PRIVACY:
--   * `score` stays visible for EVERY active rep in the workspace — it powers the
--     org-wide team standings + the leaderboard (lib/leaderboards.ts), which only
--     read the final score, never the pillars.
--   * The three pillar sub-scores are returned ONLY for reps on the CALLER's own
--     team (same manager_id, including the caller). For everyone else they are
--     NULL. This mirrors exactly what the UI shows (a rep only sees teammates'
--     breakdowns) and the established pattern that individual detail = your team,
--     cross-team = aggregates only.
--   * Even within the team, the exposed pillars are the SAME normalized 0-100
--     sub-scores used in the blend — NOT raw aggregates. Book Health is a
--     percentage (reveals nothing about book SIZE), Relationship Quality is an
--     average grade, Activity is a target-normalized score (capped at 100). No
--     customer rows, names, or book counts ever leave the view.
--   * The load-bearing tenant scope (get_my_workspace()) and least-privilege
--     grants are preserved, so cross-tenant isolation is unchanged: a caller sees
--     only their own workspace's reps.
--
-- Reversible: re-run 0009 to collapse back to {id, name, score}.

drop view if exists public.rep_scoreboard;

create view public.rep_scoreboard as
with agg as (
  select
    p.id,
    p.name,
    p.manager_id,
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
    id, name, manager_id,
    case when bt > 0 then round((bg + bo * 0.5) / bt * 100) end  as book, -- Book Health %
    case when qc > 0 then round(qs / qc) end                     as rel,  -- Relationship Quality
    case when ac > 0 then least(100, round(ac / 20.0 * 100)) end as act   -- Activity (target 20)
  from agg
),
-- The caller's own team key (their manager_id), computed ONCE. Always exactly one
-- row (the scalar is NULL when the caller has no profile / no manager), so the
-- cross join below never eliminates rows.
caller as (
  select (select manager_id from public.profiles where id = auth.uid()) as my_mgr
)
select
  pl.id,
  pl.name,
  -- weighted blend (0.40 book / 0.35 quality / 0.25 activity), renormalized over
  -- whichever pillars are present; null when the rep has no data at all. Visible
  -- for every rep in the workspace (standings + leaderboard need it).
  case
    when pl.book is null and pl.rel is null and pl.act is null then null
    else round(
      (coalesce(pl.book,0) * 0.40 + coalesce(pl.rel,0) * 0.35 + coalesce(pl.act,0) * 0.25)
      / ( (case when pl.book is not null then 0.40 else 0 end)
        + (case when pl.rel  is not null then 0.35 else 0 end)
        + (case when pl.act  is not null then 0.25 else 0 end) )
    )::int
  end as score,
  -- The three pillar sub-scores behind that number — exposed ONLY for the
  -- caller's own teammates (same manager_id). NULL for other teams and for
  -- pillars with no data. Standings-grade, normalized, never raw counts.
  case when pl.manager_id is not distinct from c.my_mgr then pl.book::int end as book_health,
  case when pl.manager_id is not distinct from c.my_mgr then pl.rel::int  end as rel_quality,
  case when pl.manager_id is not distinct from c.my_mgr then pl.act::int  end as activity
from pillars pl
cross join caller c;

-- Least-privilege: logged-in users may only READ the standings; nobody else.
-- We revoke ALL from authenticated first (Supabase default privileges otherwise
-- grant new views full DML to authenticated; the view isn't updatable so those
-- writes are inert, but we strip them anyway so the grant matches the intent),
-- then grant back only SELECT.
revoke all on public.rep_scoreboard from public;
revoke all on public.rep_scoreboard from anon;
revoke all on public.rep_scoreboard from authenticated;
grant select on public.rep_scoreboard to authenticated;
