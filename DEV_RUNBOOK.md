# Sales CRM — DEV handoff sau rà soát bổ sung

## Đã xác minh tại workspace

- Patch UI v1.1 có Customer Filters, Pipeline dạng danh sách, Báo giá placeholder, form báo giá không có PDF và layout Task mobile.
- `npm install` và `npm run build` thành công sau khi sửa type/config.
- Đã sửa tìm tên có dấu ở RPC, trạng thái lỗi tải Customer/Pipeline, tránh Demo Mode âm thầm trên production, xóa cache dữ liệu giữa các tài khoản, và PWA không trả HTML thay cho API.
- Edge Functions dùng publishable/secret keys trên server, xác thực JWT bằng `getUser`, xác minh Admin active, kiểm tra cấu trúc phòng/nhóm trước khi ghi. Chưa deploy.
- Thêm migration 014 để sửa DEV nếu 013 đã được đẩy, migration 015 để chặn notification của tài khoản locked và migration 016 để đánh dấu báo giá an toàn khi thử lại.
- Migration 017 chặn locked user và Admin khác tổ chức tại các RPC ghi, ràng buộc task với người được giao, sửa ngày báo cáo theo giờ Việt Nam và sắp xếp task Today trước khi giới hạn.
- Frontend đã thêm tải tiếp danh sách khách, bỏ giới hạn âm thầm Task/Pipeline, sửa tab Hôm nay, form Admin và ngày báo cáo. Admin Function có thể gán Auth user chưa có tổ chức vào CRM.

## Kiểm tra DEV ngày 27/09/2026

- URL và publishable key kết nối được: Auth settings HTTP 200.
- Truy vấn bảng lead_sources với quyền anon bị chặn (permission denied), phù hợp với cấu hình không public data.
- Endpoint search_customers_filtered tồn tại nhưng anon bị từ chối execute. Điều này cho thấy RPC 013 đã có trên DEV, **không xác nhận migration history hoặc quyền authenticated**.
- Build frontend bằng cấu hình DEV PASS. File frontend/.env.development có URL + publishable key (đều public). Không có secret key trong frontend.
- Người dùng đã xác nhận đăng nhập Admin thành công trên localhost ngày 28/09/2026 qua ảnh giao diện. Workspace không có session Admin hoặc tài khoản thử để chạy RLS; chưa chạy db push hoặc deploy Functions. Quyền dữ liệu chưa được xác minh. Migration 017 mới chỉ được rà soát source, chưa chạy trên DEV.

## Áp dụng vào Supabase DEV đã link

Giữ nguyên dự án DEV và migrations 001–012 đã chạy. Source có `backend/supabase/config.toml` cho CLI. Liên kết đúng project DEV rồi dùng PowerShell `npx.cmd`/`npm.cmd`:

```powershell
cd backend
npx.cmd supabase login
npx.cmd supabase link --project-ref tkylujqkrexpswlmgkrt
npx.cmd supabase migration list
npx.cmd supabase db push --dry-run
```

Endpoint 013 đã tồn tại. Nếu lịch sử migration đã ghi 013, kỳ vọng 014–017. Nếu 013 chưa được ghi nhưng RPC được tạo thủ công, dry-run có thể hiện 013–017; kiểm tra lịch sử trước khi đẩy. Dừng và đối chiếu lịch sử migration nếu xuất hiện 001–012 hoặc lỗi remote/local mismatch.

```powershell
npx.cmd supabase db push
npx.cmd supabase functions deploy admin-create-user
npx.cmd supabase functions deploy admin-lock-user
npx.cmd supabase functions deploy admin-update-user
```

Functions mặc định yêu cầu JWT; không dùng `--no-verify-jwt`. Supabase hosted cung cấp `SUPABASE_PUBLISHABLE_KEYS` và `SUPABASE_SECRET_KEYS` cho Functions. Bản local CLI có thể dùng `SUPABASE_PUBLISHABLE_KEY`/`SUPABASE_SECRET_KEY` riêng trong môi trường server. Không đặt secret key vào `frontend/.env`.

## Kết nối frontend

Source có `frontend/.env.development` với URL và publishable key DEV để chạy `npm run dev`. Không tạo `frontend/.env` chứa DEV URL vì file đó cũng được dùng khi build production. Khi deploy production, đặt biến môi trường production trong hosting hoặc `.env.production.local` từ `.env.example`:

```env
VITE_SUPABASE_URL=https://<project-ref>.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
VITE_FORCE_DEMO=false
```

Build production chỉ được deploy khi URL và publishable key trỏ đúng dự án Production. Thiếu cấu hình sẽ hiện lỗi cấu hình thay vì Demo.

```powershell
cd frontend
npm.cmd ci
npm.cmd run dev
```

Đăng nhập Admin thật. Xác nhận thanh Demo không hiển thị; mở Customer, Pipeline, Task, báo giá trong hồ sơ và màn Báo giá placeholder. Nếu RPC lỗi, UI Customer/Pipeline hiển thị lỗi thay vì báo trống. Auth user đã tạo sẵn nhưng profile còn locked và chưa gán organization có thể được gán từ Admin → Tạo tài khoản bằng đúng email; mật khẩu Auth hiện tại không thay đổi. Nếu login báo `Invalid login credentials`, xác minh email/mật khẩu hoặc đặt lại mật khẩu trong Auth.

## Tài khoản thử và RLS

Tạo 4 tài khoản thử qua Admin trong DEV: Sales A và B cùng phòng (có thể khác nhóm), Trưởng nhóm ở một trong hai nhóm, Trưởng phòng cùng phòng. Không tạo 20 user thật ngay. Đặt các biến môi trường ở máy local, tránh đưa mật khẩu vào source:

```powershell
$env:DEV_URL='https://<project-ref>.supabase.co'
$env:DEV_PUBLISHABLE_KEY='sb_publishable_...'
$env:SALES_A_EMAIL='...'; $env:SALES_A_PASSWORD='...'
$env:SALES_B_EMAIL='...'; $env:SALES_B_PASSWORD='...'
$env:MANAGER_EMAIL='...'; $env:MANAGER_PASSWORD='...'
$env:LEADER_EMAIL='...'; $env:LEADER_PASSWORD='...'
node .\scripts\rls-smoke.mjs
```

Script tạo hai hồ sơ đánh dấu `RLS-SMOKE-...` trong DEV và giữ lại để đối chiếu. Nó kiểm tra trùng SĐT hợp lệ, mỗi Sales chỉ tìm thấy hồ sơ của mình, SELECT trực tiếp không lộ khách khác, Sales/Trưởng nhóm bị từ chối Duplicate Report, Trưởng phòng thấy cả hai, và team scope (nếu có tài khoản Trưởng nhóm).

Tiếp tục kiểm thử thủ công theo `backend/docs/TEST_CASES.md`: transfer, task/activity, won/lost, quote versioning, user locked và quyền quản trị. Chưa được coi là PASS cho tới khi chạy bằng user thật trên DEV.

## Production gate

Chỉ tạo Supabase Production và deploy sau khi:
1. DEV migrations/Functions và login Admin chạy thực tế.
2. RLS smoke + duplicate + locked user + workflow đầy đủ PASS.
3. Mobile UI được kiểm trên điện thoại thực (320–390 px và thiết bị chính).
4. `npm.cmd run build` PASS với biến môi trường Production.
5. VITE_ chỉ chứa URL/publishable key, không có secret key.
6. Cấu hình Auth Site URL/redirect cho domain production, bucket và policies được kiểm lại.
