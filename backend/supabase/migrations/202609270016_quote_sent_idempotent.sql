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
