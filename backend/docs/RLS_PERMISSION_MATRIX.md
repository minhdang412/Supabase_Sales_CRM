# Ma trận phân quyền v1

| Chức năng | Sales | Trưởng nhóm | Trưởng phòng | Admin |
|---|---|---|---|---|
| Xem khách bản thân | Có | Có | Có | Có |
| Xem khách trong nhóm | Không | Có | Có | Có |
| Xem toàn phòng | Không | Không | Có | Có |
| Nhận diện khách trùng | Không | Không | Có | Có |
| Tạo khách cho bản thân | Có | Có | Có | Có |
| Sửa nội dung khách người khác | Không | Không | Không | Không qua UI |
| Giao task cho người khác | Không | Trong nhóm | Trong phòng | Toàn org |
| Chuyển khách | Không | Trong nhóm | Trong phòng | Toàn org |
| Báo cáo cá nhân | Có | Có | Có | Có |
| Báo cáo nhóm | Không | Có | Có | Có |
| Báo cáo phòng | Không | Không | Có | Có |
| Quản lý master data | Không | Không | Không | Có |
| Quản lý account | Không | Không | Không | Có |

## Khách trùng
- Không unique SĐT/email/social.
- Không cảnh báo Sales.
- Trưởng nhóm không có badge/menu Duplicate.
- Trưởng phòng/Admin dùng `get_duplicate_customers()`.
- Không có thao tác Merge.

## Write model
Quản lý chủ yếu đọc/điều phối; không sửa note, pipeline hay dữ liệu bán hàng của Sales. Chuyển khách thực hiện bằng RPC để có audit và cập nhật scope toàn lịch sử.
