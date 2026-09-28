# Supabase Sales CRM v1 – Backend

Backend Supabase/PostgreSQL cho CRM bán hàng: 4 cấp quyền, khách của từng Sales độc lập, khách trùng hợp lệ, Trưởng phòng/Admin mới có Duplicate Report, Pipeline, Task, Activity, Báo giá, Reporting và Storage private.

## Thành phần
- Supabase Auth
- PostgreSQL + RLS
- Database RPC/transaction
- Trigger + Views
- Private Storage bucket `quotes`
- Edge Functions quản trị account

## Cấu trúc
- `supabase/migrations/`: migration 001–012, chạy theo thứ tự.
- `supabase/functions/`: `admin-create-user`, `admin-lock-user`, `admin-update-user`.
- `supabase/seed.sql`: seed tiện dụng.
- `docs/`: UI/UX, phân quyền, test, bootstrap.
- `SUPABASE_CRM_V1_FULL.sql`: SQL gộp để đọc/thử nhanh; production ưu tiên migrations.

## Triển khai database
```bash
supabase login
supabase init
supabase link --project-ref <PROJECT_REF>
supabase db push --dry-run
supabase db push
```

## Deploy Edge Functions
```bash
supabase functions deploy admin-create-user
supabase functions deploy admin-lock-user
supabase functions deploy admin-update-user
```
Các function sử dụng `SUPABASE_PUBLISHABLE_KEYS` và `SUPABASE_SECRET_KEYS` mặc định của hosted runtime. Không đưa secret key vào frontend. Xem `../DEV_RUNBOOK.md`.

## Bootstrap Admin đầu tiên
Tạo user Auth đầu tiên trong Supabase Dashboard và làm theo:
- `docs/BOOTSTRAP_FIRST_ADMIN.md`
- `BOOTSTRAP_FIRST_ADMIN.sql.template`

## Quy tắc nghiệp vụ bắt buộc
1. Không public signup.
2. Không UNIQUE SĐT/email/social contact; khách trùng là hợp lệ.
3. Sales không được nhận thông tin duplicate từ luồng tạo khách.
4. Trưởng phòng/Admin mới được execute Duplicate Report.
5. `profiles.status='locked'` bị RLS chặn ngay cả khi session còn sống.
6. Không hard-delete dữ liệu nghiệp vụ.
7. UI v1.1 không dùng PDF; bucket `quotes` private chỉ giữ tương thích backend, chưa dùng trong luồng báo giá.
8. Business mutation quan trọng đi qua RPC; frontend không được tự đổi owner/scope/stage/status.

## RPC chính
- `create_lead`
- `add_customer_contact`
- `create_opportunity`
- `add_activity`
- `create_task`
- `complete_task` / `undo_complete_task` / `cancel_task`
- `change_opportunity_stage`
- `pause_opportunity`
- `mark_opportunity_won` / `mark_opportunity_lost`
- `create_quote` / `attach_quote_file` / `mark_quote_sent`
- `transfer_customer`
- `search_customers`
- `get_today_dashboard`
- `get_duplicate_customers`
- `get_funnel_report`
- `get_lead_source_report`

## Phân quyền
- Sales: dữ liệu owner của bản thân.
- Trưởng nhóm: đọc dữ liệu team, không có Duplicate Report.
- Trưởng phòng: đọc toàn department + Duplicate Report.
- Admin: toàn organization + master/account configuration.

## Kiểm tra trước production
- Test RLS với đủ 4 role bằng API thật, không chỉ UI.
- Hai Sales nhập cùng SĐT phải cùng thành công và không bị cảnh báo.
- Sales search chỉ thấy record thuộc scope.
- Trưởng phòng gọi Duplicate Report được; Sales/Trưởng nhóm không execute được.
- File PDF của scope khác phải bị Storage RLS chặn.
- User locked phải bị database từ chối.
- Chuyển khách phải giữ nguyên `created_by` lịch sử nhưng cập nhật scope hiện hành đúng.
