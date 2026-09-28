# Sales CRM — bắt đầu từ đây

Đọc **`HUONG_DAN_DEPLOY_VERCEL.md`** để deploy frontend trực tiếp lên Vercel. `HUONG_DAN_CAI_DAT_CHI_TIET.md` dành cho cách chạy trên Windows, cập nhật Supabase DEV và chuẩn bị Production.

## Bản source

- `frontend/`: React functional components, TypeScript, Vite, Tailwind CSS, Lucide React và PWA. `.env.development` đã chứa URL/publishable key của Supabase DEV.
- `backend/`: migrations 001–017, RLS, RPC, seed, Edge Functions và tài liệu nghiệp vụ.
- `DEV_RUNBOOK.md`: tình trạng triển khai DEV và những bước còn cần thực hiện.
- `RELEASE_STATUS.md`: phạm vi đã làm và chưa xác minh.

Giao diện v1.1 đã có bộ lọc Khách hàng, Pipeline dạng danh sách, bố cục Công việc trên mobile và các màn được chỉnh theo Light Mode slate/emerald. Menu Báo giá hiển thị “Hoàn thiện sau”; báo giá trong hồ sơ khách không xuất PDF.

## Chạy frontend trên DEV

```powershell
Set-Location .\frontend
npm.cmd ci
npm.cmd run dev
```

Mở `http://localhost:5173` và đăng nhập Admin DEV. Không bootstrap Admin hoặc seed lại trên DEV. Trước khi đẩy backend, chạy `supabase migration list` và `supabase db push --dry-run` theo hướng dẫn chi tiết để xác định migration còn thiếu.

**Trạng thái:** source đã build được. DEV RLS/Auth bằng tài khoản hợp lệ, migration 017, Edge Functions mới và giao diện trên thiết bị thật chưa được nghiệm thu; không coi ZIP này là bản Production đã triển khai.
