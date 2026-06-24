-- 0013_rep_scoreboard_prestige_metrics.sql
-- Expose the raw achievement METRICS on rep_scoreboard so the app can compute
-- each rep's PRESTIGE RANK (the "badge next to your name" — see
-- lib/achievements.ts) and show it next to teammates on the My Team squad cards.
--
-- WHY metrics (not the computed rank): the achievement tier thresholds + rank
-- ladder live in ONE place (lib/achievements.ts) and are still being tuned. We
-- expose the four stable COUNTS and compute tiers + rank in the app — so a
-- teammate's rank is computed by the exact same code as their own profile (no
-- SQL/TS drift, no threshold duplication).
--
-- WHAT'S ADDED vs 0012: touchpoints, a_grades, accounts, active_months.
-- touchpoints (act_count) and accounts (book_total) were already computed
-- internally; a_grades and active_months are new internal aggregates.
--
-- PRIVACY / LEAST-PRIVILEGE (consistent with 0012):
--   * `score` stays workspace-wide (standings + leaderboard).
--   * The three pillar sub-scores AND these four raw metrics are returned ONLY
--     for the caller's OWN team (same manager_id). Other teams come back NULL.
--   * This is a deliberate, owner-aligned TRANSPARENCY decision: within a squad,
--     teammates can see each other's achievement standing (the gamified flex).
--     It does expose own-team activity volume + book size — acceptable within a
--     team per the transparency mandate; NOT exposed across teams or tenants.
--   * Cross-tenant scope (get_my_workspace) + SELECT-only grant preserved.
--
-- Reversible: re-run 0012 to drop the four metric columns.

drop view if exists public.rep_scoreboard;

create view public.rep_scoreboard as
with agg as (
  select
    p.id,
    p.name,
    p.manager_id,
    coalesce(bk.book_total, 0)     as bt,
    coalesce(bk.book_green, 0)     as bg,
    coalesce(bk.book_orange, 0)    as bo,
    ql.qual_sum                    as qs,
    coalesce(ql.qual_count, 0)     as qc,
    coalesce(ql.a_count, 0)        as ag,   -- A-grade touchpoints
    coalesce(ac.act_count, 0)      as ac,
    coalesce(ac.active_months, 0)  as am    -- distinct months with activity
  from public.profiles p
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
  left join lateral (
    select
      sum(case g.grade
            when 'A' then 100 when 'B' then 100 when 'C' then 60
            when 'D' then 20  when 'F' then 20  else null end)::numeric as qual_sum,
      count(*) filter (where g.grade in ('A','B','C','D','F'))          as qual_count,
      count(*) filter (where g.grade = 'A')                            as a_count
    from public.activities g
    where g.rep_id = p.id and g.workspace_id = p.workspace_id and g.grade is not null
  ) ql on true
  left join lateral (
    select
      count(*)                                              as act_count,
      count(distinct date_trunc('month', a2.logged_at))    as active_months
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
    bt as accounts_raw,
    ac as touchpoints_raw,
    ag as agrades_raw,
    am as months_raw,
    case when bt > 0 then round((bg + bo * 0.5) / bt * 100) end  as book,
    case when qc > 0 then round(qs / qc) end                     as rel,
    case when ac > 0 then least(100, round(ac / 20.0 * 100)) end as act
  from agg
),
caller as (
  select (select manager_id from public.profiles where id = auth.uid()) as my_mgr
)
select
  pl.id,
  pl.name,
  case
    when pl.book is null and pl.rel is null and pl.act is null then null
    else round(
      (coalesce(pl.book,0) * 0.40 + coalesce(pl.rel,0) * 0.35 + coalesce(pl.act,0) * 0.25)
      / ( (case when pl.book is not null then 0.40 else 0 end)
        + (case when pl.rel  is not null then 0.35 else 0 end)
        + (case when pl.act  is not null then 0.25 else 0 end) )
    )::int
  end as score,
  -- pillar sub-scores (own-team only)
  case when pl.manager_id is not distinct from c.my_mgr then pl.book::int end as book_health,
  case when pl.manager_id is not distinct from c.my_mgr then pl.rel::int  end as rel_quality,
  case when pl.manager_id is not distinct from c.my_mgr then pl.act::int  end as activity,
  -- raw achievement metrics for prestige (own-team only)
  case when pl.manager_id is not distinct from c.my_mgr then pl.touchpoints_raw::int end as touchpoints,
  case when pl.manager_id is not distinct from c.my_mgr then pl.agrades_raw::int     end as a_grades,
  case when pl.manager_id is not distinct from c.my_mgr then pl.accounts_raw::int    end as accounts,
  case when pl.manager_id is not distinct from c.my_mgr then pl.months_raw::int      end as active_months
from pillars pl
cross join caller c;

-- Least-privilege: authenticated may only READ; anon/public get nothing.
revoke all on public.rep_scoreboard from public;
revoke all on public.rep_scoreboard from anon;
revoke all on public.rep_scoreboard from authenticated;
grant select on public.rep_scoreboard to authenticated;
