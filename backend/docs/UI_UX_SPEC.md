# UI/UX v1 - Sales CRM

## Nguyên tắc
- Mobile-first cho Sales; desktop mạnh cho quản lý.
- Tiếng Việt trên toàn giao diện.
- Một màn hình = một mục tiêu chính.
- Không ép nhập dữ liệu chưa biết.
- Form tạo khách chỉ bắt buộc `Nguồn khách`.
- Dùng Bottom Sheet trên mobile cho kết quả cuộc gọi, filter, chọn stage, follow-up.
- Không dùng bảng trên mobile; card/list thay thế.
- Không tô quá nhiều màu; màu chỉ cho trạng thái/exception.
- `Priority`: chỉ `Cao / Bình thường`, mặc định Bình thường.

## Mobile navigation
`Hôm nay | Khách hàng | Quy trình | Công việc | Thêm`

### Thêm
- Khách mới
- Công việc
- Tương tác
- Báo giá

## Hôm nay
Thứ tự ưu tiên:
1. Việc quá hạn
2. Lead mới nguồn ưu tiên
3. Công việc ưu tiên Cao
4. Lịch hẹn gần nhất
5. Công việc còn lại

Chỉ hiện 5–8 việc đầu, có `Xem tất cả`.

## Thêm khách
- Nguồn khách *
- Tên
- Liên hệ
- Xe
- Ghi chú
- `Lưu khách`

Không hỏi ngân sách, priority, tiềm năng, thanh toán ở bước này.

## Hồ sơ khách
Tabs: `Tổng quan | Lịch sử | Báo giá`

Tổng quan ưu tiên:
- Tên + contact actions
- Cơ hội đang mở
- Stage / Tiềm năng / Priority
- Việc tiếp theo
- Dự kiến mua / Thanh toán / Ngân sách / Đối thủ
- Field chưa có hiển thị dạng `+ Thêm ...`

## Complete Task
Bottom sheet:
- Kết quả
- Ghi chú
- Việc tiếp theo: Ngày mai / 2 ngày / 7 ngày / Chọn ngày / Chưa cần
- `Hoàn thành`

Sau khi lưu hiện `Hoàn tác` trong tối đa 10 phút.

## Pipeline
- Desktop: Kanban.
- Mobile: grouped list theo stage, không drag ngang nhiều cột.

## Quản lý
Dashboard ưu tiên exception:
- Lead ưu tiên quá SLA
- Task quá hạn
- Khách nóng lâu chưa chăm
- Báo giá chưa follow-up

Sau đó mới hiển thị KPI tổng hợp.

## Khách trùng
Chỉ Trưởng phòng/Admin. Trình bày trung tính, không màu cảnh báo, không có nút Merge.
