# Supabase Sales CRM Frontend v1

Frontend React/PWA bằng tiếng Việt cho `Supabase Sales CRM v1`.

## Nguyên tắc UX đã khóa
- Mobile-first cho Sales; desktop tối ưu cho quản lý.
- Tạo khách nhanh: chỉ **Nguồn khách** bắt buộc.
- Không bắt buộc SĐT; contact có thể là Facebook/Messenger/TikTok/Zalo/email/SĐT.
- Khách trùng vẫn được tạo bình thường; Sales không nhận cảnh báo trùng.
- Priority chỉ **Cao / Bình thường**.
- Hành động thường xuyên dùng bottom sheet, smart defaults, ít field.
- Quản lý theo ngoại lệ: lead quá SLA, task quá hạn, khách nóng lâu chưa chăm.

## Stack
- React + TypeScript + Vite
- Tailwind CSS v4 với Vite plugin, giao diện Light Mode dùng slate/emerald
- React Router
- TanStack Query
- Supabase JS
- Lucide icons
- CSS responsive tự chứa
- Icon từ `lucide-react` với nét và kích thước đồng bộ
- PWA shell cơ bản

## Chạy Demo Mode
```bash
npm install
npm run dev
```
Nếu chưa cấu hình `.env`, dev server tự chạy Demo Mode. Production build thiếu cấu hình hiển thị lỗi kết nối. Thanh Demo cho phép đổi role Sales / Trưởng nhóm / Trưởng phòng / Admin.

## Kết nối Supabase
Bản DEV có sẵn URL + publishable key trong `.env.development`; chạy `npm run dev` sẽ kết nối DEV, không vào Demo.

Để đổi dự án DEV, tạo `.env.development.local` từ `.env.example`. Với production, cấu hình biến môi trường trong hosting hoặc `.env.production.local`; không dùng `.env` chứa DEV URL khi build production. Điền:
```env
VITE_SUPABASE_URL=https://<project>.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=<publishable-key>
VITE_FORCE_DEMO=false
```
Sau đó:
```bash
npm install
npm run dev
```

## Route chính
- `/login`
- `/set-password` – nhân viên mới đặt mật khẩu sau email mời
- `/today`
- `/customers`
- `/customers/:id`
- `/pipeline`
- `/tasks`
- `/quotes`
- `/reports`
- `/management` – Trưởng phòng/Admin và dashboard quản lý
- `/admin` – Admin

## Chức năng frontend đã nối backend
- Auth + role guard.
- Hôm nay + scope Cá nhân/Nhóm/Phòng.
- Quick Add khách qua `create_lead`.
- Customer search và hồ sơ khách.
- Thêm contact và cơ hội mới.
- Activity timeline + thêm tương tác.
- Tạo/hoàn thành/hủy công việc và follow-up.
- Lịch làm việc mẫu theo ngày.
- Chỉnh dữ liệu Opportunity an toàn.
- Đổi Pipeline qua RPC.
- Tạm hoãn / Thành công / Không thành công.
- Tạo báo giá, versioning, đánh dấu đã gửi.
- Pipeline desktop chọn giai đoạn + danh sách; mobile stage chips + grouped list.
- Funnel + báo cáo nguồn khách.
- Dashboard quản lý và khách trùng cho Trưởng phòng/Admin.
- Chuyển khách theo quyền.
- Admin: tạo/sửa/khóa account qua Edge Functions.
- Admin: gửi email mời cho account mới; link dẫn đến màn đặt mật khẩu nếu URL Auth đã được cho phép.
- Admin: gán Auth user đã tạo sẵn (profile locked, chưa có organization) bằng email khi Functions mới được deploy.
- Admin: cấu hình Nguồn khách, SLA, Pipeline, dòng xe/phiên bản, quy tắc chăm sóc.
- Notification center + realtime invalidation cho task/notification.
- PWA shell.

## Lưu ý kiểm thử
`npm install && npm run build` đã PASS trong lần kiểm tra source này. Xem `../DEV_RUNBOOK.md` để áp dụng migrations và chạy smoke test trên Supabase DEV.
