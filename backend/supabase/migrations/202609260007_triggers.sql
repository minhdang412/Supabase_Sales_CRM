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
