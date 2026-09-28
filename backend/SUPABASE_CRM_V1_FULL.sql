-- FRESH DATABASE ONLY. Existing DEV: use supabase db push for unapplied migrations.

-- ===== 202609260001_extensions_types.sql =====
-- Sales CRM v1 - Extensions, schemas, enums
create schema if not exists private;
create schema if not exists extensions;

create extension if not exists pgcrypto with schema extensions;
create extension if not exists pg_trgm with schema extensions;
create extension if not exists unaccent with schema extensions;

create type public.app_role as enum ('sales','team_leader','sales_manager','admin');
create type public.user_status as enum ('active','locked');
create type public.contact_type as enum ('phone','email','facebook','messenger','tiktok','zalo','other');
create type public.opportunity_status as enum ('active','paused','won','lost');
create type public.potential_level as enum ('hot','potential','watch');
create type public.potential_mode as enum ('auto','manual');
create type public.priority_level as enum ('normal','high');
create type public.purchase_timeline as enum ('now','within_7_days','within_month','one_to_three_months','over_three_months','unknown');
create type public.payment_type as enum ('cash','loan','unknown');
create type public.task_status as enum ('pending','completed','cancelled');
create type public.quote_status as enum ('draft','sent','accepted','expired');
create type public.activity_type as enum (
  'lead_created','call','message','consultation','appointment','meeting',
  'quote_sent','test_drive','negotiation','deposit','delivery','note','other'
);


-- ===== 202609260002_org_profiles.sql =====
-- Organization hierarchy + user profiles
create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  timezone text not null default 'Asia/Ho_Chi_Minh',
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.departments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  name text not null,
  code text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (organization_id, code)
);

create table public.teams (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  department_id uuid not null references public.departments(id),
  name text not null,
  leader_user_id uuid,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  organization_id uuid references public.organizations(id),
  department_id uuid references public.departments(id),
  team_id uuid references public.teams(id),
  full_name text,
  phone text,
  role public.app_role not null default 'sales',
  status public.user_status not null default 'locked',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.teams
  add constraint teams_leader_user_fk foreign key (leader_user_id) references public.profiles(id);

create or replace function private.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name, role, status)
  values (
    new.id,
    nullif(trim(coalesce(new.raw_user_meta_data->>'full_name','')), ''),
    'sales'::public.app_role,
    'locked'::public.user_status
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

revoke all on function private.handle_new_auth_user() from public, anon, authenticated;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function private.handle_new_auth_user();


-- ===== 202609260003_master_data.sql =====
-- Configurable master data
create table public.lead_sources (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  parent_id uuid references public.lead_sources(id),
  code text not null,
  name text not null,
  category text,
  sort_order integer not null default 100,
  is_priority boolean not null default false,
  response_sla_minutes integer,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (organization_id, code),
  check (response_sla_minutes is null or response_sla_minutes > 0)
);

create table public.pipeline_stages (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  code text not null,
  display_name text not null,
  sort_order integer not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (organization_id, code)
);

create table public.lost_reasons (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  code text not null,
  display_name text not null,
  sort_order integer not null default 100,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (organization_id, code)
);

create table public.products (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  brand text not null default 'MG',
  name text not null,
  code text not null,
  sort_order integer not null default 100,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (organization_id, code)
);

create table public.product_variants (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id),
  name text not null,
  code text not null,
  list_price numeric(15,2),
  sort_order integer not null default 100,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (product_id, code),
  check (list_price is null or list_price >= 0)
);

create table public.task_types (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  code text not null,
  display_name text not null,
  activity_type public.activity_type,
  sort_order integer not null default 100,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (organization_id, code)
);

create table public.care_rules (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  potential_level public.potential_level not null,
  max_inactive_hours integer not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (organization_id, potential_level),
  check (max_inactive_hours > 0)
);


-- ===== 202609260004_crm_tables.sql =====
-- CRM transactional tables
create table public.customers (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  department_id uuid references public.departments(id),
  team_id uuid references public.teams(id),
  owner_user_id uuid not null references public.profiles(id),
  source_id uuid not null references public.lead_sources(id),
  display_name text not null,
  normalized_display_name text,
  note text,
  first_response_at timestamptz,
  last_activity_at timestamptz,
  is_archived boolean not null default false,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.customer_contacts (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.customers(id),
  organization_id uuid not null references public.organizations(id),
  department_id uuid references public.departments(id),
  team_id uuid references public.teams(id),
  owner_user_id uuid not null references public.profiles(id),
  contact_type public.contact_type not null,
  raw_value text not null,
  normalized_value text,
  is_primary boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.opportunities (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.customers(id),
  organization_id uuid not null references public.organizations(id),
  department_id uuid references public.departments(id),
  team_id uuid references public.teams(id),
  owner_user_id uuid not null references public.profiles(id),
  source_id uuid not null references public.lead_sources(id),
  product_id uuid references public.products(id),
  variant_id uuid references public.product_variants(id),
  stage_id uuid not null references public.pipeline_stages(id),
  status public.opportunity_status not null default 'active',
  potential_level public.potential_level not null default 'watch',
  potential_mode public.potential_mode not null default 'auto',
  priority public.priority_level not null default 'normal',
  purchase_timeline public.purchase_timeline not null default 'unknown',
  expected_purchase_date date,
  budget_min numeric(15,2),
  budget_max numeric(15,2),
  payment_type public.payment_type not null default 'unknown',
  loan_ratio numeric(5,2),
  current_vehicle_note text,
  wants_trade_in boolean not null default false,
  competitor_note text,
  note text,
  contacted_at timestamptz,
  qualified_at timestamptz,
  quoted_at timestamptz,
  appointment_at timestamptz,
  test_drive_at timestamptz,
  deposit_at timestamptz,
  paused_until timestamptz,
  won_at timestamptz,
  lost_at timestamptz,
  closed_at timestamptz,
  lost_reason_id uuid references public.lost_reasons(id),
  lost_note text,
  final_sale_price numeric(15,2),
  last_activity_at timestamptz,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (budget_min is null or budget_min >= 0),
  check (budget_max is null or budget_max >= 0),
  check (budget_min is null or budget_max is null or budget_max >= budget_min),
  check (loan_ratio is null or (loan_ratio >= 0 and loan_ratio <= 100)),
  check (final_sale_price is null or final_sale_price >= 0)
);

create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid references public.customers(id),
  opportunity_id uuid references public.opportunities(id),
  organization_id uuid not null references public.organizations(id),
  department_id uuid references public.departments(id),
  team_id uuid references public.teams(id),
  assigned_user_id uuid not null references public.profiles(id),
  task_type_id uuid not null references public.task_types(id),
  source_task_id uuid references public.tasks(id),
  title text not null,
  note text,
  due_at timestamptz not null,
  priority public.priority_level not null default 'normal',
  status public.task_status not null default 'pending',
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  cancelled_at timestamptz
);

create table public.activities (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.customers(id),
  opportunity_id uuid references public.opportunities(id),
  task_id uuid references public.tasks(id),
  organization_id uuid not null references public.organizations(id),
  department_id uuid references public.departments(id),
  team_id uuid references public.teams(id),
  owner_user_id uuid not null references public.profiles(id),
  activity_type public.activity_type not null,
  result_code text,
  note text,
  occurred_at timestamptz not null default now(),
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  is_voided boolean not null default false,
  voided_at timestamptz,
  voided_by uuid references public.profiles(id)
);

create table public.quotes (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.customers(id),
  opportunity_id uuid not null references public.opportunities(id),
  organization_id uuid not null references public.organizations(id),
  department_id uuid references public.departments(id),
  team_id uuid references public.teams(id),
  owner_user_id uuid not null references public.profiles(id),
  version integer not null,
  product_id uuid references public.products(id),
  variant_id uuid references public.product_variants(id),
  list_price numeric(15,2),
  discount_amount numeric(15,2),
  final_price numeric(15,2),
  promotion_note text,
  storage_path text,
  status public.quote_status not null default 'draft',
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  sent_at timestamptz,
  accepted_at timestamptz,
  unique (opportunity_id, version),
  check (version > 0),
  check (list_price is null or list_price >= 0),
  check (discount_amount is null or discount_amount >= 0),
  check (final_price is null or final_price >= 0)
);

create table public.pipeline_history (
  id uuid primary key default gen_random_uuid(),
  opportunity_id uuid not null references public.opportunities(id),
  organization_id uuid not null references public.organizations(id),
  department_id uuid references public.departments(id),
  team_id uuid references public.teams(id),
  owner_user_id uuid not null references public.profiles(id),
  from_stage_id uuid references public.pipeline_stages(id),
  to_stage_id uuid not null references public.pipeline_stages(id),
  changed_by uuid not null references public.profiles(id),
  changed_at timestamptz not null default now()
);

create table public.work_schedule_blocks (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  department_id uuid references public.departments(id),
  team_id uuid references public.teams(id),
  user_id uuid not null references public.profiles(id),
  day_of_week smallint not null,
  start_time time not null,
  end_time time not null,
  title text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  check (day_of_week between 0 and 6),
  check (end_time > start_time)
);

create table public.targets (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  department_id uuid references public.departments(id),
  team_id uuid references public.teams(id),
  user_id uuid references public.profiles(id),
  metric_code text not null,
  period_start date not null,
  period_end date not null,
  target_value numeric(15,2) not null,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  check (period_end >= period_start),
  check (target_value >= 0)
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id),
  type text not null,
  title text not null,
  message text,
  customer_id uuid references public.customers(id),
  task_id uuid references public.tasks(id),
  opportunity_id uuid references public.opportunities(id),
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  department_id uuid references public.departments(id),
  actor_user_id uuid not null references public.profiles(id),
  action text not null,
  entity_type text not null,
  entity_id uuid,
  old_data jsonb,
  new_data jsonb,
  reason text,
  created_at timestamptz not null default now()
);


-- ===== 202609260005_indexes.sql =====
-- Performance indexes: ownership, RLS filters, Today, search, reports
create index idx_profiles_org on public.profiles(organization_id);
create index idx_profiles_department on public.profiles(department_id);
create index idx_profiles_team on public.profiles(team_id);
create index idx_profiles_role_status on public.profiles(role, status);

create index idx_lead_sources_org_sort on public.lead_sources(organization_id, sort_order) where is_active;
create index idx_pipeline_org_sort on public.pipeline_stages(organization_id, sort_order) where is_active;
create index idx_products_org_sort on public.products(organization_id, sort_order) where is_active;

create index idx_customers_owner_created on public.customers(owner_user_id, created_at desc);
create index idx_customers_team_created on public.customers(team_id, created_at desc);
create index idx_customers_department_created on public.customers(department_id, created_at desc);
create index idx_customers_source_created on public.customers(source_id, created_at desc);
create index idx_customers_last_activity on public.customers(last_activity_at desc nulls last);
create index idx_customers_active_owner on public.customers(owner_user_id, is_archived, created_at desc);
create index idx_customers_name_trgm on public.customers using gin (normalized_display_name extensions.gin_trgm_ops);

create index idx_contacts_customer on public.customer_contacts(customer_id);
create index idx_contacts_owner on public.customer_contacts(owner_user_id);
create index idx_contacts_normalized on public.customer_contacts(normalized_value) where normalized_value is not null;
create index idx_contacts_normalized_trgm on public.customer_contacts using gin (normalized_value extensions.gin_trgm_ops) where normalized_value is not null;

create index idx_opps_customer on public.opportunities(customer_id, created_at desc);
create index idx_opps_owner_status on public.opportunities(owner_user_id, status, stage_id);
create index idx_opps_team_status on public.opportunities(team_id, status, stage_id);
create index idx_opps_department_status on public.opportunities(department_id, status, stage_id);
create index idx_opps_source_created on public.opportunities(source_id, created_at desc);
create index idx_opps_last_activity on public.opportunities(last_activity_at desc nulls last);

create index idx_tasks_assignee_due on public.tasks(assigned_user_id, status, due_at);
create index idx_tasks_team_due on public.tasks(team_id, status, due_at);
create index idx_tasks_department_due on public.tasks(department_id, status, due_at);
create index idx_tasks_customer on public.tasks(customer_id, status, due_at);
create index idx_tasks_source_task on public.tasks(source_task_id);

create index idx_activities_customer_time on public.activities(customer_id, occurred_at desc) where not is_voided;
create index idx_activities_opp_time on public.activities(opportunity_id, occurred_at desc) where not is_voided;
create index idx_activities_owner_time on public.activities(owner_user_id, occurred_at desc) where not is_voided;
create index idx_activities_task on public.activities(task_id);

create index idx_quotes_opp_version on public.quotes(opportunity_id, version desc);
create index idx_quotes_owner_created on public.quotes(owner_user_id, created_at desc);
create index idx_quotes_status_sent on public.quotes(status, sent_at desc);

create index idx_pipeline_history_opp_time on public.pipeline_history(opportunity_id, changed_at desc);
create index idx_pipeline_history_owner_time on public.pipeline_history(owner_user_id, changed_at desc);

create index idx_schedule_user_day on public.work_schedule_blocks(user_id, day_of_week, start_time);
create index idx_targets_user_period on public.targets(user_id, period_start, period_end);
create index idx_targets_team_period on public.targets(team_id, period_start, period_end);
create index idx_notifications_user_unread on public.notifications(user_id, created_at desc) where read_at is null;
create index idx_audit_org_time on public.audit_logs(organization_id, created_at desc);
create index idx_audit_department_time on public.audit_logs(department_id, created_at desc);


-- ===== 202609260006_helpers_rls.sql =====
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


-- ===== 202609260007_triggers.sql =====
-- Data normalization, timestamps, activity/pipeline side effects
create or replace function private.set_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin new.updated_at = now(); return new; end; $$;

create trigger trg_profiles_updated before update on public.profiles for each row execute function private.set_updated_at();
create trigger trg_customers_updated before update on public.customers for each row execute function private.set_updated_at();
create trigger trg_opportunities_updated before update on public.opportunities for each row execute function private.set_updated_at();

create or replace function private.normalize_customer_before_write()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.display_name := trim(new.display_name);
  new.normalized_display_name := private.normalize_search_text(new.display_name);
  return new;
end; $$;
create trigger trg_customer_normalize before insert or update of display_name on public.customers
for each row execute function private.normalize_customer_before_write();

create or replace function private.normalize_contact_before_write()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.raw_value := trim(new.raw_value);
  new.normalized_value := private.normalize_contact(new.contact_type, new.raw_value);
  return new;
end; $$;
create trigger trg_contact_normalize before insert or update of contact_type,raw_value on public.customer_contacts
for each row execute function private.normalize_contact_before_write();

create or replace function private.prevent_code_change()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.code is distinct from old.code then
    raise exception 'code is immutable';
  end if;
  return new;
end; $$;
create trigger trg_source_code_immutable before update on public.lead_sources for each row execute function private.prevent_code_change();
create trigger trg_stage_code_immutable before update on public.pipeline_stages for each row execute function private.prevent_code_change();
create trigger trg_lost_code_immutable before update on public.lost_reasons for each row execute function private.prevent_code_change();
create trigger trg_product_code_immutable before update on public.products for each row execute function private.prevent_code_change();
create trigger trg_task_type_code_immutable before update on public.task_types for each row execute function private.prevent_code_change();

create or replace function private.set_opportunity_milestones()
returns trigger language plpgsql set search_path = '' as $$
declare v_code text;
begin
  if tg_op='INSERT' or new.stage_id is distinct from old.stage_id then
    select s.code into v_code from public.pipeline_stages s where s.id=new.stage_id;
    case v_code
      when 'contacted' then new.contacted_at := coalesce(new.contacted_at, now());
      when 'qualified' then new.qualified_at := coalesce(new.qualified_at, now());
      when 'quoted' then new.quoted_at := coalesce(new.quoted_at, now());
      when 'appointment' then new.appointment_at := coalesce(new.appointment_at, now());
      when 'test_drive' then new.test_drive_at := coalesce(new.test_drive_at, now());
      when 'deposit' then new.deposit_at := coalesce(new.deposit_at, now());
      else null;
    end case;
  end if;
  return new;
end; $$;
create trigger trg_opportunity_milestones before insert or update of stage_id on public.opportunities
for each row execute function private.set_opportunity_milestones();

create or replace function private.log_pipeline_history()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op='INSERT' then
    insert into public.pipeline_history(opportunity_id,organization_id,department_id,team_id,owner_user_id,from_stage_id,to_stage_id,changed_by,changed_at)
    values(new.id,new.organization_id,new.department_id,new.team_id,new.owner_user_id,null,new.stage_id,new.created_by,new.created_at);
  elsif new.stage_id is distinct from old.stage_id then
    insert into public.pipeline_history(opportunity_id,organization_id,department_id,team_id,owner_user_id,from_stage_id,to_stage_id,changed_by,changed_at)
    values(new.id,new.organization_id,new.department_id,new.team_id,new.owner_user_id,old.stage_id,new.stage_id,coalesce((select auth.uid()),new.owner_user_id),now());
  end if;
  return new;
end; $$;
revoke all on function private.log_pipeline_history() from public, anon, authenticated;
create trigger trg_pipeline_history after insert or update of stage_id on public.opportunities
for each row execute function private.log_pipeline_history();

create or replace function private.activity_after_insert()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.is_voided or new.activity_type='lead_created'::public.activity_type then
    return new;
  end if;
  update public.customers
     set first_response_at=coalesce(first_response_at,new.occurred_at),
         last_activity_at=greatest(coalesce(last_activity_at,new.occurred_at),new.occurred_at)
   where id=new.customer_id;
  if new.opportunity_id is not null then
    update public.opportunities
       set last_activity_at=greatest(coalesce(last_activity_at,new.occurred_at),new.occurred_at)
     where id=new.opportunity_id;
  end if;
  return new;
end; $$;
revoke all on function private.activity_after_insert() from public, anon, authenticated;
create trigger trg_activity_after_insert after insert on public.activities
for each row execute function private.activity_after_insert();


-- ===== 202609260008_rpc.sql =====
-- Business RPCs. All SECURITY DEFINER functions validate authorization internally.

create or replace function public.create_lead(
  p_source_id uuid,
  p_display_name text default null,
  p_contact_raw text default null,
  p_contact_type public.contact_type default null,
  p_product_id uuid default null,
  p_variant_id uuid default null,
  p_note text default null
)
returns table(customer_id uuid, opportunity_id uuid)
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_profile public.profiles%rowtype;
  v_customer_id uuid := gen_random_uuid();
  v_opp_id uuid;
  v_stage_id uuid;
  v_source_name text;
  v_name text;
  v_type public.contact_type;
begin
  select * into v_profile from public.profiles where id=v_uid and status='active'::public.user_status;
  if not found or v_profile.organization_id is null then raise exception 'Tài khoản chưa được kích hoạt đầy đủ'; end if;
  select name into v_source_name from public.lead_sources
   where id=p_source_id and organization_id=v_profile.organization_id and is_active;
  if not found then raise exception 'Nguồn khách không hợp lệ'; end if;

  v_name := nullif(trim(coalesce(p_display_name,'')), '');
  if v_name is null then
    v_name := 'Khách ' || v_source_name || ' #' || upper(substr(replace(v_customer_id::text,'-',''),1,6));
  end if;

  insert into public.customers(id,organization_id,department_id,team_id,owner_user_id,source_id,display_name,note,created_by)
  values(v_customer_id,v_profile.organization_id,v_profile.department_id,v_profile.team_id,v_uid,p_source_id,v_name,p_note,v_uid);

  if nullif(trim(coalesce(p_contact_raw,'')),'') is not null then
    v_type := p_contact_type;
    if v_type is null then
      if p_contact_raw ~* '^[+0-9 ().-]{8,}$' then v_type := 'phone';
      elsif p_contact_raw ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$' then v_type := 'email';
      elsif lower(p_contact_raw) like '%facebook.com%' then v_type := 'facebook';
      elsif lower(p_contact_raw) like '%tiktok.com%' or left(trim(p_contact_raw),1)='@' then v_type := 'tiktok';
      else v_type := 'other'; end if;
    end if;
    insert into public.customer_contacts(customer_id,organization_id,department_id,team_id,owner_user_id,contact_type,raw_value,is_primary)
    values(v_customer_id,v_profile.organization_id,v_profile.department_id,v_profile.team_id,v_uid,v_type,p_contact_raw,true);
  end if;

  if p_product_id is not null then
    if not exists(select 1 from public.products p where p.id=p_product_id and p.organization_id=v_profile.organization_id and p.is_active) then
      raise exception 'Sản phẩm không hợp lệ';
    end if;
    if p_variant_id is not null and not exists(select 1 from public.product_variants pv where pv.id=p_variant_id and pv.product_id=p_product_id and pv.is_active) then
      raise exception 'Phiên bản xe không hợp lệ';
    end if;
    select id into v_stage_id from public.pipeline_stages
     where organization_id=v_profile.organization_id and code='new' and is_active limit 1;
    if v_stage_id is null then raise exception 'Chưa cấu hình giai đoạn Khách mới'; end if;
    v_opp_id := gen_random_uuid();
    insert into public.opportunities(id,customer_id,organization_id,department_id,team_id,owner_user_id,source_id,product_id,variant_id,stage_id,created_by)
    values(v_opp_id,v_customer_id,v_profile.organization_id,v_profile.department_id,v_profile.team_id,v_uid,p_source_id,p_product_id,p_variant_id,v_stage_id,v_uid);
  end if;

  insert into public.activities(customer_id,opportunity_id,organization_id,department_id,team_id,owner_user_id,activity_type,note,occurred_at,created_by)
  values(v_customer_id,v_opp_id,v_profile.organization_id,v_profile.department_id,v_profile.team_id,v_uid,'lead_created'::public.activity_type,p_note,now(),v_uid);

  return query select v_customer_id, v_opp_id;
end; $$;

create or replace function public.add_activity(
  p_customer_id uuid,
  p_opportunity_id uuid,
  p_activity_type public.activity_type,
  p_result_code text default null,
  p_note text default null,
  p_occurred_at timestamptz default now()
)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare v_uid uuid := (select auth.uid()); c public.customers%rowtype; v_id uuid;
begin
  select * into c from public.customers where id=p_customer_id;
  if not found then raise exception 'Không tìm thấy khách'; end if;
  if c.owner_user_id<>v_uid and (select private.current_role())<>'admin'::public.app_role then raise exception 'Không có quyền ghi tương tác'; end if;
  if p_opportunity_id is not null and not exists(select 1 from public.opportunities o where o.id=p_opportunity_id and o.customer_id=c.id) then raise exception 'Cơ hội không hợp lệ'; end if;
  insert into public.activities(customer_id,opportunity_id,organization_id,department_id,team_id,owner_user_id,activity_type,result_code,note,occurred_at,created_by)
  values(c.id,p_opportunity_id,c.organization_id,c.department_id,c.team_id,c.owner_user_id,p_activity_type,p_result_code,p_note,coalesce(p_occurred_at,now()),v_uid)
  returning id into v_id;
  return v_id;
end; $$;

create or replace function public.create_task(
  p_assigned_user_id uuid,
  p_task_type_id uuid,
  p_customer_id uuid default null,
  p_opportunity_id uuid default null,
  p_title text default null,
  p_note text default null,
  p_due_at timestamptz default null,
  p_priority public.priority_level default 'normal'
)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare v_uid uuid := (select auth.uid()); t public.profiles%rowtype; tt public.task_types%rowtype; v_id uuid; v_title text;
begin
  if not (select private.can_assign_to_user(p_assigned_user_id)) then raise exception 'Không có quyền giao công việc cho tài khoản này'; end if;
  select * into t from public.profiles where id=p_assigned_user_id and status='active'::public.user_status;
  select * into tt from public.task_types where id=p_task_type_id and organization_id=t.organization_id and is_active;
  if not found then raise exception 'Loại công việc không hợp lệ'; end if;
  if p_due_at is null then raise exception 'Cần thời gian thực hiện'; end if;
  if p_customer_id is not null and not exists(select 1 from public.customers c where c.id=p_customer_id and (select private.can_read_scope(c.owner_user_id,c.team_id,c.department_id,c.organization_id))) then raise exception 'Không có quyền với khách'; end if;
  if p_opportunity_id is not null and not exists(select 1 from public.opportunities o where o.id=p_opportunity_id and (select private.can_read_scope(o.owner_user_id,o.team_id,o.department_id,o.organization_id))) then raise exception 'Không có quyền với cơ hội'; end if;
  v_title := coalesce(nullif(trim(p_title),''),tt.display_name);
  insert into public.tasks(customer_id,opportunity_id,organization_id,department_id,team_id,assigned_user_id,task_type_id,title,note,due_at,priority,created_by)
  values(p_customer_id,p_opportunity_id,t.organization_id,t.department_id,t.team_id,t.id,tt.id,v_title,p_note,p_due_at,p_priority,v_uid)
  returning id into v_id;
  return v_id;
end; $$;

create or replace function public.complete_task(
  p_task_id uuid,
  p_result_code text default null,
  p_note text default null,
  p_next_due_at timestamptz default null,
  p_next_task_type_id uuid default null,
  p_next_note text default null
)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  t public.tasks%rowtype; tt public.task_types%rowtype;
  v_activity_id uuid; v_next_task_id uuid; v_next_type uuid;
begin
  select * into t from public.tasks where id=p_task_id for update;
  if not found then raise exception 'Không tìm thấy công việc'; end if;
  if t.assigned_user_id<>v_uid and (select private.current_role())<>'admin'::public.app_role then raise exception 'Không có quyền hoàn thành công việc'; end if;
  if t.status<>'pending'::public.task_status then raise exception 'Công việc không còn ở trạng thái chờ'; end if;
  update public.tasks set status='completed', completed_at=now() where id=t.id;
  select * into tt from public.task_types where id=t.task_type_id;
  if t.customer_id is not null and tt.activity_type is not null then
    insert into public.activities(customer_id,opportunity_id,task_id,organization_id,department_id,team_id,owner_user_id,activity_type,result_code,note,occurred_at,created_by)
    values(t.customer_id,t.opportunity_id,t.id,t.organization_id,t.department_id,t.team_id,t.assigned_user_id,tt.activity_type,p_result_code,p_note,now(),v_uid)
    returning id into v_activity_id;
  end if;
  if p_next_due_at is not null then
    v_next_type := coalesce(p_next_task_type_id,t.task_type_id);
    insert into public.tasks(customer_id,opportunity_id,organization_id,department_id,team_id,assigned_user_id,task_type_id,source_task_id,title,note,due_at,priority,created_by)
    select t.customer_id,t.opportunity_id,t.organization_id,t.department_id,t.team_id,t.assigned_user_id,v_next_type,t.id,tt2.display_name,p_next_note,p_next_due_at,t.priority,v_uid
    from public.task_types tt2 where tt2.id=v_next_type
    returning id into v_next_task_id;
  end if;
  return jsonb_build_object('task_id',t.id,'activity_id',v_activity_id,'next_task_id',v_next_task_id);
end; $$;

create or replace function public.undo_complete_task(p_task_id uuid)
returns boolean
language plpgsql security definer set search_path = ''
as $$
declare v_uid uuid := (select auth.uid()); t public.tasks%rowtype;
begin
  select * into t from public.tasks where id=p_task_id for update;
  if not found or t.assigned_user_id<>v_uid or t.status<>'completed'::public.task_status then return false; end if;
  if t.completed_at is null or t.completed_at < now()-interval '10 minutes' then return false; end if;
  update public.tasks set status='pending',completed_at=null where id=t.id;
  update public.activities set is_voided=true,voided_at=now(),voided_by=v_uid where task_id=t.id and not is_voided;
  update public.tasks set status='cancelled',cancelled_at=now() where source_task_id=t.id and status='pending'::public.task_status;
  return true;
end; $$;

create or replace function public.change_opportunity_stage(p_opportunity_id uuid,p_stage_id uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
declare v_uid uuid := (select auth.uid()); o public.opportunities%rowtype;
begin
  select * into o from public.opportunities where id=p_opportunity_id for update;
  if not found then raise exception 'Không tìm thấy cơ hội'; end if;
  if o.owner_user_id<>v_uid and (select private.current_role())<>'admin'::public.app_role then raise exception 'Không có quyền đổi giai đoạn'; end if;
  if not exists(select 1 from public.pipeline_stages s where s.id=p_stage_id and s.organization_id=o.organization_id and s.is_active) then raise exception 'Giai đoạn không hợp lệ'; end if;
  update public.opportunities set stage_id=p_stage_id where id=o.id;
end; $$;

create or replace function public.pause_opportunity(p_opportunity_id uuid,p_until timestamptz,p_note text default null)
returns void
language plpgsql security definer set search_path = ''
as $$
declare v_uid uuid := (select auth.uid()); o public.opportunities%rowtype; v_task_type uuid;
begin
  select * into o from public.opportunities where id=p_opportunity_id for update;
  if not found or (o.owner_user_id<>v_uid and (select private.current_role())<>'admin'::public.app_role) then raise exception 'Không có quyền'; end if;
  if p_until is null or p_until<=now() then raise exception 'Ngày chăm lại phải ở tương lai'; end if;
  update public.opportunities set status='paused',paused_until=p_until,note=coalesce(p_note,note) where id=o.id;
  select id into v_task_type from public.task_types where organization_id=o.organization_id and code='customer_followup' and is_active limit 1;
  if v_task_type is not null then
    insert into public.tasks(customer_id,opportunity_id,organization_id,department_id,team_id,assigned_user_id,task_type_id,title,note,due_at,priority,created_by)
    values(o.customer_id,o.id,o.organization_id,o.department_id,o.team_id,o.owner_user_id,v_task_type,'Chăm sóc lại khách',p_note,p_until,'normal',v_uid);
  end if;
end; $$;

create or replace function public.mark_opportunity_won(p_opportunity_id uuid,p_final_sale_price numeric default null,p_note text default null)
returns void
language plpgsql security definer set search_path = ''
as $$
declare v_uid uuid := (select auth.uid()); o public.opportunities%rowtype;
begin
  select * into o from public.opportunities where id=p_opportunity_id for update;
  if not found or (o.owner_user_id<>v_uid and (select private.current_role())<>'admin'::public.app_role) then raise exception 'Không có quyền'; end if;
  update public.opportunities set status='won',won_at=now(),closed_at=now(),final_sale_price=p_final_sale_price,note=coalesce(p_note,note) where id=o.id;
  update public.tasks set status='cancelled',cancelled_at=now() where opportunity_id=o.id and status='pending'::public.task_status;
end; $$;

create or replace function public.mark_opportunity_lost(p_opportunity_id uuid,p_lost_reason_id uuid,p_note text default null)
returns void
language plpgsql security definer set search_path = ''
as $$
declare v_uid uuid := (select auth.uid()); o public.opportunities%rowtype;
begin
  select * into o from public.opportunities where id=p_opportunity_id for update;
  if not found or (o.owner_user_id<>v_uid and (select private.current_role())<>'admin'::public.app_role) then raise exception 'Không có quyền'; end if;
  if not exists(select 1 from public.lost_reasons r where r.id=p_lost_reason_id and r.organization_id=o.organization_id and r.is_active) then raise exception 'Lý do không hợp lệ'; end if;
  update public.opportunities set status='lost',lost_at=now(),closed_at=now(),lost_reason_id=p_lost_reason_id,lost_note=p_note where id=o.id;
  update public.tasks set status='cancelled',cancelled_at=now() where opportunity_id=o.id and status='pending'::public.task_status;
end; $$;

create or replace function public.create_quote(
  p_opportunity_id uuid,
  p_list_price numeric default null,
  p_discount_amount numeric default null,
  p_final_price numeric default null,
  p_promotion_note text default null,
  p_storage_path text default null
)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare v_uid uuid := (select auth.uid()); o public.opportunities%rowtype; v_id uuid; v_version int;
begin
  select * into o from public.opportunities where id=p_opportunity_id for update;
  if not found or (o.owner_user_id<>v_uid and (select private.current_role())<>'admin'::public.app_role) then raise exception 'Không có quyền'; end if;
  select coalesce(max(version),0)+1 into v_version from public.quotes where opportunity_id=o.id;
  insert into public.quotes(customer_id,opportunity_id,organization_id,department_id,team_id,owner_user_id,version,product_id,variant_id,list_price,discount_amount,final_price,promotion_note,storage_path,created_by)
  values(o.customer_id,o.id,o.organization_id,o.department_id,o.team_id,o.owner_user_id,v_version,o.product_id,o.variant_id,p_list_price,p_discount_amount,p_final_price,p_promotion_note,p_storage_path,v_uid)
  returning id into v_id;
  return v_id;
end; $$;

create or replace function public.mark_quote_sent(p_quote_id uuid,p_sent_at timestamptz default now())
returns void
language plpgsql security definer set search_path = ''
as $$
declare v_uid uuid := (select auth.uid()); q public.quotes%rowtype; v_quoted_stage uuid; v_current_sort int; v_quoted_sort int;
begin
  select * into q from public.quotes where id=p_quote_id for update;
  if not found or (q.owner_user_id<>v_uid and (select private.current_role())<>'admin'::public.app_role) then raise exception 'Không có quyền'; end if;
  update public.quotes set status='sent',sent_at=coalesce(p_sent_at,now()) where id=q.id;
  insert into public.activities(customer_id,opportunity_id,organization_id,department_id,team_id,owner_user_id,activity_type,note,occurred_at,created_by)
  values(q.customer_id,q.opportunity_id,q.organization_id,q.department_id,q.team_id,q.owner_user_id,'quote_sent',concat('Báo giá #',q.version),coalesce(p_sent_at,now()),v_uid);
  select id,sort_order into v_quoted_stage,v_quoted_sort from public.pipeline_stages where organization_id=q.organization_id and code='quoted' and is_active limit 1;
  select s.sort_order into v_current_sort from public.opportunities o join public.pipeline_stages s on s.id=o.stage_id where o.id=q.opportunity_id;
  if v_quoted_stage is not null and coalesce(v_current_sort,0)<v_quoted_sort then
    update public.opportunities set stage_id=v_quoted_stage where id=q.opportunity_id;
  end if;
end; $$;

create or replace function public.transfer_customer(p_customer_id uuid,p_new_owner_user_id uuid,p_reason text default null)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid()); v_role public.app_role := (select private.current_role());
  c public.customers%rowtype; np public.profiles%rowtype;
begin
  select * into c from public.customers where id=p_customer_id for update;
  if not found then raise exception 'Không tìm thấy khách'; end if;
  select * into np from public.profiles where id=p_new_owner_user_id and status='active'::public.user_status;
  if not found or np.organization_id is distinct from c.organization_id then raise exception 'Nhân viên nhận khách không hợp lệ'; end if;
  if v_role='team_leader'::public.app_role then
    if c.team_id is distinct from (select private.current_team_id()) or np.team_id is distinct from (select private.current_team_id()) then raise exception 'Trưởng nhóm chỉ chuyển khách trong nhóm'; end if;
  elsif v_role='sales_manager'::public.app_role then
    if c.department_id is distinct from (select private.current_department_id()) or np.department_id is distinct from (select private.current_department_id()) then raise exception 'Trưởng phòng chỉ chuyển khách trong phòng'; end if;
  elsif v_role='admin'::public.app_role then
    null;
  else
    raise exception 'Không có quyền chuyển khách';
  end if;

  update public.customers set owner_user_id=np.id,team_id=np.team_id,department_id=np.department_id where id=c.id;
  update public.customer_contacts set owner_user_id=np.id,team_id=np.team_id,department_id=np.department_id where customer_id=c.id;
  update public.opportunities set owner_user_id=np.id,team_id=np.team_id,department_id=np.department_id where customer_id=c.id;
  update public.activities set owner_user_id=np.id,team_id=np.team_id,department_id=np.department_id where customer_id=c.id;
  update public.quotes set owner_user_id=np.id,team_id=np.team_id,department_id=np.department_id where customer_id=c.id;
  update public.pipeline_history ph set owner_user_id=np.id,team_id=np.team_id,department_id=np.department_id
   where exists(select 1 from public.opportunities o where o.id=ph.opportunity_id and o.customer_id=c.id);
  update public.tasks set assigned_user_id=np.id,team_id=np.team_id,department_id=np.department_id
   where customer_id=c.id and status='pending'::public.task_status;

  insert into public.audit_logs(organization_id,department_id,actor_user_id,action,entity_type,entity_id,old_data,new_data,reason)
  values(c.organization_id,np.department_id,v_uid,'transfer_customer','customer',c.id,
    jsonb_build_object('owner_user_id',c.owner_user_id,'team_id',c.team_id,'department_id',c.department_id),
    jsonb_build_object('owner_user_id',np.id,'team_id',np.team_id,'department_id',np.department_id),p_reason);
end; $$;

create or replace function public.search_customers(p_query text,p_limit int default 20,p_offset int default 0)
returns table(customer_id uuid,display_name text,source_name text,last_activity_at timestamptz,primary_contact text,active_opportunity jsonb)
language sql security definer set search_path = ''
as $$
  with q as (select private.normalize_search_text(p_query) as s),
  visible as (
    select c.* from public.customers c
    where not c.is_archived and (select private.can_read_scope(c.owner_user_id,c.team_id,c.department_id,c.organization_id))
  )
  select c.id,c.display_name,ls.name,c.last_activity_at,
    (select cc.raw_value from public.customer_contacts cc where cc.customer_id=c.id order by cc.is_primary desc,cc.created_at limit 1),
    (select jsonb_build_object('id',o.id,'product_id',o.product_id,'variant_id',o.variant_id,'stage_id',o.stage_id,'status',o.status,'priority',o.priority,'potential_level',o.potential_level)
       from public.opportunities o where o.customer_id=c.id and o.status in ('active','paused') order by o.created_at desc limit 1)
  from visible c
  join public.lead_sources ls on ls.id=c.source_id
  cross join q
  where q.s is null
     or c.normalized_display_name ilike '%'||q.s||'%'
     or exists(select 1 from public.customer_contacts cc where cc.customer_id=c.id and cc.normalized_value ilike '%'||q.s||'%')
  order by c.updated_at desc
  limit greatest(1,least(coalesce(p_limit,20),100)) offset greatest(coalesce(p_offset,0),0)
$$;

create or replace function public.get_today_dashboard(p_scope text default 'self')
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid()); v_role public.app_role := (select private.current_role());
  v_org uuid := (select private.current_org_id()); v_team uuid := (select private.current_team_id()); v_dept uuid := (select private.current_department_id());
  v_start timestamptz := date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') at time zone 'Asia/Ho_Chi_Minh';
  v_end timestamptz := (date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') + interval '1 day') at time zone 'Asia/Ho_Chi_Minh';
  result jsonb;
begin
  if not (select private.is_active_user()) then raise exception 'Tài khoản bị khóa'; end if;
  if p_scope='team' and v_role not in ('team_leader','sales_manager','admin') then raise exception 'Không có quyền xem nhóm'; end if;
  if p_scope='department' and v_role not in ('sales_manager','admin') then raise exception 'Không có quyền xem phòng'; end if;

  with scoped_tasks as (
    select t.* from public.tasks t where t.organization_id=v_org and t.status='pending' and
      case p_scope
        when 'self' then t.assigned_user_id=v_uid
        when 'team' then t.team_id=v_team
        when 'department' then t.department_id=v_dept
        else false end
  ), scoped_customers as (
    select c.* from public.customers c where c.organization_id=v_org and not c.is_archived and
      case p_scope
        when 'self' then c.owner_user_id=v_uid
        when 'team' then c.team_id=v_team
        when 'department' then c.department_id=v_dept
        else false end
  ), overdue as (
    select coalesce(jsonb_agg(to_jsonb(x) order by x.due_at),'[]'::jsonb) j from (
      select t.id,t.title,t.due_at,t.priority,t.customer_id,t.opportunity_id from scoped_tasks t where t.due_at<now() limit 20
    ) x
  ), upcoming as (
    select coalesce(jsonb_agg(to_jsonb(x) order by x.due_at),'[]'::jsonb) j from (
      select t.id,t.title,t.due_at,t.priority,t.customer_id,t.opportunity_id from scoped_tasks t where t.due_at>=now() and t.due_at<v_end limit 20
    ) x
  ), priority_leads as (
    select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at),'[]'::jsonb) j from (
      select c.id,c.display_name,c.created_at,ls.name source_name,ls.response_sla_minutes,
             extract(epoch from (now()-c.created_at))/60 age_minutes
      from scoped_customers c join public.lead_sources ls on ls.id=c.source_id
      where c.first_response_at is null and ls.is_priority
      order by c.created_at limit 20
    ) x
  )
  select jsonb_build_object(
    'overview',jsonb_build_object(
      'overdue_tasks',(select count(*) from scoped_tasks where due_at<now()),
      'today_tasks',(select count(*) from scoped_tasks where due_at>=v_start and due_at<v_end),
      'new_leads_today',(select count(*) from scoped_customers where created_at>=v_start and created_at<v_end),
      'priority_unhandled',(select count(*) from scoped_customers c join public.lead_sources ls on ls.id=c.source_id where c.first_response_at is null and ls.is_priority)
    ),
    'overdue_tasks',(select j from overdue),
    'upcoming_tasks',(select j from upcoming),
    'priority_new_leads',(select j from priority_leads)
  ) into result;
  return result;
end; $$;

create or replace function public.get_duplicate_customers(p_contact_type public.contact_type default null)
returns table(match_type public.contact_type,match_value text,record_count bigint,records jsonb)
language plpgsql security definer set search_path = ''
as $$
begin
  if (select private.current_role()) not in ('sales_manager'::public.app_role,'admin'::public.app_role) then
    raise exception 'Không có quyền xem khách trùng';
  end if;
  return query
  with ctx as (
    select private.current_role() role,private.current_org_id() org,private.current_department_id() dept
  ), eligible as (
    select cc.* from public.customer_contacts cc cross join ctx
    where cc.normalized_value is not null
      and cc.contact_type in ('phone','email','facebook','tiktok','zalo')
      and (p_contact_type is null or cc.contact_type=p_contact_type)
      and cc.organization_id=ctx.org
      and ((ctx.role='sales_manager'::public.app_role and cc.department_id=ctx.dept) or ctx.role='admin'::public.app_role)
  ), dup as (
    select contact_type,normalized_value,count(distinct customer_id) cnt
    from eligible group by contact_type,normalized_value having count(distinct customer_id)>1
  )
  select d.contact_type,d.normalized_value,d.cnt,
    jsonb_agg(jsonb_build_object(
      'customer_id',c.id,'display_name',c.display_name,'owner_user_id',c.owner_user_id,
      'team_id',c.team_id,'source_id',c.source_id,'last_activity_at',c.last_activity_at
    ) order by c.updated_at desc)
  from dup d
  join eligible e on e.contact_type=d.contact_type and e.normalized_value=d.normalized_value
  join public.customers c on c.id=e.customer_id
  group by d.contact_type,d.normalized_value,d.cnt
  order by d.cnt desc,d.normalized_value;
end; $$;

create or replace function public.get_funnel_report(p_from date,p_to date)
returns table(stage_code text,stage_name text,reached_count bigint)
language sql security definer set search_path = ''
as $$
  with o as (
    select * from public.opportunities x
    where x.created_at >= p_from::timestamptz and x.created_at < (p_to+1)::timestamptz
      and (select private.can_read_scope(x.owner_user_id,x.team_id,x.department_id,x.organization_id))
  )
  select * from (
    select 'new','Khách mới',count(*) from o
    union all select 'contacted','Đã liên hệ',count(*) from o where contacted_at is not null
    union all select 'qualified','Đã xác định nhu cầu',count(*) from o where qualified_at is not null
    union all select 'quoted','Đã báo giá',count(*) from o where quoted_at is not null
    union all select 'appointment','Đã hẹn',count(*) from o where appointment_at is not null
    union all select 'test_drive','Đã lái thử',count(*) from o where test_drive_at is not null
    union all select 'deposit','Đã đặt cọc',count(*) from o where deposit_at is not null
    union all select 'won','Thành công',count(*) from o where won_at is not null
  ) r(stage_code,stage_name,reached_count)
$$;

create or replace function public.get_lead_source_report(p_from date,p_to date)
returns table(source_id uuid,source_name text,lead_count bigint,responded_count bigint,quoted_count bigint,deposit_count bigint,won_count bigint,avg_response_minutes numeric)
language sql security definer set search_path = ''
as $$
  with o as (
    select x.*,c.created_at customer_created,c.first_response_at
    from public.opportunities x join public.customers c on c.id=x.customer_id
    where x.created_at>=p_from::timestamptz and x.created_at<(p_to+1)::timestamptz
      and (select private.can_read_scope(x.owner_user_id,x.team_id,x.department_id,x.organization_id))
  )
  select ls.id,ls.name,count(o.id),count(o.id) filter(where o.first_response_at is not null),
    count(o.id) filter(where o.quoted_at is not null),count(o.id) filter(where o.deposit_at is not null),
    count(o.id) filter(where o.won_at is not null),
    round(avg(extract(epoch from (o.first_response_at-o.customer_created))/60.0) filter(where o.first_response_at is not null)::numeric,1)
  from public.lead_sources ls left join o on o.source_id=ls.id
  where ls.organization_id=(select private.current_org_id())
  group by ls.id,ls.name,ls.sort_order order by ls.sort_order,ls.name
$$;

-- Lock RPC execution down explicitly
revoke execute on function public.create_lead(uuid,text,text,public.contact_type,uuid,uuid,text) from public, anon;
revoke execute on function public.add_activity(uuid,uuid,public.activity_type,text,text,timestamptz) from public, anon;
revoke execute on function public.create_task(uuid,uuid,uuid,uuid,text,text,timestamptz,public.priority_level) from public, anon;
revoke execute on function public.complete_task(uuid,text,text,timestamptz,uuid,text) from public, anon;
revoke execute on function public.undo_complete_task(uuid) from public, anon;
revoke execute on function public.change_opportunity_stage(uuid,uuid) from public, anon;
revoke execute on function public.pause_opportunity(uuid,timestamptz,text) from public, anon;
revoke execute on function public.mark_opportunity_won(uuid,numeric,text) from public, anon;
revoke execute on function public.mark_opportunity_lost(uuid,uuid,text) from public, anon;
revoke execute on function public.create_quote(uuid,numeric,numeric,numeric,text,text) from public, anon;
revoke execute on function public.mark_quote_sent(uuid,timestamptz) from public, anon;
revoke execute on function public.transfer_customer(uuid,uuid,text) from public, anon;
revoke execute on function public.search_customers(text,int,int) from public, anon;
revoke execute on function public.get_today_dashboard(text) from public, anon;
revoke execute on function public.get_duplicate_customers(public.contact_type) from public, anon;
revoke execute on function public.get_funnel_report(date,date) from public, anon;
revoke execute on function public.get_lead_source_report(date,date) from public, anon;

grant execute on function public.create_lead(uuid,text,text,public.contact_type,uuid,uuid,text) to authenticated;
grant execute on function public.add_activity(uuid,uuid,public.activity_type,text,text,timestamptz) to authenticated;
grant execute on function public.create_task(uuid,uuid,uuid,uuid,text,text,timestamptz,public.priority_level) to authenticated;
grant execute on function public.complete_task(uuid,text,text,timestamptz,uuid,text) to authenticated;
grant execute on function public.undo_complete_task(uuid) to authenticated;
grant execute on function public.change_opportunity_stage(uuid,uuid) to authenticated;
grant execute on function public.pause_opportunity(uuid,timestamptz,text) to authenticated;
grant execute on function public.mark_opportunity_won(uuid,numeric,text) to authenticated;
grant execute on function public.mark_opportunity_lost(uuid,uuid,text) to authenticated;
grant execute on function public.create_quote(uuid,numeric,numeric,numeric,text,text) to authenticated;
grant execute on function public.mark_quote_sent(uuid,timestamptz) to authenticated;
grant execute on function public.transfer_customer(uuid,uuid,text) to authenticated;
grant execute on function public.search_customers(text,int,int) to authenticated;
grant execute on function public.get_today_dashboard(text) to authenticated;
grant execute on function public.get_duplicate_customers(public.contact_type) to authenticated;
grant execute on function public.get_funnel_report(date,date) to authenticated;
grant execute on function public.get_lead_source_report(date,date) to authenticated;


-- ===== 202609260009_views.sql =====
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


-- ===== 202609260010_storage.sql =====
-- Private quote PDF bucket, max 10 MB, PDF only.
insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('quotes','quotes',false,10485760,array['application/pdf'])
on conflict (id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

-- File path convention: <organization_id>/<quote_id>/<filename.pdf>
drop policy if exists quote_files_select on storage.objects;
create policy quote_files_select on storage.objects for select to authenticated
using (
  bucket_id='quotes' and
  exists(
    select 1 from public.quotes q
    where q.id::text=(storage.foldername(name))[2]
      and (select private.can_read_scope(q.owner_user_id,q.team_id,q.department_id,q.organization_id))
  )
);

drop policy if exists quote_files_insert on storage.objects;
create policy quote_files_insert on storage.objects for insert to authenticated
with check (
  bucket_id='quotes' and
  exists(
    select 1 from public.quotes q
    where q.id::text=(storage.foldername(name))[2]
      and (q.owner_user_id=(select auth.uid()) or (select private.current_role())='admin'::public.app_role)
      and q.organization_id::text=(storage.foldername(name))[1]
  )
);

drop policy if exists quote_files_update on storage.objects;
create policy quote_files_update on storage.objects for update to authenticated
using (
  bucket_id='quotes' and exists(
    select 1 from public.quotes q where q.id::text=(storage.foldername(name))[2]
      and (q.owner_user_id=(select auth.uid()) or (select private.current_role())='admin'::public.app_role)
  )
)
with check (
  bucket_id='quotes' and exists(
    select 1 from public.quotes q where q.id::text=(storage.foldername(name))[2]
      and (q.owner_user_id=(select auth.uid()) or (select private.current_role())='admin'::public.app_role)
  )
);


-- ===== 202609260011_seed_master_data.sql =====
-- Initial production-safe master data. Rename organization/department/team after deploy.
insert into public.organizations(id,name,timezone)
values ('00000000-0000-0000-0000-000000000001','Sales CRM','Asia/Ho_Chi_Minh')
on conflict (id) do nothing;

insert into public.departments(id,organization_id,name,code)
values ('00000000-0000-0000-0000-000000000010','00000000-0000-0000-0000-000000000001','Phòng Bán Hàng','SALES')
on conflict (id) do nothing;

insert into public.teams(id,organization_id,department_id,name)
values
('00000000-0000-0000-0000-000000000101','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000010','Nhóm 1'),
('00000000-0000-0000-0000-000000000102','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000010','Nhóm 2')
on conflict (id) do nothing;

insert into public.lead_sources(organization_id,code,name,category,sort_order,is_priority,response_sla_minutes) values
('00000000-0000-0000-0000-000000000001','facebook_ads','Facebook Ads','paid',10,true,15),
('00000000-0000-0000-0000-000000000001','website','Website','paid',20,true,15),
('00000000-0000-0000-0000-000000000001','car_marketplace','Sàn xe','paid',30,true,30),
('00000000-0000-0000-0000-000000000001','tiktok','TikTok','paid',40,true,30),
('00000000-0000-0000-0000-000000000001','zalo','Zalo','paid',50,true,30),
('00000000-0000-0000-0000-000000000001','google_ads','Google Ads','paid',60,true,15),
('00000000-0000-0000-0000-000000000001','company_data','Data công ty','company',70,true,60),
('00000000-0000-0000-0000-000000000001','event','Sự kiện','company',80,true,60),
('00000000-0000-0000-0000-000000000001','facebook_personal','Facebook cá nhân','organic',100,false,null),
('00000000-0000-0000-0000-000000000001','facebook_marketplace','Facebook Marketplace','organic',110,false,null),
('00000000-0000-0000-0000-000000000001','facebook_group','Group Facebook','organic',120,false,null),
('00000000-0000-0000-0000-000000000001','showroom','Khách đến showroom','offline',130,false,null),
('00000000-0000-0000-0000-000000000001','hotline','Hotline / Điện thoại vào','offline',140,false,null),
('00000000-0000-0000-0000-000000000001','referral','Khách giới thiệu','relationship',150,false,null),
('00000000-0000-0000-0000-000000000001','old_customer','Khách cũ','relationship',160,false,null),
('00000000-0000-0000-0000-000000000001','collaborator','CTV','relationship',170,false,null),
('00000000-0000-0000-0000-000000000001','internal_referral','Nội bộ giới thiệu','relationship',180,false,null),
('00000000-0000-0000-0000-000000000001','other','Khác','other',999,false,null)
on conflict (organization_id,code) do nothing;

insert into public.pipeline_stages(organization_id,code,display_name,sort_order) values
('00000000-0000-0000-0000-000000000001','new','Khách mới',10),
('00000000-0000-0000-0000-000000000001','contacted','Đã liên hệ',20),
('00000000-0000-0000-0000-000000000001','qualified','Đã xác định nhu cầu',30),
('00000000-0000-0000-0000-000000000001','quoted','Đã báo giá',40),
('00000000-0000-0000-0000-000000000001','appointment','Đã hẹn',50),
('00000000-0000-0000-0000-000000000001','test_drive','Đã lái thử',60),
('00000000-0000-0000-0000-000000000001','negotiation','Đang thương lượng',70),
('00000000-0000-0000-0000-000000000001','deposit','Đã đặt cọc',80)
on conflict (organization_id,code) do nothing;

insert into public.lost_reasons(organization_id,code,display_name,sort_order) values
('00000000-0000-0000-0000-000000000001','price','Giá chưa phù hợp',10),
('00000000-0000-0000-0000-000000000001','other_brand','Mua hãng khác',20),
('00000000-0000-0000-0000-000000000001','other_dealer','Mua đại lý khác',30),
('00000000-0000-0000-0000-000000000001','no_budget','Chưa đủ tài chính',40),
('00000000-0000-0000-0000-000000000001','finance_rejected','Không vay được',50),
('00000000-0000-0000-0000-000000000001','delayed','Hoãn mua',60),
('00000000-0000-0000-0000-000000000001','no_contact','Không liên hệ được',70),
('00000000-0000-0000-0000-000000000001','no_need','Không còn nhu cầu',80),
('00000000-0000-0000-0000-000000000001','junk','Lead rác / sai thông tin',90),
('00000000-0000-0000-0000-000000000001','other','Khác',999)
on conflict (organization_id,code) do nothing;

insert into public.task_types(organization_id,code,display_name,activity_type,sort_order) values
('00000000-0000-0000-0000-000000000001','call','Gọi khách','call',10),
('00000000-0000-0000-0000-000000000001','message','Nhắn khách','message',20),
('00000000-0000-0000-0000-000000000001','send_quote','Gửi báo giá','quote_sent',30),
('00000000-0000-0000-0000-000000000001','consult','Tư vấn','consultation',40),
('00000000-0000-0000-0000-000000000001','appointment','Hẹn gặp','appointment',50),
('00000000-0000-0000-0000-000000000001','test_drive','Lái thử','test_drive',60),
('00000000-0000-0000-0000-000000000001','prospecting','Tìm khách mới',null,70),
('00000000-0000-0000-0000-000000000001','post_content','Đăng bài',null,80),
('00000000-0000-0000-0000-000000000001','video','Quay video',null,90),
('00000000-0000-0000-0000-000000000001','finance','Tư vấn tài chính','consultation',100),
('00000000-0000-0000-0000-000000000001','documents','Thu hồ sơ','note',110),
('00000000-0000-0000-0000-000000000001','deposit','Nhận cọc','deposit',120),
('00000000-0000-0000-0000-000000000001','delivery_prepare','Chuẩn bị giao xe','note',130),
('00000000-0000-0000-0000-000000000001','after_sales','Chăm sóc sau bán','message',140),
('00000000-0000-0000-0000-000000000001','customer_followup','Chăm sóc lại khách','call',150),
('00000000-0000-0000-0000-000000000001','other','Khác','other',999)
on conflict (organization_id,code) do nothing;

insert into public.care_rules(organization_id,potential_level,max_inactive_hours) values
('00000000-0000-0000-0000-000000000001','hot',24),
('00000000-0000-0000-0000-000000000001','potential',72),
('00000000-0000-0000-0000-000000000001','watch',168)
on conflict (organization_id,potential_level) do nothing;

insert into public.products(organization_id,brand,name,code,sort_order) values
('00000000-0000-0000-0000-000000000001','MG','MG5','mg5',10),
('00000000-0000-0000-0000-000000000001','MG','MG7','mg7',20),
('00000000-0000-0000-0000-000000000001','MG','MG ZS','mg_zs',30),
('00000000-0000-0000-0000-000000000001','MG','MG HS','mg_hs',40),
('00000000-0000-0000-0000-000000000001','MG','MG RX5','mg_rx5',50),
('00000000-0000-0000-0000-000000000001','MG','MG4','mg4',60),
('00000000-0000-0000-0000-000000000001','MG','MG G50','mg_g50',70)
on conflict (organization_id,code) do nothing;


-- ===== 202609260012_hardening_utilities.sql =====
-- Security hardening + utility RPCs used by the completed frontend.

-- Business tables are RPC-first. Remove broad direct insert/update privileges granted earlier.
revoke insert, update on public.customers, public.customer_contacts, public.opportunities, public.tasks from authenticated;

-- Allow only low-risk inline edits. RLS still applies.
grant update (display_name, note, is_archived) on public.customers to authenticated;
grant update (contact_type, raw_value, is_primary) on public.customer_contacts to authenticated;
grant update (
  product_id, variant_id, potential_level, potential_mode, priority,
  purchase_timeline, expected_purchase_date, budget_min, budget_max,
  payment_type, loan_ratio, current_vehicle_note, wants_trade_in,
  competitor_note, note
) on public.opportunities to authenticated;
grant update (title, note, due_at, priority) on public.tasks to authenticated;

create or replace function public.add_customer_contact(
  p_customer_id uuid,
  p_contact_type public.contact_type,
  p_raw_value text,
  p_is_primary boolean default false
)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  c public.customers%rowtype;
  v_id uuid;
begin
  select * into c from public.customers where id=p_customer_id for update;
  if not found then raise exception 'Không tìm thấy khách'; end if;
  if c.owner_user_id<>v_uid and (select private.current_role())<>'admin'::public.app_role then
    raise exception 'Không có quyền thêm liên hệ';
  end if;
  if nullif(trim(coalesce(p_raw_value,'')),'') is null then raise exception 'Thông tin liên hệ không được trống'; end if;
  if p_is_primary then
    update public.customer_contacts set is_primary=false where customer_id=c.id and is_primary;
  end if;
  insert into public.customer_contacts(
    customer_id,organization_id,department_id,team_id,owner_user_id,
    contact_type,raw_value,is_primary
  ) values (
    c.id,c.organization_id,c.department_id,c.team_id,c.owner_user_id,
    p_contact_type,p_raw_value,p_is_primary
  ) returning id into v_id;
  return v_id;
end; $$;

create or replace function public.create_opportunity(
  p_customer_id uuid,
  p_product_id uuid default null,
  p_variant_id uuid default null,
  p_source_id uuid default null
)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  c public.customers%rowtype;
  v_stage uuid;
  v_source uuid;
  v_id uuid;
begin
  select * into c from public.customers where id=p_customer_id for update;
  if not found then raise exception 'Không tìm thấy khách'; end if;
  if c.owner_user_id<>v_uid and (select private.current_role())<>'admin'::public.app_role then
    raise exception 'Không có quyền tạo cơ hội';
  end if;
  if p_product_id is not null and not exists(
    select 1 from public.products p where p.id=p_product_id and p.organization_id=c.organization_id and p.is_active
  ) then raise exception 'Sản phẩm không hợp lệ'; end if;
  if p_variant_id is not null and not exists(
    select 1 from public.product_variants v where v.id=p_variant_id and v.product_id=p_product_id and v.is_active
  ) then raise exception 'Phiên bản không hợp lệ'; end if;
  v_source := coalesce(p_source_id,c.source_id);
  if not exists(select 1 from public.lead_sources s where s.id=v_source and s.organization_id=c.organization_id and s.is_active) then
    raise exception 'Nguồn khách không hợp lệ';
  end if;
  select id into v_stage from public.pipeline_stages
    where organization_id=c.organization_id and code='new' and is_active limit 1;
  if v_stage is null then raise exception 'Chưa cấu hình giai đoạn Khách mới'; end if;
  insert into public.opportunities(
    customer_id,organization_id,department_id,team_id,owner_user_id,
    source_id,product_id,variant_id,stage_id,created_by
  ) values (
    c.id,c.organization_id,c.department_id,c.team_id,c.owner_user_id,
    v_source,p_product_id,p_variant_id,v_stage,v_uid
  ) returning id into v_id;
  return v_id;
end; $$;

create or replace function public.cancel_task(p_task_id uuid, p_note text default null)
returns boolean
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  t public.tasks%rowtype;
begin
  select * into t from public.tasks where id=p_task_id for update;
  if not found then return false; end if;
  if t.assigned_user_id<>v_uid and (select private.current_role())<>'admin'::public.app_role then
    raise exception 'Không có quyền hủy công việc';
  end if;
  if t.status<>'pending'::public.task_status then return false; end if;
  update public.tasks
    set status='cancelled', cancelled_at=now(), note=coalesce(nullif(trim(p_note),''),note)
  where id=t.id;
  return true;
end; $$;

create or replace function public.attach_quote_file(p_quote_id uuid, p_storage_path text)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  q public.quotes%rowtype;
  v_path text := nullif(trim(coalesce(p_storage_path,'')),'');
begin
  select * into q from public.quotes where id=p_quote_id for update;
  if not found then raise exception 'Không tìm thấy báo giá'; end if;
  if q.owner_user_id<>v_uid and (select private.current_role())<>'admin'::public.app_role then
    raise exception 'Không có quyền đính kèm file';
  end if;
  if v_path is null then raise exception 'Đường dẫn file không hợp lệ'; end if;
  if split_part(v_path,'/',1)<>q.organization_id::text or split_part(v_path,'/',2)<>q.id::text then
    raise exception 'Đường dẫn file không đúng quy ước';
  end if;
  update public.quotes set storage_path=v_path where id=q.id;
end; $$;

revoke execute on function public.add_customer_contact(uuid,public.contact_type,text,boolean) from public, anon;
revoke execute on function public.create_opportunity(uuid,uuid,uuid,uuid) from public, anon;
revoke execute on function public.cancel_task(uuid,text) from public, anon;
revoke execute on function public.attach_quote_file(uuid,text) from public, anon;

grant execute on function public.add_customer_contact(uuid,public.contact_type,text,boolean) to authenticated;
grant execute on function public.create_opportunity(uuid,uuid,uuid,uuid) to authenticated;
grant execute on function public.cancel_task(uuid,text) to authenticated;
grant execute on function public.attach_quote_file(uuid,text) to authenticated;


-- ===== 202609270013_customer_filters.sql =====
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


-- ===== 202609270014_customer_name_search_fix.sql =====
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


-- ===== 202609270015_locked_notifications.sql =====
-- Locked sessions must not retain notification access.
drop policy if exists notification_self_read on public.notifications;
create policy notification_self_read on public.notifications for select to authenticated
using (user_id = (select auth.uid()) and (select private.is_active_user()));

drop policy if exists notification_self_update on public.notifications;
create policy notification_self_update on public.notifications for update to authenticated
using (user_id = (select auth.uid()) and (select private.is_active_user()))
with check (user_id = (select auth.uid()) and (select private.is_active_user()));


-- ===== 202609270016_quote_sent_idempotent.sql =====
-- Make mark_quote_sent safe to retry after a lost network response.
create or replace function public.mark_quote_sent(p_quote_id uuid,p_sent_at timestamptz default now())
returns void
language plpgsql security definer set search_path = ''
as $$
declare v_uid uuid := (select auth.uid()); q public.quotes%rowtype; v_quoted_stage uuid; v_current_sort int; v_quoted_sort int;
begin
  select * into q from public.quotes where id=p_quote_id for update;
  if not found or (q.owner_user_id<>v_uid and (select private.current_role())<>'admin'::public.app_role) then raise exception 'Không có quyền'; end if;
  -- A retried request must not add a second quote_sent activity.
  if q.status in ('sent'::public.quote_status,'accepted'::public.quote_status) then return; end if;
  update public.quotes set status='sent',sent_at=coalesce(p_sent_at,now()) where id=q.id;
  insert into public.activities(customer_id,opportunity_id,organization_id,department_id,team_id,owner_user_id,activity_type,note,occurred_at,created_by)
  values(q.customer_id,q.opportunity_id,q.organization_id,q.department_id,q.team_id,q.owner_user_id,'quote_sent',concat('Báo giá #',q.version),coalesce(p_sent_at,now()),v_uid);
  select id,sort_order into v_quoted_stage,v_quoted_sort from public.pipeline_stages where organization_id=q.organization_id and code='quoted' and is_active limit 1;
  select s.sort_order into v_current_sort from public.opportunities o join public.pipeline_stages s on s.id=o.stage_id where o.id=q.opportunity_id;
  if v_quoted_stage is not null and coalesce(v_current_sort,0)<v_quoted_sort then
    update public.opportunities set stage_id=v_quoted_stage where id=q.opportunity_id;
  end if;
end; $$;

