# Mapping Frontend ↔ Supabase

| UI | Nguồn dữ liệu / RPC |
|---|---|
| Đăng nhập | Supabase Auth + `profiles` |
| Hôm nay | `get_today_dashboard(scope)` |
| Tạo khách | `create_lead(...)` |
| Tìm khách | `search_customers(...)` |
| Hồ sơ khách | RLS SELECT: customers + contacts + opportunities + activities + quotes + tasks |
| Hoàn thành task | `complete_task(...)` |
| Pipeline | `opportunities` + `pipeline_stages` |
| Công việc | `tasks` |
| Báo giá | `quotes` |
| Funnel | `get_funnel_report(...)` |
| Nguồn khách | `get_lead_source_report(...)` |
| Khách trùng | `get_duplicate_customers(...)` – Trưởng phòng/Admin |

## Quy tắc UI quan trọng
1. Không hiển thị field scope (`organization_id`, `department_id`, `team_id`, `owner_user_id`) cho Sales.
2. Không hiển thị chức năng khách trùng cho Sales/Trưởng nhóm.
3. Không kiểm tra/alert duplicate trong form tạo khách.
4. Chỉ Nguồn khách bắt buộc khi tạo lead.
5. Không hard-delete dữ liệu nghiệp vụ từ frontend.
