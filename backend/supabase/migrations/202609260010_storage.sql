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
