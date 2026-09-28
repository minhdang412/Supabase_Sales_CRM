# Test cases bắt buộc trước production

1. Sales A tạo lead không SĐT -> thành công.
2. Sales A tạo chỉ Facebook/TikTok -> thành công.
3. Sales A và B nhập cùng SĐT -> cả hai thành công, không duplicate warning.
4. Sales A search cùng SĐT -> chỉ thấy record A.
5. Trưởng nhóm thấy khách trong nhóm nhưng không có Duplicate Report.
6. Trưởng phòng thấy toàn phòng và chạy Duplicate Report được.
7. Admin thấy toàn organization.
8. User locked khi đang có session -> RLS từ chối dữ liệu.
9. Task quá hạn được trả về trong Today Dashboard.
10. Complete task -> task completed + activity + last_activity update.
11. Complete task + follow-up -> next task tạo đúng.
12. Undo trong 10 phút -> task pending, activity voided, next task cancelled.
13. Quote #02 không overwrite #01.
14. Mark quote sent -> activity quote_sent và stage tối thiểu Quoted.
15. Transfer customer trong team bởi Trưởng nhóm -> thành công.
16. Trưởng nhóm transfer ra ngoài team -> bị chặn.
17. Trưởng phòng transfer giữa 2 team cùng phòng -> thành công.
18. Transfer giữ nguyên created_by của Activity/Quote/History nhưng owner scope đổi.
19. Báo giá trong hồ sơ khách không có luồng upload PDF; menu Báo giá hiển thị “Hoàn thiện sau”.
20. Lost bắt buộc lost_reason hợp lệ.
21. Pipeline đi tắt/đi ngược -> cho phép, history ghi nhận.
22. Master data code không đổi sau khi tạo.
23. Xóa trực tiếp customer qua client -> không có grant/policy.
24. `get_duplicate_customers` gọi bằng Sales hoặc locked user -> RPC từ chối.
25. Direct API không vượt qua RLS dù sửa frontend.
26. Locked user còn access token gọi `complete_task`, `add_activity`, `mark_quote_sent` -> RPC từ chối.
27. Admin của tổ chức A gọi RPC ghi trên customer/opportunity/task/quote của tổ chức B -> RPC từ chối.
28. Giao task gắn khách/cơ hội của người khác hoặc tổ chức khác -> từ chối.
29. Tài khoản đã tạo trong Auth chưa có organization được Admin gán role/phòng/nhóm; đăng nhập bằng mật khẩu hợp lệ sau khi gán.
30. Báo cáo ngày đầu/cuối khoảng theo múi giờ Việt Nam; kiểm tra bản ghi gần 00:00 và 23:59.
31. Danh sách khách có hơn 25 bản ghi tải tiếp; Task hơn 100 và Pipeline hơn 500 bản ghi không bị cắt âm thầm.
