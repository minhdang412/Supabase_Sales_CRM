# Sau MVP v1 – các nâng cấp tùy chọn

Core workflow của v1 đã được nối frontend ↔ Supabase. Các mục dưới đây là V1.1/V2, không phải blocker cho MVP:

1. Notification push/web push thay vì chỉ Notification Center trong app.
2. Dashboard Target/KPI chi tiết theo ngày/tuần/tháng.
3. CRUD UI cho Lost Reasons và Task Types (v1 đã có seed/database; ít thay đổi nên có thể quản lý bằng migration).
4. Kéo-thả sort_order trực quan thay vì nhập số trong Admin.
5. Bộ lọc nâng cao/saved filters cho quản lý.
6. Full offline queue nếu thực sự cần làm việc không có Internet.
7. E2E automation bằng Playwright/Cypress.
8. pgTAP coverage đầy đủ cho RLS/RPC.
9. Integration email/Zalo/Messenger nếu sau này có API chính thức phù hợp.
10. AI hỗ trợ gợi ý follow-up/nội dung – chỉ sau khi dữ liệu v1 đủ sạch.
