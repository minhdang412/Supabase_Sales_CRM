-- Initial production-safe master data. Rename organization/department/team after deploy.
insert into public.organizations(id,name,timezone)
values ('00000000-0000-0000-0000-000000000001','Sales CRM','Asia/Ho_Chi_Minh')
on conflict (id) do nothing;

insert into public.departments(id,organization_id,name,code)
values ('00000000-0000-0000-0000-000000000010','00000000-0000-0000-0000-000000000001','Phòng Bán Hàng','SALES')
on conflict (id) do nothing;

insert into public.teams(id,organization_id,department_id,name)
values
('00000000-0000-0000-0000-000000000101','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000010','Nhóm 1'),
('00000000-0000-0000-0000-000000000102','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000010','Nhóm 2')
on conflict (id) do nothing;

insert into public.lead_sources(organization_id,code,name,category,sort_order,is_priority,response_sla_minutes) values
('00000000-0000-0000-0000-000000000001','facebook_ads','Facebook Ads','paid',10,true,15),
('00000000-0000-0000-0000-000000000001','website','Website','paid',20,true,15),
('00000000-0000-0000-0000-000000000001','car_marketplace','Sàn xe','paid',30,true,30),
('00000000-0000-0000-0000-000000000001','tiktok','TikTok','paid',40,true,30),
('00000000-0000-0000-0000-000000000001','zalo','Zalo','paid',50,true,30),
('00000000-0000-0000-0000-000000000001','google_ads','Google Ads','paid',60,true,15),
('00000000-0000-0000-0000-000000000001','company_data','Data công ty','company',70,true,60),
('00000000-0000-0000-0000-000000000001','event','Sự kiện','company',80,true,60),
('00000000-0000-0000-0000-000000000001','facebook_personal','Facebook cá nhân','organic',100,false,null),
('00000000-0000-0000-0000-000000000001','facebook_marketplace','Facebook Marketplace','organic',110,false,null),
('00000000-0000-0000-0000-000000000001','facebook_group','Group Facebook','organic',120,false,null),
('00000000-0000-0000-0000-000000000001','showroom','Khách đến showroom','offline',130,false,null),
('00000000-0000-0000-0000-000000000001','hotline','Hotline / Điện thoại vào','offline',140,false,null),
('00000000-0000-0000-0000-000000000001','referral','Khách giới thiệu','relationship',150,false,null),
('00000000-0000-0000-0000-000000000001','old_customer','Khách cũ','relationship',160,false,null),
('00000000-0000-0000-0000-000000000001','collaborator','CTV','relationship',170,false,null),
('00000000-0000-0000-0000-000000000001','internal_referral','Nội bộ giới thiệu','relationship',180,false,null),
('00000000-0000-0000-0000-000000000001','other','Khác','other',999,false,null)
on conflict (organization_id,code) do nothing;

insert into public.pipeline_stages(organization_id,code,display_name,sort_order) values
('00000000-0000-0000-0000-000000000001','new','Khách mới',10),
('00000000-0000-0000-0000-000000000001','contacted','Đã liên hệ',20),
('00000000-0000-0000-0000-000000000001','qualified','Đã xác định nhu cầu',30),
('00000000-0000-0000-0000-000000000001','quoted','Đã báo giá',40),
('00000000-0000-0000-0000-000000000001','appointment','Đã hẹn',50),
('00000000-0000-0000-0000-000000000001','test_drive','Đã lái thử',60),
('00000000-0000-0000-0000-000000000001','negotiation','Đang thương lượng',70),
('00000000-0000-0000-0000-000000000001','deposit','Đã đặt cọc',80)
on conflict (organization_id,code) do nothing;

insert into public.lost_reasons(organization_id,code,display_name,sort_order) values
('00000000-0000-0000-0000-000000000001','price','Giá chưa phù hợp',10),
('00000000-0000-0000-0000-000000000001','other_brand','Mua hãng khác',20),
('00000000-0000-0000-0000-000000000001','other_dealer','Mua đại lý khác',30),
('00000000-0000-0000-0000-000000000001','no_budget','Chưa đủ tài chính',40),
('00000000-0000-0000-0000-000000000001','finance_rejected','Không vay được',50),
('00000000-0000-0000-0000-000000000001','delayed','Hoãn mua',60),
('00000000-0000-0000-0000-000000000001','no_contact','Không liên hệ được',70),
('00000000-0000-0000-0000-000000000001','no_need','Không còn nhu cầu',80),
('00000000-0000-0000-0000-000000000001','junk','Lead rác / sai thông tin',90),
('00000000-0000-0000-0000-000000000001','other','Khác',999)
on conflict (organization_id,code) do nothing;

insert into public.task_types(organization_id,code,display_name,activity_type,sort_order) values
('00000000-0000-0000-0000-000000000001','call','Gọi khách','call',10),
('00000000-0000-0000-0000-000000000001','message','Nhắn khách','message',20),
('00000000-0000-0000-0000-000000000001','send_quote','Gửi báo giá','quote_sent',30),
('00000000-0000-0000-0000-000000000001','consult','Tư vấn','consultation',40),
('00000000-0000-0000-0000-000000000001','appointment','Hẹn gặp','appointment',50),
('00000000-0000-0000-0000-000000000001','test_drive','Lái thử','test_drive',60),
('00000000-0000-0000-0000-000000000001','prospecting','Tìm khách mới',null,70),
('00000000-0000-0000-0000-000000000001','post_content','Đăng bài',null,80),
('00000000-0000-0000-0000-000000000001','video','Quay video',null,90),
('00000000-0000-0000-0000-000000000001','finance','Tư vấn tài chính','consultation',100),
('00000000-0000-0000-0000-000000000001','documents','Thu hồ sơ','note',110),
('00000000-0000-0000-0000-000000000001','deposit','Nhận cọc','deposit',120),
('00000000-0000-0000-0000-000000000001','delivery_prepare','Chuẩn bị giao xe','note',130),
('00000000-0000-0000-0000-000000000001','after_sales','Chăm sóc sau bán','message',140),
('00000000-0000-0000-0000-000000000001','customer_followup','Chăm sóc lại khách','call',150),
('00000000-0000-0000-0000-000000000001','other','Khác','other',999)
on conflict (organization_id,code) do nothing;

insert into public.care_rules(organization_id,potential_level,max_inactive_hours) values
('00000000-0000-0000-0000-000000000001','hot',24),
('00000000-0000-0000-0000-000000000001','potential',72),
('00000000-0000-0000-0000-000000000001','watch',168)
on conflict (organization_id,potential_level) do nothing;

insert into public.products(organization_id,brand,name,code,sort_order) values
('00000000-0000-0000-0000-000000000001','MG','MG5','mg5',10),
('00000000-0000-0000-0000-000000000001','MG','MG7','mg7',20),
('00000000-0000-0000-0000-000000000001','MG','MG ZS','mg_zs',30),
('00000000-0000-0000-0000-000000000001','MG','MG HS','mg_hs',40),
('00000000-0000-0000-0000-000000000001','MG','MG RX5','mg_rx5',50),
('00000000-0000-0000-0000-000000000001','MG','MG4','mg4',60),
('00000000-0000-0000-0000-000000000001','MG','MG G50','mg_g50',70)
on conflict (organization_id,code) do nothing;
