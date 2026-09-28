-- Locked sessions must not retain notification access.
drop policy if exists notification_self_read on public.notifications;
create policy notification_self_read on public.notifications for select to authenticated
using (user_id = (select auth.uid()) and (select private.is_active_user()));

drop policy if exists notification_self_update on public.notifications;
create policy notification_self_update on public.notifications for update to authenticated
using (user_id = (select auth.uid()) and (select private.is_active_user()))
with check (user_id = (select auth.uid()) and (select private.is_active_user()));
