# Bootstrap Admin đầu tiên

1. Chạy toàn bộ migrations.
2. Trong Supabase Dashboard > Authentication, tạo/invite user Admin đầu tiên.
3. Trigger sẽ tạo `profiles` với trạng thái `locked`.
4. Lấy UUID user rồi chạy SQL sau (thay `<USER_UUID>`):

```sql
update public.profiles
set organization_id='00000000-0000-0000-0000-000000000001',
    department_id=null,
    team_id=null,
    role='admin',
    status='active',
    full_name=coalesce(full_name,'Quản trị viên')
where id='<USER_UUID>'::uuid;
```

Sau đó Admin có thể dùng Edge Function `admin-create-user` để mời các tài khoản còn lại.

## Gán cơ cấu ban đầu
- Department: `00000000-0000-0000-0000-000000000010`
- Nhóm 1: `00000000-0000-0000-0000-000000000101`
- Nhóm 2: `00000000-0000-0000-0000-000000000102`

Đổi tên organization/department/team trong giao diện Admin hoặc SQL sau khi bootstrap.
