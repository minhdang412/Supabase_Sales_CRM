-- Reapply the complete fixed RPC for DEV installations that already ran 013.
-- v1.1: server-side customer filters used by Customers UI.
create or replace function public.search_customers_filtered(
  p_query text default null,
  p_quick_filter text default 'all',
  p_source_id uuid default null,
  p_stage_id uuid default null,
  p_limit int default 25,
  p_offset int default 0
)
returns table(
  customer_id uuid,
  display_name text,
  source_id uuid,
  source_name text,
  last_activity_at timestamptz,
  primary_contact text,
  next_task_at timestamptz,
  active_opportunity jsonb
)
language sql
security definer
set search_path = ''
as $$
  with q as (
    select private.normalize_search_text(p_query) as s
  ), visible as (
    select c.*
    from public.customers c
    where not c.is_archived
      and (select private.can_read_scope(c.owner_user_id,c.team_id,c.department_id,c.organization_id))
  ), enriched as (
    select
      c.id,
      c.display_name,
      c.normalized_display_name,
      c.source_id,
      ls.name as source_name,
      c.last_activity_at,
      (select cc.raw_value
         from public.customer_contacts cc
        where cc.customer_id=c.id
        order by cc.is_primary desc, cc.created_at
        limit 1) as primary_contact,
      (select min(t.due_at)
         from public.tasks t
        where t.customer_id=c.id
          and t.status='pending'::public.task_status) as next_task_at,
      (select jsonb_build_object(
          'id',o.id,
          'product_id',o.product_id,
          'variant_id',o.variant_id,
          'stage_id',o.stage_id,
          'status',o.status,
          'priority',o.priority,
          'potential_level',o.potential_level
        )
         from public.opportunities o
        where o.customer_id=c.id
          and o.status in ('active','paused')
        order by o.created_at desc
        limit 1) as active_opportunity,
      (select o.potential_level
         from public.opportunities o
        where o.customer_id=c.id
          and o.status in ('active','paused')
        order by o.created_at desc
        limit 1) as potential_level,
      (select o.priority
         from public.opportunities o
        where o.customer_id=c.id
          and o.status in ('active','paused')
        order by o.created_at desc
        limit 1) as priority,
      (select o.stage_id
         from public.opportunities o
        where o.customer_id=c.id
          and o.status in ('active','paused')
        order by o.created_at desc
        limit 1) as stage_id,
      c.organization_id,
      c.updated_at
    from visible c
    join public.lead_sources ls on ls.id=c.source_id
  )
  select
    e.id,
    e.display_name,
    e.source_id,
    e.source_name,
    e.last_activity_at,
    e.primary_contact,
    e.next_task_at,
    e.active_opportunity
  from enriched e
  cross join q
  where
    (q.s is null
      or e.normalized_display_name ilike '%'||q.s||'%'
      or exists(
        select 1
        from public.customer_contacts cc
        where cc.customer_id=e.id
          and cc.normalized_value ilike '%'||q.s||'%'
      ))
    and (p_source_id is null or e.source_id=p_source_id)
    and (p_stage_id is null or e.stage_id=p_stage_id)
    and (
      coalesce(p_quick_filter,'all')='all'
      or (p_quick_filter='hot' and e.potential_level='hot'::public.potential_level)
      or (p_quick_filter='high' and e.priority='high'::public.priority_level)
      or (p_quick_filter='no_next' and e.next_task_at is null)
      or (
        p_quick_filter='stale'
        and (
          e.last_activity_at is null
          or e.last_activity_at < now() - make_interval(hours => coalesce(
            (select cr.max_inactive_hours
               from public.care_rules cr
              where cr.organization_id=e.organization_id
                and cr.potential_level=coalesce(e.potential_level,'watch'::public.potential_level)
                and cr.is_active
              limit 1),
            72
          ))
        )
      )
    )
  order by e.updated_at desc
  limit greatest(1,least(coalesce(p_limit,25),100))
  offset greatest(coalesce(p_offset,0),0)
$$;

revoke execute on function public.search_customers_filtered(text,text,uuid,uuid,int,int) from public, anon;
grant execute on function public.search_customers_filtered(text,text,uuid,uuid,int,int) to authenticated;
