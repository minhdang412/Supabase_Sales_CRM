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
