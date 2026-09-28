# Khắc phục trang đăng nhập localhost

Ảnh ngày 28/09 cho thấy React đã hiển thị nội dung nhưng **stylesheet không được áp dụng**: mọi thành phần dồn về góc trên trái, không có card hoặc nền slate. Ảnh được chụp trước khi bấm nút, nên không thể kết luận mật khẩu sai chỉ từ ảnh.

## 1. Chạy source mới trong thư mục sạch

Giải nén **bản ZIP mới nhất** vào một thư mục mới, không chép đè lên `frontend` cũ. Mở PowerShell tại thư mục `Supabase_Sales_CRM` trong ZIP rồi chạy:

```powershell
Set-Location .\frontend
node --version
npm.cmd ci
npm.cmd run dev
```

Yêu cầu Node 20.19+ hoặc 22.12+. Mở **đúng URL được Vite in ra trong PowerShell**, thường là `http://localhost:5173/login`. Nếu cổng 5173 bận, Vite có thể tự dùng cổng khác. Nhấn `Ctrl+Shift+R` để tải lại không dùng cache. Nếu trước đây đã cài PWA trên localhost, mở DevTools → Application → Service Workers → Unregister rồi tải lại.

`npm.cmd ci` phải hoàn tất không lỗi. Source này dùng `@tailwindcss/vite` trong `vite.config.ts`; `styles.css` phải được tải qua Vite. Không dùng `npm install` trong thư mục source cũ có `vite.config.js` sinh ra từ phiên bản khác.

## 2. Nếu trang vẫn không có định dạng

Mở DevTools bằng `F12` → **Network** → đánh dấu Disable cache → tải lại. Tìm `styles.css`:

- Nếu status không phải `200`, chụp mục **Response** và lỗi trong **Console**. Kiểm tra PowerShell chạy Vite có báo lỗi CSS/Tailwind không.
- Nếu `styles.css` là `200` nhưng trang vẫn trống định dạng, xác nhận đang mở URL của đúng tiến trình Vite và không bật chế độ chặn CSS trong trình duyệt.
- Nếu trình duyệt báo `ERR_CONNECTION_REFUSED`, tiến trình `npm.cmd run dev` đã dừng hoặc đang chạy ở cổng khác.

## 3. Nếu giao diện đẹp nhưng bấm Đăng nhập không vào

Source mới hiện thông báo lỗi tiếng Việt tại form. Đối chiếu:

| Thông báo | Cách xử lý |
| --- | --- |
| Email hoặc mật khẩu chưa đúng | Dùng tài khoản Auth của project DEV `tkylujqkrexpswlmgkrt`; kiểm tra email, xác nhận email, hoặc đặt lại mật khẩu trong Supabase Authentication → Users. |
| Tài khoản CRM chưa được kích hoạt/đang khóa | Auth có thể đã tồn tại nhưng profile chưa có tổ chức hoặc đang locked. Dùng Admin trong app → Tạo / gán tài khoản theo đúng email. |
| Không tải được hồ sơ CRM | Kiểm tra mạng, migration/RLS trên DEV và lỗi Network của truy vấn `profiles`. |
| Thiếu VITE_SUPABASE_URL/key | Xác nhận `frontend/.env.development` có URL/key DEV và `VITE_FORCE_DEMO=false`; dừng rồi chạy lại Vite sau khi sửa env. |

**Để xác định chính xác lỗi còn lại**, gửi ảnh sau khi bấm Đăng nhập, URL trên thanh địa chỉ và phần lỗi màu đỏ ở PowerShell/Console (che email hoặc token nếu muốn). Không gửi mật khẩu, access token hoặc Supabase secret key.
