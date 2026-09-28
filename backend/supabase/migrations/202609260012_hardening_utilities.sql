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
