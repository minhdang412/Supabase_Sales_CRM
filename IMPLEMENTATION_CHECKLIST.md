# IMPLEMENTATION CHECKLIST — Sales CRM v1

## A. Supabase DEV
- [ ] Tạo project DEV.
- [ ] Link Supabase CLI.
- [ ] `supabase db push --dry-run` không có lỗi bất ngờ.
- [ ] `supabase db push` thành công.
- [ ] Bucket `quotes` private được giữ cho backend cũ; UI v1.1.2 không dùng PDF.
- [ ] Deploy 3 Edge Functions quản trị account.

## B. Bootstrap tổ chức
- [ ] Tạo Auth user Admin đầu tiên.
- [ ] Bootstrap organization + Admin profile.
- [ ] Tạo Phòng bán hàng.
- [ ] Tạo Nhóm 1, Nhóm 2.
- [ ] Kiểm tra seed nguồn khách/Pipeline/task types/care rules.
- [ ] Cập nhật danh mục xe thật.

## C. Account test
- [ ] 1 Sales nhóm 1.
- [ ] 1 Sales nhóm 2.
- [ ] 1 Trưởng nhóm.
- [ ] 1 Trưởng phòng.
- [ ] 1 Admin.
- [ ] Lock/unlock hoạt động.
- [ ] Đổi role/team bị validate đúng.

## D. RLS quan trọng
- [ ] Sales chỉ SELECT record own scope.
- [ ] Sales không UPDATE owner/team/department/stage/status trực tiếp.
- [ ] Trưởng nhóm đọc được team nhưng không Duplicate Report.
- [ ] Trưởng phòng đọc department + Duplicate Report.
- [ ] Admin quản trị master data.
- [ ] User locked bị chặn dù session còn tồn tại.

## E. Duplicate business rule
- [ ] Sales A tạo `0909123456` thành công.
- [ ] Sales B tạo `0909123456` thành công.
- [ ] Không có duplicate warning cho A/B.
- [ ] Sales A search chỉ thấy record A.
- [ ] Sales B search chỉ thấy record B.
- [ ] Trưởng phòng thấy cả hai trong Khách trùng.
- [ ] Không có chức năng merge bắt buộc.

## F. Core Sales flow
- [ ] Quick Add chỉ bắt buộc Nguồn khách.
- [ ] Contact không bắt buộc.
- [ ] Thêm contact sau được.
- [ ] Tạo Opportunity sau được.
- [ ] Thêm Activity.
- [ ] Tạo Task.
- [ ] Complete Task sinh Activity + optional follow-up.
- [ ] Đổi Pipeline.
- [ ] Tạm hoãn sinh future task.
- [ ] Won/Lost hoạt động.
- [ ] Lost bắt buộc reason.

## G. Quote/Storage
- [ ] Quote version tăng đúng.
- [ ] Quote không overwrite version cũ.
- [ ] UI báo giá trong hồ sơ tạo nhiều phiên bản, không có PDF.
- [ ] RPC đánh dấu đã gửi không tạo hoạt động trùng khi thử lại.

## H. Manager/Admin UX
- [ ] Dashboard ngoại lệ hiển thị đúng.
- [ ] Transfer customer đúng scope.
- [ ] Admin create/edit/lock user.
- [ ] Admin sửa nguồn khách/SLA.
- [ ] Admin sửa Pipeline display/order/active.
- [ ] Admin quản lý dòng xe/phiên bản.
- [ ] Admin sửa Lead Aging.

## I. Frontend quality
- [ ] `npm install` thành công.
- [ ] `npm run build` thành công.
- [ ] Test Chrome desktop.
- [ ] Test Edge desktop.
- [ ] Test Chrome Android hoặc responsive mobile.
- [ ] Test Safari iPhone nếu đội dùng iOS.
- [ ] Install PWA/Add to Home Screen.
- [ ] Loading/error/empty states dễ hiểu.
- [ ] Form mobile không bị bàn phím che nút chính.

## J. Production gate
- [ ] Không có service-role key trong frontend/build.
- [ ] DEV test pass đủ 4 roles.
- [ ] Backup/restore strategy được xác nhận.
- [ ] Dữ liệu seed production được rà lại.
- [ ] Tạo project Production riêng.
- [ ] Push migrations từ source control.
- [ ] Smoke test Production trước khi cấp account toàn đội.
