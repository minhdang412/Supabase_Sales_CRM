-- Revalidate CRM write RPCs at execution time. Locked profiles and cross-organization admins cannot mutate rows.

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
  if not (select private.is_active_user()) then raise exception 'Tài khoản bị khóa'; end if;
  select * into c from public.customers where id=p_customer_id;
  if not found then raise exception 'Không tìm thấy khách'; end if;
  if not (select private.can_read_scope(c.owner_user_id,c.team_id,c.department_id,c.organization_id)) then raise exception 'Không có quyền'; end if;
  if (c.owner_user_id is distinct from v_uid and (select private.current_role()) is distinct from 'admin'::public.app_role) then raise exception 'Không có quyền ghi tương tác'; end if;
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
  if not (select private.is_active_user()) then raise exception 'Tài khoản bị khóa'; end if;
  if not (select private.can_assign_to_user(p_assigned_user_id)) then raise exception 'Không có quyền giao công việc cho tài khoản này'; end if;
  select * into t from public.profiles where id=p_assigned_user_id and status='active'::public.user_status;
  select * into tt from public.task_types where id=p_task_type_id and organization_id=t.organization_id and is_active;
  if not found then raise exception 'Loại công việc không hợp lệ'; end if;
  if p_due_at is null then raise exception 'Cần thời gian thực hiện'; end if;
  if p_customer_id is not null and not exists(select 1 from public.customers c where c.id=p_customer_id and (select private.can_read_scope(c.owner_user_id,c.team_id,c.department_id,c.organization_id))) then raise exception 'Không có quyền với khách'; end if;
  if p_opportunity_id is not null and not exists(select 1 from public.opportunities o where o.id=p_opportunity_id and (select private.can_read_scope(o.owner_user_id,o.team_id,o.department_id,o.organization_id))) then raise exception 'Không có quyền với cơ hội'; end if;
  if p_customer_id is not null and not exists(select 1 from public.customers c where c.id=p_customer_id and c.organization_id=t.organization_id and c.owner_user_id=t.id) then raise exception 'Khách không thuộc người được giao'; end if;
  if p_opportunity_id is not null and not exists(select 1 from public.opportunities o where o.id=p_opportunity_id and o.organization_id=t.organization_id and o.owner_user_id=t.id and (p_customer_id is null or o.customer_id=p_customer_id)) then raise exception 'Cơ hội không thuộc người được giao'; end if;
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
  if not (select private.is_active_user()) then raise exception 'Tài khoản bị khóa'; end if;
  select * into t from public.tasks where id=p_task_id for update;
  if not found then raise exception 'Không tìm thấy công việc'; end if;
  if not (select private.can_read_scope(t.assigned_user_id,t.team_id,t.department_id,t.organization_id)) then raise exception 'Không có quyền'; end if;
  if (t.assigned_user_id is distinct from v_uid and (select private.current_role()) is distinct from 'admin'::public.app_role) then raise exception 'Không có quyền hoàn thành công việc'; end if;
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
  if not (select private.is_active_user()) then raise exception 'Tài khoản bị khóa'; end if;
  select * into t from public.tasks where id=p_task_id for update;
  if not found or t.assigned_user_id<>v_uid or t.status<>'completed'::public.task_status then return false; end if;
  if not (select private.can_read_scope(t.assigned_user_id,t.team_id,t.department_id,t.organization_id)) then raise exception 'Không có quyền'; end if;
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
  if not (select private.is_active_user()) then raise exception 'Tài khoản bị khóa'; end if;
  select * into o from public.opportunities where id=p_opportunity_id for update;
  if not found then raise exception 'Không tìm thấy cơ hội'; end if;
  if not (select private.can_read_scope(o.owner_user_id,o.team_id,o.department_id,o.organization_id)) then raise exception 'Không có quyền'; end if;
  if (o.owner_user_id is distinct from v_uid and (select private.current_role()) is distinct from 'admin'::public.app_role) then raise exception 'Không có quyền đổi giai đoạn'; end if;
  if not exists(select 1 from public.pipeline_stages s where s.id=p_stage_id and s.organization_id=o.organization_id and s.is_active) then raise exception 'Giai đoạn không hợp lệ'; end if;
  update public.opportunities set stage_id=p_stage_id where id=o.id;
end; $$;

create or replace function public.pause_opportunity(p_opportunity_id uuid,p_until timestamptz,p_note text default null)
returns void
language plpgsql security definer set search_path = ''
as $$
declare v_uid uuid := (select auth.uid()); o public.opportunities%rowtype; v_task_type uuid;
begin
  if not (select private.is_active_user()) then raise exception 'Tài khoản bị khóa'; end if;
  select * into o from public.opportunities where id=p_opportunity_id for update;
  if not found or ((o.owner_user_id is distinct from v_uid and (select private.current_role()) is distinct from 'admin'::public.app_role)) then raise exception 'Không có quyền'; end if;
  if not (select private.can_read_scope(o.owner_user_id,o.team_id,o.department_id,o.organization_id)) then raise exception 'Không có quyền'; end if;
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
  if not (select private.is_active_user()) then raise exception 'Tài khoản bị khóa'; end if;
  select * into o from public.opportunities where id=p_opportunity_id for update;
  if not found or ((o.owner_user_id is distinct from v_uid and (select private.current_role()) is distinct from 'admin'::public.app_role)) then raise exception 'Không có quyền'; end if;
  if not (select private.can_read_scope(o.owner_user_id,o.team_id,o.department_id,o.organization_id)) then raise exception 'Không có quyền'; end if;
  update public.opportunities set status='won',won_at=now(),closed_at=now(),final_sale_price=p_final_sale_price,note=coalesce(p_note,note) where id=o.id;
  update public.tasks set status='cancelled',cancelled_at=now() where opportunity_id=o.id and status='pending'::public.task_status;
end; $$;

create or replace function public.mark_opportunity_lost(p_opportunity_id uuid,p_lost_reason_id uuid,p_note text default null)
returns void
language plpgsql security definer set search_path = ''
as $$
declare v_uid uuid := (select auth.uid()); o public.opportunities%rowtype;
begin
  if not (select private.is_active_user()) then raise exception 'Tài khoản bị khóa'; end if;
  select * into o from public.opportunities where id=p_opportunity_id for update;
  if not found or ((o.owner_user_id is distinct from v_uid and (select private.current_role()) is distinct from 'admin'::public.app_role)) then raise exception 'Không có quyền'; end if;
  if not (select private.can_read_scope(o.owner_user_id,o.team_id,o.department_id,o.organization_id)) then raise exception 'Không có quyền'; end if;
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
  if not (select private.is_active_user()) then raise exception 'Tài khoản bị khóa'; end if;
  select * into o from public.opportunities where id=p_opportunity_id for update;
  if not found or ((o.owner_user_id is distinct from v_uid and (select private.current_role()) is distinct from 'admin'::public.app_role)) then raise exception 'Không có quyền'; end if;
  if not (select private.can_read_scope(o.owner_user_id,o.team_id,o.department_id,o.organization_id)) then raise exception 'Không có quyền'; end if;
  select coalesce(max(version),0)+1 into v_version from public.quotes where opportunity_id=o.id;
  insert into public.quotes(customer_id,opportunity_id,organization_id,department_id,team_id,owner_user_id,version,product_id,variant_id,list_price,discount_amount,final_price,promotion_note,storage_path,created_by)
  values(o.customer_id,o.id,o.organization_id,o.department_id,o.team_id,o.owner_user_id,v_version,o.product_id,o.variant_id,p_list_price,p_discount_amount,p_final_price,p_promotion_note,p_storage_path,v_uid)
  returning id into v_id;
  return v_id;
end; $$;

create or replace function public.transfer_customer(p_customer_id uuid,p_new_owner_user_id uuid,p_reason text default null)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid()); v_role public.app_role := (select private.current_role());
  c public.customers%rowtype; np public.profiles%rowtype;
begin
  if not (select private.is_active_user()) then raise exception 'Tài khoản bị khóa'; end if;
  select * into c from public.customers where id=p_customer_id for update;
  if not found then raise exception 'Không tìm thấy khách'; end if;
  if not (select private.can_read_scope(c.owner_user_id,c.team_id,c.department_id,c.organization_id)) then raise exception 'Không có quyền'; end if;
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
  if not (select private.is_active_user()) then raise exception 'Tài khoản bị khóa'; end if;
  select * into c from public.customers where id=p_customer_id for update;
  if not found then raise exception 'Không tìm thấy khách'; end if;
  if not (select private.can_read_scope(c.owner_user_id,c.team_id,c.department_id,c.organization_id)) then raise exception 'Không có quyền'; end if;
  if (c.owner_user_id is distinct from v_uid and (select private.current_role()) is distinct from 'admin'::public.app_role) then
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
  if not (select private.is_active_user()) then raise exception 'Tài khoản bị khóa'; end if;
  select * into c from public.customers where id=p_customer_id for update;
  if not found then raise exception 'Không tìm thấy khách'; end if;
  if not (select private.can_read_scope(c.owner_user_id,c.team_id,c.department_id,c.organization_id)) then raise exception 'Không có quyền'; end if;
  if (c.owner_user_id is distinct from v_uid and (select private.current_role()) is distinct from 'admin'::public.app_role) then
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
  if not (select private.is_active_user()) then raise exception 'Tài khoản bị khóa'; end if;
  select * into t from public.tasks where id=p_task_id for update;
  if not found then return false; end if;
  if not (select private.can_read_scope(t.assigned_user_id,t.team_id,t.department_id,t.organization_id)) then raise exception 'Không có quyền'; end if;
  if (t.assigned_user_id is distinct from v_uid and (select private.current_role()) is distinct from 'admin'::public.app_role) then
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
  if not (select private.is_active_user()) then raise exception 'Tài khoản bị khóa'; end if;
  select * into q from public.quotes where id=p_quote_id for update;
  if not found then raise exception 'Không tìm thấy báo giá'; end if;
  if not (select private.can_read_scope(q.owner_user_id,q.team_id,q.department_id,q.organization_id)) then raise exception 'Không có quyền'; end if;
  if (q.owner_user_id is distinct from v_uid and (select private.current_role()) is distinct from 'admin'::public.app_role) then
    raise exception 'Không có quyền đính kèm file';
  end if;
  if v_path is null then raise exception 'Đường dẫn file không hợp lệ'; end if;
  if split_part(v_path,'/',1)<>q.organization_id::text or split_part(v_path,'/',2)<>q.id::text then
    raise exception 'Đường dẫn file không đúng quy ước';
  end if;
  update public.quotes set storage_path=v_path where id=q.id;
end; $$;

create or replace function public.mark_quote_sent(p_quote_id uuid,p_sent_at timestamptz default now())
returns void
language plpgsql security definer set search_path = ''
as $$
declare v_uid uuid := (select auth.uid()); q public.quotes%rowtype; v_quoted_stage uuid; v_current_sort int; v_quoted_sort int;
begin
  if not (select private.is_active_user()) then raise exception 'Tài khoản bị khóa'; end if;
  select * into q from public.quotes where id=p_quote_id for update;
  if not found or ((q.owner_user_id is distinct from v_uid and (select private.current_role()) is distinct from 'admin'::public.app_role)) then raise exception 'Không có quyền'; end if;
  if not (select private.can_read_scope(q.owner_user_id,q.team_id,q.department_id,q.organization_id)) then raise exception 'Không có quyền'; end if;
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

create or replace function public.get_duplicate_customers(p_contact_type public.contact_type default null)
returns table(match_type public.contact_type,match_value text,record_count bigint,records jsonb)
language plpgsql security definer set search_path = ''
as $$
begin
  if not coalesce((select private.current_role()) in ('sales_manager'::public.app_role,'admin'::public.app_role),false) then
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
    where x.created_at >= (p_from::timestamp at time zone 'Asia/Ho_Chi_Minh') and x.created_at < ((p_to+1)::timestamp at time zone 'Asia/Ho_Chi_Minh')
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
    where x.created_at>=(p_from::timestamp at time zone 'Asia/Ho_Chi_Minh') and x.created_at<((p_to+1)::timestamp at time zone 'Asia/Ho_Chi_Minh')
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
      select t.id,t.title,t.due_at,t.priority,t.customer_id,t.opportunity_id from scoped_tasks t where t.due_at<now() order by t.due_at,t.id limit 20
    ) x
  ), upcoming as (
    select coalesce(jsonb_agg(to_jsonb(x) order by x.due_at),'[]'::jsonb) j from (
      select t.id,t.title,t.due_at,t.priority,t.customer_id,t.opportunity_id from scoped_tasks t where t.due_at>=now() and t.due_at<v_end order by t.due_at,t.id limit 20
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
