# Sales CRM — trạng thái rà soát trước khi xuất

## Đã hoàn tất trong source

- Frontend có cấu hình Supabase DEV trong `.env.development`, không chứa secret key.
- Đã bỏ `.env` chứa DEV URL để bản build production không vô tình trỏ về DEV; production cần biến môi trường riêng.
- Build TypeScript/Vite PASS với cấu hình DEV; routes được chia tải theo trang, không còn cảnh báo bundle >500 KB.
- UI v1.1: bộ lọc khách, pipeline danh sách, Báo giá placeholder, báo giá trong hồ sơ không có PDF, Task mobile.
- Màn Công việc chỉ lấy task của người đăng nhập; Hôm nay ở phạm vi nhóm/phòng không cho hoàn thành việc của Sales khác.
- Hồ sơ khách ngoài quyền sở hữu ở chế độ xem; quản lý vẫn có luồng chuyển khách.
- Các form chính và màn dữ liệu hiển thị lỗi thay vì bỏ qua lỗi mạng/RPC.
- Báo giá retry tiếp tục cùng bản đã tạo; migration 016 ngăn tạo hoạt động quote_sent trùng.
- Migration 014 dùng định nghĩa RPC tĩnh và có thể chạy sau 013 đã apply.
- Migration 017 bổ sung kiểm tra active/scope trong RPC ghi, ngăn quyền Admin vượt tổ chức và chỉnh ngày báo cáo theo giờ Việt Nam.
- Customer có nút tải tiếp, Task/Pipeline tải đủ trang, tab Hôm nay không trộn việc tương lai. Admin gán được Auth user chưa có organization khi Functions mới được deploy.
- Giao diện được chuyển sang Tailwind CSS Light Mode với slate/emerald; shell, trang Hôm nay, Khách hàng, Quy trình, Báo cáo, Login và component chung đã đồng bộ icon, khoảng cách và trạng thái hover.
- Có `frontend/vercel.json` cho route SPA, màn `/set-password` và link mời nhân viên mới từ Edge Function về domain frontend; build production với cấu hình DEV đã PASS.

## Chưa được xác minh trên DEV

- Lịch sử migration 013–017 và kết quả `db push --dry-run`. Migration 017 chưa được chạy trên DEV.
- Login Admin trên localhost đã được người dùng xác nhận bằng ảnh ngày 28/09/2026; các role nghiệp vụ chưa được xác minh.
- RLS, duplicate, locked user, transfer, full workflow. Người dùng yêu cầu bỏ qua bài test RLS bằng tài khoản thử ở giai đoạn này.
- Ba Edge Functions quản trị bản mới chưa deploy.
- Kiểm tra trình duyệt/thiết bị mobile thật, môi trường hosting và Auth redirect.
- Email mời, thiết lập mật khẩu lần đầu và đăng nhập lại trên domain Vercel chưa được chạy end-to-end; cần cấu hình Supabase Auth Site URL/Redirect URLs.
- Ảnh đầu ngày 28/09 cho thấy stylesheet từng không được áp dụng. Ảnh sau đó xác nhận trang Login và Today đã có định dạng; Admin đã đăng nhập được. Luồng signIn trong source cũng đã được sửa để tải profile trực tiếp và hiển thị lỗi credentials rõ hơn.
- Production build thiếu `VITE_` hiện giữ trang Login và hiển thị lỗi cấu hình thay vì khởi tạo Supabase client bằng giá trị rỗng.

## Trạng thái phát hành

Source là ứng viên để triển khai tiếp trên DEV. Chưa xác nhận an toàn để cấp tài khoản production hoặc dùng dữ liệu khách thật. Khi sẵn sàng phát hành, xác minh các mục trên theo `DEV_RUNBOOK.md` và `backend/docs/TEST_CASES.md`.
