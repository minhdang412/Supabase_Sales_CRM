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
