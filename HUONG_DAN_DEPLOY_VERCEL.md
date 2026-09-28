# Deploy Sales CRM lên Vercel, kết nối Supabase DEV

**Không bắt buộc chạy app ở máy local.** Vercel có thể cài dependencies và build trực tiếp từ Git repository. Vercel chỉ phục vụ frontend; migrations, RLS, RPC và Edge Functions phải được áp dụng ở Supabase DEV riêng. Trước khi cho nhân viên dùng dữ liệu thật, vẫn cần kiểm tra đăng nhập và phân quyền trên site đã deploy.

## 1. Chuẩn bị Supabase DEV

Giữ project DEV `tkylujqkrexpswlmgkrt` hiện có. Admin đã đăng nhập thành công ở localhost; **không bootstrap Admin hay seed lại**. Thư mục `backend/supabase/config.toml` đã có để CLI nhận diện source. Mở PowerShell tại thư mục `backend` đã giải nén:

```powershell
npx.cmd supabase login
npx.cmd supabase link --project-ref tkylujqkrexpswlmgkrt
npx.cmd supabase migration list
npx.cmd supabase db push --dry-run
```

Nếu dry-run đề nghị chạy lại 001–012, hoặc RPC 013 đã tồn tại nhưng lịch sử 013 chưa khớp, **dừng và đối chiếu migration history** trong Supabase Dashboard theo `DEV_RUNBOOK.md`; không chạy `SUPABASE_CRM_V1_FULL.sql`, không tự repair lịch sử khi chưa đối chiếu schema. Khi danh sách migration còn thiếu đã đúng, chạy:

```powershell
npx.cmd supabase db push
npx.cmd supabase functions deploy admin-create-user
npx.cmd supabase functions deploy admin-update-user
npx.cmd supabase functions deploy admin-lock-user
```

Giữ JWT verification mặc định. Không đưa secret key vào frontend. Các lệnh backend thao tác trực tiếp Supabase DEV từ máy của bạn; **không cần chạy frontend local**. Hiện workspace chưa xác minh migration history hoặc deploy Functions thực tế.

## 2. Đưa source lên Git repository riêng tư

Upload thư mục source sau khi giải nén lên GitHub/GitLab/Bitbucket repository riêng tư. Repo root có `backend/` và `frontend/`. Không đưa `node_modules`, `dist`, mật khẩu hoặc Supabase secret/service role key vào Git. `.env.development` trong gói chỉ chứa URL và publishable key DEV, nhưng `.gitignore` không đưa file này lên Git; Vercel dùng các biến ở bước 4.

## 3. Tạo Vercel project

Trong Vercel → Add New → Project → Import repository. Chọn:

| Mục | Giá trị |
| --- | --- |
| Root Directory | `frontend` |
| Framework Preset | `Vite` |
| Build Command | `npm run build` |
| Output Directory | `dist` |
| Node.js Version | 22.x hoặc bản đáp ứng Vite 8 (`20.19+` / `22.12+`) |

`frontend/vercel.json` đã có rewrite để mở trực tiếp `/login`, `/admin`, `/set-password` không bị 404. Vercel sẽ build source; không cần upload thư mục `dist` từ máy local. **Chưa bấm Deploy** cho tới khi đã nhập ba biến ở bước 4; màn cấu hình cho phép nhập trước khi deploy lần đầu.

Nếu không dùng Git, có thể mở PowerShell ngay trong thư mục `frontend`, chạy `npx.cmd vercel login` rồi `npx.cmd vercel link` để tạo/liên kết project, thêm ba biến trong Vercel Dashboard, sau đó chạy `npx.cmd vercel --prod`. Đây cũng là deploy source trực tiếp lên Vercel; không cần `npm run dev`. Lần deploy đầu có thể là Production deployment ngay cả khi không chỉ định `--prod`, nên đặt biến đúng trước khi deploy.

## 4. Đặt Environment Variables tại Vercel

Trong màn Import hoặc Project Settings → Environment Variables, thêm ba biến dưới đây cho môi trường Vercel sẽ dùng để thử DEV (nếu bấm Deploy từ project mặc định, chọn **Production**):

```env
VITE_SUPABASE_URL=https://tkylujqkrexpswlmgkrt.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=sb_publishable_vgQcOVKW57Av9qXxU3OQbg_cnNMX4rP
VITE_FORCE_DEMO=false
```

Không điền Supabase secret/service role key. **Vite nhúng các biến `VITE_` vào frontend lúc build**; sau khi sửa biến, Redeploy để tạo bản build mới. Nếu dùng Vercel Production environment để thử DEV, site vẫn kết nối **Supabase DEV**, không phải Supabase Production. Khi tạo project Supabase Production, thay URL/key bằng của Production và redeploy cho đúng môi trường.

## 5. Cấu hình URL Auth để nhân viên nhận lời mời

Sau lần deploy đầu, ghi lại URL cố định, ví dụ `https://sales-crm-cua-ban.vercel.app`. Trong Supabase DEV → Authentication → URL Configuration:

1. Đặt **Site URL** là URL site cố định này.
2. Thêm Redirect URL chính xác `https://sales-crm-cua-ban.vercel.app/set-password` (và URL preview nếu thực sự dùng preview để gửi thư mời). Nếu vẫn thử local, thêm `http://localhost:5173/set-password`.
3. Kiểm tra cấu hình email và khả năng gửi thư mời của Supabase; môi trường Production cần cấu hình SMTP phù hợp.

Edge Function tạo nhân viên mới sẽ gửi email mời với đích `/set-password`. Người nhận mở link, đặt mật khẩu ít nhất 12 ký tự, rồi vào CRM. Nếu email Auth đã có từ trước, nút “Tạo / gán tài khoản” chỉ gán role/phòng/nhóm và **không gửi email mời mới, không đổi mật khẩu**; dùng quy trình đặt lại mật khẩu cho tài khoản đó khi cần. Nếu Redirect URL không được Supabase cho phép, thư mời có thể chuyển về Site URL thay vì màn đặt mật khẩu.

## 6. Kiểm tra trên chính URL Vercel

1. Mở `/login`, đăng nhập Admin DEV. Thanh Demo không được xuất hiện.
2. Mở `/admin` bằng Admin và kiểm tra nút **Tạo tài khoản**: email, họ tên, vai trò, phòng, nhóm. Sales/Trưởng nhóm cần phòng và nhóm; Trưởng phòng cần phòng; Admin không chọn phòng/nhóm.
3. Tạo **một tài khoản thử mới**. Kiểm tra email mời → `/set-password` → đặt mật khẩu → đăng xuất → đăng nhập lại bằng email/mật khẩu. Chỉ sau đó cấp các tài khoản khác.
4. Kiểm tra trực tiếp URL `/customers` hoặc `/admin` sau khi F5; nếu bị 404, xác nhận `frontend/vercel.json` nằm tại root directory của Vercel project.
5. Kiểm RLS bằng các role khác nhau theo `backend/docs/TEST_CASES.md` trước khi dùng dữ liệu khách thật. Build/deploy thành công chưa xác nhận backend hoặc RLS hoạt động.

**Trạng thái:** Admin đã đăng nhập được trên localhost. Build source không xác minh RLS, email mời, hay Functions đang chạy. Repository và Vercel account chưa được kết nối trong workspace này; chưa có URL deploy thực tế. Sau khi làm xong, giữ nguyên URL Vercel để kiểm tra các vai trò trước khi chuyển sang Supabase Production.
