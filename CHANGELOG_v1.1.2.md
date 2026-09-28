# Sales CRM v1.1.2 — DEV continuation

- Sửa RPC tìm tên khách có dấu; migration 014 là định nghĩa tĩnh có thể chạy sau 013.
- Migration 015 chặn notification của tài khoản locked; migration 016 làm `mark_quote_sent` idempotent khi retry.
- Kết nối frontend tới Supabase DEV bằng URL + publishable key trong `.env.development`.
- Màn Công việc chỉ lấy task được giao cho user hiện tại; dashboard nhóm/phòng không hiện nút hoàn thành task của Sales khác.
- Hồ sơ khách do Sales khác phụ trách hiển thị chế độ xem; quản lý giữ quyền chuyển khách. Đã sửa nút Nhắn thành liên kết SMS khi có số điện thoại.
- Các form công việc, tương tác, liên hệ, cơ hội, báo giá, chuyển khách và lịch làm việc hiển thị lỗi ghi dữ liệu.
- Form báo giá thử lại trên cùng version đã tạo; RPC chống hoạt động `quote_sent` trùng.
- Login giải thích rõ profile chưa kích hoạt hoặc bị khóa; màn dữ liệu hiển thị lỗi tải.
- Chia bundle theo trang; build TypeScript/Vite PASS với cấu hình DEV.
- RLS test bằng test accounts được người dùng bỏ qua tại giai đoạn này. Không có xác nhận production.
