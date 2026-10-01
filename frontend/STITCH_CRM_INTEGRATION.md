# Tích hợp 17 màn Stitch vào Sales CRM

Bản này dựa trên 17 ZIP Stitch đã cung cấp ngày 01/10/2026. Nội dung ZIP là HTML tĩnh, ảnh mẫu và DESIGN.md; dữ liệu trong ảnh (showroom Hà Nội, nhân viên, giá xe, số điện thoại) là minh họa, không được chép vào CRM thật.

## Đã tích hợp vào frontend React hiện tại

- Thiết kế chung: canvas slate sáng, card trắng viền mảnh, màu emerald chủ đạo, cảnh báo quá hạn rose, badge Nóng rose theo yêu cầu người dùng, các cấp badge khác phân biệt rõ; khoảng cách và điều hướng mobile.
- Danh sách khách: bố cục thẻ theo mẫu Stitch, viền ưu tiên/cần chăm, nguồn, mức nóng, xe quan tâm nếu API trả product_id, lần chăm và việc tiếp theo. Giữ nguyên tìm kiếm, lọc, phân trang và mở hồ sơ.
- Phễu bán hàng: danh sách theo giai đoạn, card khách gọn, trạng thái, mức tiềm năng và điều hướng hồ sơ; giữ API getPipeline.
- Hôm nay: khối ưu tiên từ dashboard thật, KPI và việc quá hạn; CTA dẫn tới Công việc.
- Đăng nhập: nhận diện xe và thẻ đăng nhập theo ngôn ngữ Stitch; giữ Supabase Auth.
- Card, sheet, task, trang chi tiết, báo cáo, quản trị và thông báo dùng token CSS chung. Logic tạo/sửa/chuyển khách/hoàn thành việc/RLS vẫn theo code hiện tại.

## Chưa thể đưa thành chức năng thật chỉ từ HTML mẫu

- Bộ lọc Stitch có thêm ngân sách, xe, người phụ trách, SLA, khoảng ngày; API search_customers_filtered hiện chỉ hỗ trợ từ khóa, quick filter, nguồn, giai đoạn. Các bộ lọc mới cần thiết kế API/RPC và kiểm tra RLS.
- Các nút gọi Zalo, thông tin biến thể/màu xe, báo giá mẫu, tự động hóa và KPI trình bày trong HTML Stitch chưa có dữ liệu/cơ chế tương ứng. Không tạo nút hoặc số liệu giả trên app.
- Màn điều chuyển khách, hoàn thành công việc và thông báo dùng form cùng API đang có, không sao chép danh sách mock của Stitch.

## Cập nhật Vercel

1. Giải nén ZIP frontend được gửi kèm.
2. Chép **nội dung bên trong** vào đúng root repository frontend đang nối Vercel (`package.json`, `src`, `public`, `vercel.json` ở root). Không chép `node_modules`, `dist`, hoặc file `.env`.
3. Commit và Push lên GitHub; Vercel sẽ build và redeploy theo repository đã kết nối. Giữ nguyên Vercel Environment Variables hiện có.
4. Mở Vercel trên điện thoại, kiểm tra Khách hàng, Hôm nay, Phễu bán hàng, Công việc, Chi tiết khách, đăng nhập và các quyền role. Với PWA, tải lại hẳn trang nếu còn cache giao diện cũ.

## Xác minh

`npm run build` (TypeScript + Vite) chạy thành công. Chưa kiểm thử trực tiếp với phiên Admin trên Vercel hoặc tài khoản Sales; không kết luận RLS từ bước build.
