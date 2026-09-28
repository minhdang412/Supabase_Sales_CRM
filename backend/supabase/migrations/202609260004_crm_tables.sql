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
