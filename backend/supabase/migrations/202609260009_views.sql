-- Safe convenience views; security_invoker makes underlying RLS apply.
create or replace view public.v_customer_summary
with (security_invoker=true)
as
select
  c.id,
  c.display_name,
  c.owner_user_id,
  c.team_id,
  c.department_id,
  c.source_id,
  ls.name as source_name,
  c.created_at,
  c.first_response_at,
  c.last_activity_at,
  (select cc.raw_value from public.customer_contacts cc where cc.customer_id=c.id order by cc.is_primary desc,cc.created_at limit 1) as primary_contact,
  (select o.id from public.opportunities o where o.customer_id=c.id and o.status in ('active','paused') order by o.created_at desc limit 1) as active_opportunity_id
from public.customers c
join public.lead_sources ls on ls.id=c.source_id
where not c.is_archived;

grant select on public.v_customer_summary to authenticated;

create or replace view public.v_task_summary
with (security_invoker=true)
as
select t.*, (t.status='pending'::public.task_status and t.due_at<now()) as is_overdue, tt.display_name as task_type_name
from public.tasks t join public.task_types tt on tt.id=t.task_type_id;

grant select on public.v_task_summary to authenticated;
