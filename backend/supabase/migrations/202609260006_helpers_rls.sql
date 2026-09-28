-- Helper functions + RLS + grants
create or replace function private.current_role()
returns public.app_role
language sql
stable
security definer
set search_path = ''
as $$
  select p.role from public.profiles p
  where p.id = (select auth.uid()) and p.status = 'active'::public.user_status
$$;

create or replace function private.current_org_id()
returns uuid
language sql stable security definer set search_path = ''
as $$ select p.organization_id from public.profiles p where p.id=(select auth.uid()) and p.status='active'::public.user_status $$;

create or replace function private.current_department_id()
returns uuid
language sql stable security definer set search_path = ''
as $$ select p.department_id from public.profiles p where p.id=(select auth.uid()) and p.status='active'::public.user_status $$;

create or replace function private.current_team_id()
returns uuid
language sql stable security definer set search_path = ''
as $$ select p.team_id from public.profiles p where p.id=(select auth.uid()) and p.status='active'::public.user_status $$;

create or replace function private.is_active_user()
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.status='active'::public.user_status)
$$;

create or replace function private.can_read_scope(
  p_owner_user_id uuid,
  p_team_id uuid,
  p_department_id uuid,
  p_organization_id uuid
)
returns boolean
language plpgsql stable security definer set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_role public.app_role;
  v_org uuid;
  v_dept uuid;
  v_team uuid;
begin
  if v_uid is null then return false; end if;
  select role, organization_id, department_id, team_id
    into v_role, v_org, v_dept, v_team
  from public.profiles
  where id=v_uid and status='active'::public.user_status;
  if not found then return false; end if;
  if p_organization_id is distinct from v_org then return false; end if;
  case v_role
    when 'sales' then return p_owner_user_id = v_uid;
    when 'team_leader' then return p_owner_user_id = v_uid or (v_team is not null and p_team_id = v_team);
    when 'sales_manager' then return p_owner_user_id = v_uid or (v_dept is not null and p_department_id = v_dept);
    when 'admin' then return true;
  end case;
  return false;
end;
$$;

create or replace function private.can_assign_to_user(p_target_user_id uuid)
returns boolean
language plpgsql stable security definer set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_role public.app_role;
  v_org uuid; v_dept uuid; v_team uuid;
  t_org uuid; t_dept uuid; t_team uuid; t_status public.user_status;
begin
  select role, organization_id, department_id, team_id into v_role,v_org,v_dept,v_team
  from public.profiles where id=v_uid and status='active'::public.user_status;
  if not found then return false; end if;
  select organization_id, department_id, team_id, status into t_org,t_dept,t_team,t_status
  from public.profiles where id=p_target_user_id;
  if not found or t_status <> 'active'::public.user_status or t_org is distinct from v_org then return false; end if;
  case v_role
    when 'sales' then return p_target_user_id=v_uid;
    when 'team_leader' then return p_target_user_id=v_uid or (v_team is not null and t_team=v_team);
    when 'sales_manager' then return p_target_user_id=v_uid or (v_dept is not null and t_dept=v_dept);
    when 'admin' then return true;
  end case;
  return false;
end;
$$;

create or replace function private.is_admin_for_org(p_org uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists(
    select 1 from public.profiles p
    where p.id=(select auth.uid()) and p.status='active'::public.user_status
      and p.role='admin'::public.app_role and p.organization_id=p_org
  )
$$;

create or replace function private.normalize_search_text(p_value text)
returns text
language sql stable set search_path = ''
as $$
  select nullif(trim(regexp_replace(extensions.unaccent(lower(coalesce(p_value,''))), '\s+', ' ', 'g')), '')
$$;

create or replace function private.normalize_contact(p_type public.contact_type, p_value text)
returns text
language plpgsql stable set search_path = ''
as $$
declare
  v text := trim(coalesce(p_value,''));
  d text;
begin
  if v='' then return null; end if;
  case p_type
    when 'phone' then
      d := regexp_replace(v, '[^0-9]', '', 'g');
      if left(d,2)='84' and length(d)>=10 then d := '0' || substr(d,3); end if;
      return nullif(d,'');
    when 'email' then return lower(v);
    when 'facebook' then return regexp_replace(lower(v), '[/?#]+$', '', 'g');
    when 'messenger' then return lower(v);
    when 'tiktok' then return regexp_replace(lower(v), '[/?#]+$', '', 'g');
    when 'zalo' then return lower(regexp_replace(v, '\s+', '', 'g'));
    else return lower(v);
  end case;
end;
$$;

revoke all on schema private from public, anon;
grant usage on schema private to authenticated;
revoke execute on all functions in schema private from public, anon;
grant execute on function private.current_role() to authenticated;
grant execute on function private.current_org_id() to authenticated;
grant execute on function private.current_department_id() to authenticated;
grant execute on function private.current_team_id() to authenticated;
grant execute on function private.is_active_user() to authenticated;
grant execute on function private.can_read_scope(uuid,uuid,uuid,uuid) to authenticated;
grant execute on function private.can_assign_to_user(uuid) to authenticated;
grant execute on function private.is_admin_for_org(uuid) to authenticated;
grant execute on function private.normalize_search_text(text) to authenticated;
grant execute on function private.normalize_contact(public.contact_type,text) to authenticated;

-- Enable RLS on every exposed table
alter table public.organizations enable row level security;
alter table public.departments enable row level security;
alter table public.teams enable row level security;
alter table public.profiles enable row level security;
alter table public.lead_sources enable row level security;
alter table public.pipeline_stages enable row level security;
alter table public.lost_reasons enable row level security;
alter table public.products enable row level security;
alter table public.product_variants enable row level security;
alter table public.task_types enable row level security;
alter table public.care_rules enable row level security;
alter table public.customers enable row level security;
alter table public.customer_contacts enable row level security;
alter table public.opportunities enable row level security;
alter table public.tasks enable row level security;
alter table public.activities enable row level security;
alter table public.quotes enable row level security;
alter table public.pipeline_history enable row level security;
alter table public.work_schedule_blocks enable row level security;
alter table public.targets enable row level security;
alter table public.notifications enable row level security;
alter table public.audit_logs enable row level security;

-- Start from least privilege
revoke all on all tables in schema public from anon;
revoke all on all tables in schema public from authenticated;

grant select on public.organizations, public.departments, public.teams, public.profiles,
  public.lead_sources, public.pipeline_stages, public.lost_reasons, public.products,
  public.product_variants, public.task_types, public.care_rules,
  public.customers, public.customer_contacts, public.opportunities, public.tasks,
  public.activities, public.quotes, public.pipeline_history, public.work_schedule_blocks,
  public.targets, public.notifications, public.audit_logs to authenticated;

grant update on public.organizations to authenticated;
grant insert, update on public.departments, public.teams to authenticated;
grant insert, update on public.lead_sources, public.pipeline_stages, public.lost_reasons,
  public.products, public.product_variants, public.task_types, public.care_rules to authenticated;
grant insert, update on public.customers, public.customer_contacts, public.opportunities,
  public.tasks, public.work_schedule_blocks to authenticated;
grant update on public.notifications to authenticated;
grant insert, update on public.targets to authenticated;

-- Organization hierarchy read/admin policies
create policy org_read on public.organizations for select to authenticated
using ((select private.is_active_user()) and id=(select private.current_org_id()));
create policy org_admin_update on public.organizations for update to authenticated
using ((select private.is_admin_for_org(id))) with check ((select private.is_admin_for_org(id)));

create policy dept_read on public.departments for select to authenticated
using ((select private.is_active_user()) and organization_id=(select private.current_org_id()));
create policy dept_admin_insert on public.departments for insert to authenticated
with check ((select private.is_admin_for_org(organization_id)));
create policy dept_admin_update on public.departments for update to authenticated
using ((select private.is_admin_for_org(organization_id))) with check ((select private.is_admin_for_org(organization_id)));

create policy team_read on public.teams for select to authenticated
using ((select private.is_active_user()) and organization_id=(select private.current_org_id()));
create policy team_admin_insert on public.teams for insert to authenticated
with check ((select private.is_admin_for_org(organization_id)));
create policy team_admin_update on public.teams for update to authenticated
using ((select private.is_admin_for_org(organization_id))) with check ((select private.is_admin_for_org(organization_id)));

create policy profile_read on public.profiles for select to authenticated
using ((select private.can_read_scope(id,team_id,department_id,organization_id)));

-- Master data helpers: all active org users read; only admins write
create policy source_read on public.lead_sources for select to authenticated
using ((select private.is_active_user()) and organization_id=(select private.current_org_id()));
create policy source_admin_insert on public.lead_sources for insert to authenticated with check ((select private.is_admin_for_org(organization_id)));
create policy source_admin_update on public.lead_sources for update to authenticated using ((select private.is_admin_for_org(organization_id))) with check ((select private.is_admin_for_org(organization_id)));

create policy stage_read on public.pipeline_stages for select to authenticated
using ((select private.is_active_user()) and organization_id=(select private.current_org_id()));
create policy stage_admin_insert on public.pipeline_stages for insert to authenticated with check ((select private.is_admin_for_org(organization_id)));
create policy stage_admin_update on public.pipeline_stages for update to authenticated using ((select private.is_admin_for_org(organization_id))) with check ((select private.is_admin_for_org(organization_id)));

create policy lost_reason_read on public.lost_reasons for select to authenticated
using ((select private.is_active_user()) and organization_id=(select private.current_org_id()));
create policy lost_reason_admin_insert on public.lost_reasons for insert to authenticated with check ((select private.is_admin_for_org(organization_id)));
create policy lost_reason_admin_update on public.lost_reasons for update to authenticated using ((select private.is_admin_for_org(organization_id))) with check ((select private.is_admin_for_org(organization_id)));

create policy product_read on public.products for select to authenticated
using ((select private.is_active_user()) and organization_id=(select private.current_org_id()));
create policy product_admin_insert on public.products for insert to authenticated with check ((select private.is_admin_for_org(organization_id)));
create policy product_admin_update on public.products for update to authenticated using ((select private.is_admin_for_org(organization_id))) with check ((select private.is_admin_for_org(organization_id)));

create policy variant_read on public.product_variants for select to authenticated
using ((select private.is_active_user()) and exists(select 1 from public.products p where p.id=product_id and p.organization_id=(select private.current_org_id())));
create policy variant_admin_insert on public.product_variants for insert to authenticated
with check (exists(select 1 from public.products p where p.id=product_id and (select private.is_admin_for_org(p.organization_id))));
create policy variant_admin_update on public.product_variants for update to authenticated
using (exists(select 1 from public.products p where p.id=product_id and (select private.is_admin_for_org(p.organization_id))))
with check (exists(select 1 from public.products p where p.id=product_id and (select private.is_admin_for_org(p.organization_id))));

create policy task_type_read on public.task_types for select to authenticated
using ((select private.is_active_user()) and organization_id=(select private.current_org_id()));
create policy task_type_admin_insert on public.task_types for insert to authenticated with check ((select private.is_admin_for_org(organization_id)));
create policy task_type_admin_update on public.task_types for update to authenticated using ((select private.is_admin_for_org(organization_id))) with check ((select private.is_admin_for_org(organization_id)));

create policy care_rule_read on public.care_rules for select to authenticated
using ((select private.is_active_user()) and organization_id=(select private.current_org_id()));
create policy care_rule_admin_insert on public.care_rules for insert to authenticated with check ((select private.is_admin_for_org(organization_id)));
create policy care_rule_admin_update on public.care_rules for update to authenticated using ((select private.is_admin_for_org(organization_id))) with check ((select private.is_admin_for_org(organization_id)));

-- CRM read policies
create policy customer_read on public.customers for select to authenticated
using ((select private.can_read_scope(owner_user_id,team_id,department_id,organization_id)));
create policy contact_read on public.customer_contacts for select to authenticated
using ((select private.can_read_scope(owner_user_id,team_id,department_id,organization_id)));
create policy opportunity_read on public.opportunities for select to authenticated
using ((select private.can_read_scope(owner_user_id,team_id,department_id,organization_id)));
create policy task_read on public.tasks for select to authenticated
using ((select private.can_read_scope(assigned_user_id,team_id,department_id,organization_id)));
create policy activity_read on public.activities for select to authenticated
using ((select private.can_read_scope(owner_user_id,team_id,department_id,organization_id)));
create policy quote_read on public.quotes for select to authenticated
using ((select private.can_read_scope(owner_user_id,team_id,department_id,organization_id)));
create policy pipeline_history_read on public.pipeline_history for select to authenticated
using ((select private.can_read_scope(owner_user_id,team_id,department_id,organization_id)));

-- Direct write policies are intentionally narrow; business actions should prefer RPCs.
create policy customer_insert_self on public.customers for insert to authenticated
with check (
  (select private.is_active_user()) and owner_user_id=(select auth.uid())
  and organization_id=(select private.current_org_id())
  and department_id is not distinct from (select private.current_department_id())
  and team_id is not distinct from (select private.current_team_id())
);
create policy customer_update_owner on public.customers for update to authenticated
using (owner_user_id=(select auth.uid()))
with check (
  owner_user_id=(select auth.uid())
  and organization_id=(select private.current_org_id())
  and department_id is not distinct from (select private.current_department_id())
  and team_id is not distinct from (select private.current_team_id())
);

create policy contact_insert_owner on public.customer_contacts for insert to authenticated
with check (
  owner_user_id=(select auth.uid()) and organization_id=(select private.current_org_id())
  and department_id is not distinct from (select private.current_department_id())
  and team_id is not distinct from (select private.current_team_id())
  and exists(select 1 from public.customers c where c.id=customer_id and c.owner_user_id=(select auth.uid()))
);
create policy contact_update_owner on public.customer_contacts for update to authenticated
using (owner_user_id=(select auth.uid()))
with check (
  owner_user_id=(select auth.uid()) and organization_id=(select private.current_org_id())
  and department_id is not distinct from (select private.current_department_id())
  and team_id is not distinct from (select private.current_team_id())
  and exists(select 1 from public.customers c where c.id=customer_id and c.owner_user_id=(select auth.uid()))
);

create policy opportunity_insert_owner on public.opportunities for insert to authenticated
with check (
  owner_user_id=(select auth.uid()) and organization_id=(select private.current_org_id())
  and department_id is not distinct from (select private.current_department_id())
  and team_id is not distinct from (select private.current_team_id())
  and exists(select 1 from public.customers c where c.id=customer_id and c.owner_user_id=(select auth.uid()))
  and exists(select 1 from public.lead_sources ls where ls.id=source_id and ls.organization_id=(select private.current_org_id()))
  and exists(select 1 from public.pipeline_stages ps where ps.id=stage_id and ps.organization_id=(select private.current_org_id()))
);
create policy opportunity_update_owner on public.opportunities for update to authenticated
using (owner_user_id=(select auth.uid())) with check (
  owner_user_id=(select auth.uid()) and organization_id=(select private.current_org_id())
  and department_id is not distinct from (select private.current_department_id())
  and team_id is not distinct from (select private.current_team_id())
);

create policy task_insert_self on public.tasks for insert to authenticated
with check (
  assigned_user_id=(select auth.uid()) and organization_id=(select private.current_org_id())
  and department_id is not distinct from (select private.current_department_id())
  and team_id is not distinct from (select private.current_team_id())
  and (customer_id is null or exists(select 1 from public.customers c where c.id=customer_id and c.owner_user_id=(select auth.uid())))
);
create policy task_update_assignee on public.tasks for update to authenticated
using (assigned_user_id=(select auth.uid()))
with check (
  assigned_user_id=(select auth.uid()) and organization_id=(select private.current_org_id())
  and department_id is not distinct from (select private.current_department_id())
  and team_id is not distinct from (select private.current_team_id())
);

create policy schedule_read on public.work_schedule_blocks for select to authenticated
using ((select private.can_read_scope(user_id,team_id,department_id,organization_id)));
create policy schedule_insert_self on public.work_schedule_blocks for insert to authenticated
with check (user_id=(select auth.uid()) and organization_id=(select private.current_org_id()));
create policy schedule_update_self on public.work_schedule_blocks for update to authenticated
using (user_id=(select auth.uid())) with check (
  user_id=(select auth.uid()) and organization_id=(select private.current_org_id())
  and department_id is not distinct from (select private.current_department_id())
  and team_id is not distinct from (select private.current_team_id())
);

create policy target_read on public.targets for select to authenticated
using (
  (select private.is_active_user()) and organization_id=(select private.current_org_id()) and
  case (select private.current_role())
    when 'sales'::public.app_role then user_id=(select auth.uid())
    when 'team_leader'::public.app_role then user_id=(select auth.uid()) or team_id=(select private.current_team_id())
    when 'sales_manager'::public.app_role then department_id=(select private.current_department_id())
    when 'admin'::public.app_role then true
  end
);
create policy target_admin_insert on public.targets for insert to authenticated with check ((select private.is_admin_for_org(organization_id)));
create policy target_admin_update on public.targets for update to authenticated using ((select private.is_admin_for_org(organization_id))) with check ((select private.is_admin_for_org(organization_id)));

create policy notification_self_read on public.notifications for select to authenticated using (user_id=(select auth.uid()));
create policy notification_self_update on public.notifications for update to authenticated using (user_id=(select auth.uid())) with check (user_id=(select auth.uid()));

create policy audit_manager_read on public.audit_logs for select to authenticated
using (
  organization_id=(select private.current_org_id()) and
  (
    (select private.current_role())='admin'::public.app_role
    or ((select private.current_role())='sales_manager'::public.app_role and department_id=(select private.current_department_id()))
  )
);
