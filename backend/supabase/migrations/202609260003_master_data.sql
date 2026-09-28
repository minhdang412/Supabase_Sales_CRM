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
