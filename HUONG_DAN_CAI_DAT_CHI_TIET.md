# Hướng dẫn cài đặt Sales CRM — bản source ngày 28/09/2026

Bản này gồm Supabase migrations/RLS/RPC/Edge Functions và frontend React, Vite, Tailwind CSS, Lucide React, PWA. Đường dẫn DEV đã có sẵn trong `frontend/.env.development`. Admin DEV và dữ liệu seed đã được tạo trước đó; **không bootstrap hoặc seed lại** trên DEV.

Nếu muốn deploy trực tiếp lên Vercel mà không chạy frontend local, xem `HUONG_DAN_DEPLOY_VERCEL.md`. Những bước kiểm tra migration/Edge Functions ở Supabase DEV vẫn cần thực hiện.

## A. Chuẩn bị trên Windows

1. Giải nén ZIP vào một thư mục có quyền ghi, ví dụ `C:\SalesCRM`. Trong thư mục giải nén phải thấy `backend`, `frontend`, `DEV_RUNBOOK.md` và file hướng dẫn này.
2. Cài Node.js phù hợp với Vite trong gói: **Node 20.19+ hoặc 22.12+**. Mở PowerShell mới và kiểm tra:

   ```powershell
   node --version
   npm.cmd --version
   ```

3. Mở PowerShell ở thư mục đã giải nén. Nếu đường dẫn có dấu cách, dùng dấu nháy đơn:

   ```powershell
   Set-Location 'C:\SalesCRM\Supabase_Sales_CRM'
   ```

   Thay đường dẫn ví dụ bằng đường dẫn thật; thư mục cuối là nơi có `backend` và `frontend`.

## B. Chạy giao diện với Supabase DEV đã có

1. Vào frontend, cài đúng dependencies trong lockfile:

   ```powershell
   Set-Location .\frontend
   npm.cmd ci
   ```

2. Kiểm tra `frontend/.env.development` đang có:

   ```env
   VITE_SUPABASE_URL=https://tkylujqkrexpswlmgkrt.supabase.co
   VITE_SUPABASE_PUBLISHABLE_KEY=sb_publishable_vgQcOVKW57Av9qXxU3OQbg_cnNMX4rP
   VITE_FORCE_DEMO=false
   ```

   Đây là URL và publishable key của DEV. Không đặt service role/secret key vào frontend. Không tạo `frontend/.env` chứa DEV URL vì file này cũng có thể ảnh hưởng build production.

3. Chạy ứng dụng:

   ```powershell
   npm.cmd run dev
   ```

4. Mở `http://localhost:5173`, đăng nhập Admin DEV đã bootstrap. Thanh Demo không được xuất hiện. Kiểm tra Hôm nay, Khách hàng và bộ lọc, Quy trình, Công việc, Báo cáo. Menu Báo giá hiển thị “Hoàn thiện sau”; form báo giá trong hồ sơ khách không xuất PDF. Nhấn `Ctrl+C` tại PowerShell để dừng.

Nếu một số màn báo thiếu RPC/quyền, hoàn tất phần C trước khi kết luận lỗi giao diện.

## C. Cập nhật backend trên Supabase DEV hiện tại

Các migrations 001–012 đã chạy trước đây; RPC của 013 đã được quan sát trên DEV, nhưng lịch sử migration 013 và việc áp dụng 014–017 **chưa được xác minh**. Tuyệt đối không chạy lại `backend/SUPABASE_CRM_V1_FULL.sql` trên dự án này.

1. Đăng nhập Supabase CLI và liên kết đúng dự án DEV:

   ```powershell
   Set-Location 'C:\SalesCRM\Supabase_Sales_CRM\backend'
   npx.cmd supabase login
   npx.cmd supabase link --project-ref tkylujqkrexpswlmgkrt
   ```

   CLI có thể yêu cầu mật khẩu database của dự án; lấy trong Supabase Dashboard. Nếu `npx` hỏi cài CLI, chấp nhận cài cho lần chạy này. Không ghi mật khẩu vào source.

2. Đối chiếu migrations local/remote trước khi thay đổi database:

   ```powershell
   npx.cmd supabase migration list
   npx.cmd supabase db push --dry-run
   ```

   Kiểm tra danh sách dự kiến chỉ gồm những migration chưa áp dụng. Nếu thấy 001–012, hoặc 013 đã có RPC nhưng lịch sử remote chưa ghi nhận 013, **dừng tại đây** và đối chiếu lịch sử với `DEV_RUNBOOK.md` và Supabase Dashboard; đừng tự đánh dấu migration đã chạy khi chưa kiểm tra schema. Mục tiêu là áp dụng chính xác các migration còn thiếu đến `202609270017_rpc_scope_hardening.sql`.

3. Chỉ khi danh sách đã đúng, áp dụng và triển khai ba Edge Functions:

   ```powershell
   npx.cmd supabase db push
   npx.cmd supabase functions deploy admin-create-user
   npx.cmd supabase functions deploy admin-lock-user
   npx.cmd supabase functions deploy admin-update-user
   ```

   Giữ xác thực JWT mặc định của Functions; không thêm `--no-verify-jwt`. Nếu project đã liên kết từ trước, bước `link` không cần chạy lại. Dashboard của DEV phải hiển thị migrations và cả ba Functions tương ứng.

4. Mở lại frontend và thử Admin → Quản lý tài khoản. Việc tạo tài khoản **chỉ trong Authentication → Users** không tự gán vai trò, phòng hoặc nhóm trong CRM. Vào Admin trong ứng dụng, tạo/gán tài khoản với email Auth đó và chọn role, phòng, nhóm phù hợp. Luồng này yêu cầu Function mới đã deploy và Admin active.

   Tài khoản email mới nhận thư mời dẫn đến `/set-password`, nơi nhân viên đặt mật khẩu. Trước khi thử, cấu hình Site URL và Redirect URL của domain frontend theo `HUONG_DAN_DEPLOY_VERCEL.md`. Email Auth đã có trước đó chỉ được gán role/phòng/nhóm; mật khẩu hiện tại không đổi.

## D. Xử lý lỗi đăng nhập đã gặp

`AuthApiError: Invalid login credentials` là lỗi xác thực email/mật khẩu trước khi kiểm tra RLS. Trong Supabase Dashboard của **đúng project DEV**, mở Authentication → Users, xác nhận email đã tồn tại, trạng thái xác nhận email và đặt lại mật khẩu nếu cần. Thử đăng nhập ứng dụng bằng đúng email/mật khẩu mới. Việc thêm role/phòng/nhóm sẽ không chữa lỗi sai mật khẩu.

Sau khi đăng nhập được nhưng thiếu role/phòng/nhóm, dùng màn Admin như phần C. Không thử script `frontend/scripts/rls-smoke.mjs` bằng tài khoản chưa xác thực/gán vai trò. Người dùng đã chọn bỏ qua bài test này ở giai đoạn trước; trong gói này nó vẫn là kiểm thử cần hoàn thành trước Production.

## E. Xác minh trước khi đưa vào sử dụng thật

1. Chạy build source:

   ```powershell
   Set-Location 'C:\SalesCRM\Supabase_Sales_CRM\frontend'
   npm.cmd run build -- --mode development
   ```

2. Trên DEV, đăng nhập lần lượt Sales A/B, Trưởng nhóm, Trưởng phòng, Admin; kiểm tra phạm vi Khách hàng, Pipeline, Công việc, Duplicate Report, chuyển khách, tài khoản bị khóa và báo giá. Dùng `backend/docs/TEST_CASES.md` và `backend/docs/RLS_PERMISSION_MATRIX.md` làm danh sách kiểm tra. Thực hiện bài test API/RLS bằng tài khoản thật trước khi mở Production; kết quả build hoặc màn hình UI không thay thế được kiểm tra RLS.
3. Kiểm tra mobile trên thiết bị thật và PWA qua HTTPS khi có hosting. Ghi lại các lỗi theo `RELEASE_STATUS.md`.

**Trạng thái xuất gói:** build DEV và production đã chạy thành công trong workspace. Chưa chạy xác thực đăng nhập/RLS bằng tài khoản DEV hợp lệ, chưa xác nhận migration 017 đã áp dụng, chưa deploy lại Functions, chưa kiểm UI trên trình duyệt/điện thoại thật. Vì vậy đây là source để triển khai và kiểm thử tiếp, chưa phải bản production đã nghiệm thu.

## F. Chuẩn bị Production sau khi DEV đạt kiểm thử

1. Tạo project Supabase Production **riêng**; ghi lại project ref, URL và publishable key Production. Trên project mới, dùng cùng thư mục `backend` để `link`, `migration list`, `db push --dry-run`, sau đó `db push` sau khi đối chiếu. Deploy ba Functions bằng lệnh phần C nhưng liên kết với **project Production**. Bootstrap Admin Production theo `backend/docs/BOOTSTRAP_FIRST_ADMIN.md` đúng một lần và tạo dữ liệu tổ chức cần thiết; không copy tài khoản hoặc dữ liệu thử từ DEV tùy tiện.
2. Trong Supabase Auth, cấu hình Site URL và redirect URLs theo domain hosting. Kiểm tra Storage bucket/policies và các luồng nghiệp vụ trên Production bằng tài khoản thử trước khi cấp tài khoản thật.
3. Trong `frontend`, tạo file `.env.production.local` (file này không có trong ZIP) với **giá trị Production**:

   ```env
   VITE_SUPABASE_URL=https://<production-ref>.supabase.co
   VITE_SUPABASE_PUBLISHABLE_KEY=sb_publishable_<production-key>
   VITE_FORCE_DEMO=false
   ```

   Hoặc đặt ba biến này trong cài đặt build của hosting. Chỉ dùng public URL/publishable key; không đưa secret/service role key vào biến `VITE_`.
4. Build và kiểm tra đầu ra trước khi upload:

   ```powershell
   npm.cmd ci
   npm.cmd run build
   npm.cmd run preview
   ```

   Mở `http://localhost:4173`; kiểm tra app đang kết nối **Production**. Sau đó xuất bản nội dung `frontend/dist` lên hosting HTTPS, bật fallback về `index.html` cho React Router. Cấu hình cache/PWA theo hosting, kiểm tra truy cập trực tiếp các route và đăng nhập trên domain thật. Không dùng `dist` tạo từ `--mode development` ở phần E để deploy Production.

## G. Các file nên đọc tiếp

- `DEV_RUNBOOK.md`: trạng thái backend DEV, cách kiểm tra và production gate.
- `RELEASE_STATUS.md`: các mục chưa được xác minh.
- `frontend/README.md`: cấu trúc và lệnh frontend.
- `backend/docs/TEST_CASES.md`: các tình huống nghiệp vụ/RLS.
- `backend/docs/BOOTSTRAP_FIRST_ADMIN.md`: chỉ dùng khi bootstrap project mới.
