-- 0022_rep_scoreboard_touchpoints_week.sql
-- Make the rep "Team Goal" challenge REAL: expose each rep's touchpoints logged
-- THIS calendar week, own-team-gated (so the squad can see each member's
-- contribution toward a shared weekly goal). Not tied to the prestige toggle —
-- the team goal is a squad activity challenge, separate from the sales ranks.
-- Only change vs 0020: the activities lateral also counts this week + a new
-- touchpoints_week column.

drop view if exists public.rep_scoreboard;

create view public.rep_scoreboard as
with agg as (
  select
    p.id, p.name, p.manager_id,
    coalesce(bk.book_total, 0)  as bt,
    coalesce(bk.book_green, 0)  as bg,
    coalesce(bk.book_orange, 0) as bo,
    ql.qual_sum                 as qs,
    coalesce(ql.qual_count, 0)  as qc,
    coalesce(ac.act_count, 0)   as ac,
    coalesce(ac.act_week, 0)    as aw,
    coalesce(rv.rev, 0)         as rev,
    coalesce(rv.rev_month, 0)   as rev_month
  from public.profiles p
  left join lateral (
    select
      count(*)                                                       as book_total,
      count(*) filter (where d.last_days < 30)                       as book_green,
      count(*) filter (where d.last_days >= 30 and d.last_days < 60) as book_orange
    from (
      select coalesce(date_part('day', now() - max(a.logged_at)), 999) as last_days
      from public.contacts c
      left join public.activities a on a.contact_id = c.id and a.workspace_id = p.workspace_id
      where c.assigned_rep_id = p.id and c.workspace_id = p.workspace_id
      group by c.id
    ) d
  ) bk on true
  left join lateral (
    select
      sum(case g.grade when 'A' then 100 when 'B' then 100 when 'C' then 60 when 'D' then 20 when 'F' then 20 else null end)::numeric as qual_sum,
      count(*) filter (where g.grade in ('A','B','C','D','F')) as qual_count
    from public.activities g
    where g.rep_id = p.id and g.workspace_id = p.workspace_id and g.grade is not null
  ) ql on true
  left join lateral (
    select
      count(*) as act_count,
      count(*) filter (where a2.logged_at >= date_trunc('week', now())) as act_week
    from public.activities a2
    where a2.rep_id = p.id and a2.workspace_id = p.workspace_id
  ) ac on true
  left join lateral (
    select
      coalesce(sum(o.amount), 0) as rev,
      coalesce(sum(o.amount) filter (where o.placed_at >= date_trunc('month', now())), 0) as rev_month
    from public.orders o
    where o.rep_id = p.id and o.workspace_id = p.workspace_id
  ) rv on true
  where p.role = 'rep' and p.status = 'active' and p.workspace_id = public.get_my_workspace()
),
pillars as (
  select
    id, name, manager_id, rev, rev_month, aw,
    case when bt > 0 then round((bg + bo * 0.5) / bt * 100) end  as book,
    case when qc > 0 then round(qs / qc) end                     as rel,
    case when ac > 0 then least(100, round(ac / 20.0 * 100)) end as act,
    case
      when rev >= 10000000 then 7
      when rev >= 1000000  then 6
      when rev >= 500000   then 5
      when rev >= 250000   then 4
      when rev >= 100000   then 3
      when rev >= 25000    then 2
      when rev >= 5000     then 1
      else 0
    end as rank_idx
  from agg
),
caller as (
  select
    (select manager_id from public.profiles where id = auth.uid()) as my_mgr,
    public.get_my_role() as role,
    coalesce((select show_prestige from public.workspace_settings ws where ws.workspace_id = public.get_my_workspace()), false) as show_prestige
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
  case when pl.manager_id is not distinct from c.my_mgr then pl.book::int end as book_health,
  case when pl.manager_id is not distinct from c.my_mgr then pl.rel::int  end as rel_quality,
  case when pl.manager_id is not distinct from c.my_mgr then pl.act::int  end as activity,
  case when pl.manager_id is not distinct from c.my_mgr then pl.aw::int   end as touchpoints_week,
  case when c.show_prestige then pl.rank_idx end as prestige_rank,
  case when c.show_prestige and c.role = any (array['owner','executive']) then pl.rev::numeric       end as revenue,
  case when c.show_prestige and c.role = any (array['owner','executive']) then pl.rev_month::numeric end as revenue_month
from pillars pl
cross join caller c;

revoke all on public.rep_scoreboard from public;
revoke all on public.rep_scoreboard from anon;
revoke all on public.rep_scoreboard from authenticated;
grant select on public.rep_scoreboard to authenticated;
