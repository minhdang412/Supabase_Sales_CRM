import type { CustomerDetail, CustomerListItem, FunnelRow, LeadSourceReportRow, PipelineGroup, Profile, StageItem, TodayDashboard, TaskItem, QuoteItem } from './types'

const now = new Date()
const iso = (mins: number) => new Date(now.getTime() + mins * 60000).toISOString()

export const demoProfiles: Record<string, Profile> = {
  sales: { id: 'demo-sales', full_name: 'Nguyễn Minh Đăng', role: 'sales', status: 'active', team_id: 'team-1', department_id: 'dept-1', organization_id: 'org-1' },
  team_leader: { id: 'demo-leader', full_name: 'Trưởng nhóm 1', role: 'team_leader', status: 'active', team_id: 'team-1', department_id: 'dept-1', organization_id: 'org-1' },
  sales_manager: { id: 'demo-manager', full_name: 'Trưởng phòng Kinh doanh', role: 'sales_manager', status: 'active', department_id: 'dept-1', organization_id: 'org-1' },
  admin: { id: 'demo-admin', full_name: 'Quản trị viên', role: 'admin', status: 'active', organization_id: 'org-1' }
}

export const stages: StageItem[] = [
  { id:'s1', code:'new', display_name:'Khách mới', sort_order:10 },
  { id:'s2', code:'contacted', display_name:'Đã liên hệ', sort_order:20 },
  { id:'s3', code:'qualified', display_name:'Đã xác định nhu cầu', sort_order:30 },
  { id:'s4', code:'quoted', display_name:'Đã báo giá', sort_order:40 },
  { id:'s5', code:'appointment', display_name:'Đã hẹn', sort_order:50 },
  { id:'s6', code:'test_drive', display_name:'Đã lái thử', sort_order:60 },
  { id:'s7', code:'negotiation', display_name:'Đang thương lượng', sort_order:70 },
  { id:'s8', code:'deposit', display_name:'Đã đặt cọc', sort_order:80 }
]

export const customers: CustomerListItem[] = [
  { customer_id:'c1', display_name:'Nguyễn Văn Nam', source_name:'Facebook Ads', source_id:'ls1', primary_contact:'0909 123 456', next_task_at:iso(240), last_activity_at:iso(-900), active_opportunity:{ id:'o1', product_id:'p1', variant_id:'v1', stage_id:'s7', status:'active', priority:'high', potential_level:'hot' } },
  { customer_id:'c2', display_name:'Minh Facebook', source_name:'Facebook Ads', source_id:'ls1', primary_contact:'Messenger: Minh Nguyễn', next_task_at:null, last_activity_at:null, active_opportunity:{ id:'o2', product_id:'p1', stage_id:'s1', status:'active', priority:'normal', potential_level:'potential' } },
  { customer_id:'c3', display_name:'Trần Tuấn', source_name:'Website', source_id:'ls2', primary_contact:'0912 555 222', next_task_at:null, last_activity_at:iso(-3000), active_opportunity:{ id:'o3', product_id:'p2', stage_id:'s4', status:'active', priority:'normal', potential_level:'potential' } },
  { customer_id:'c4', display_name:'Chị Lan', source_name:'Sàn xe', source_id:'ls3', primary_contact:'0988 444 111', next_task_at:iso(150), last_activity_at:iso(-200), active_opportunity:{ id:'o4', product_id:'p3', stage_id:'s5', status:'active', priority:'high', potential_level:'hot' } },
  { customer_id:'c5', display_name:'Hùng TikTok', source_name:'TikTok', source_id:'ls4', primary_contact:'@hungxe', next_task_at:null, last_activity_at:iso(-4300), active_opportunity:{ id:'o5', product_id:'p1', stage_id:'s2', status:'active', priority:'normal', potential_level:'watch' } }
]

const detailMap: Record<string, CustomerDetail> = {
  c1: {
    id:'c1', owner_user_id:'demo-sales', display_name:'Nguyễn Văn Nam', source_name:'Facebook Ads', created_at:iso(-10000), last_activity_at:iso(-900), note:'Khách quan tâm phương án vay và muốn chốt trong tháng.',
    contacts:[{id:'ct1',contact_type:'phone',raw_value:'0909 123 456',is_primary:true},{id:'ct2',contact_type:'facebook',raw_value:'facebook.com/nguyenvannam',is_primary:false}],
    opportunities:[{id:'o1',status:'active',priority:'high',potential_level:'hot',purchase_timeline:'within_month',payment_type:'loan',loan_ratio:70,budget_min:700000000,budget_max:750000000,competitor_note:'Toyota Camry',stage:stages[6],product:{id:'p1',name:'MG7'},variant:{id:'v1',name:'Luxury'}}],
    activities:[
      {id:'a1',activity_type:'quote_sent',result_code:'sent',note:'Gửi báo giá #03',occurred_at:iso(-900)},
      {id:'a2',activity_type:'call',result_code:'connected',note:'Khách hỏi phương án vay 70%',occurred_at:iso(-1200)},
      {id:'a3',activity_type:'message',result_code:'sent',note:'Nhắn Messenger xác nhận lịch',occurred_at:iso(-2600)},
      {id:'a4',activity_type:'lead_created',note:'Tạo khách từ Facebook Ads',occurred_at:iso(-10000)}
    ],
    tasks:[{id:'t1',title:'Gọi lại hỏi quyết định',due_at:iso(240),priority:'high',status:'pending',customer_id:'c1',opportunity_id:'o1'}],
    quotes:[
      {id:'q3',version:3,final_price:718000000,list_price:738000000,discount_amount:20000000,status:'sent',created_at:iso(-900),sent_at:iso(-900)},
      {id:'q2',version:2,final_price:725000000,list_price:738000000,discount_amount:13000000,status:'sent',created_at:iso(-3000),sent_at:iso(-3000)},
      {id:'q1',version:1,final_price:738000000,list_price:738000000,discount_amount:0,status:'expired',created_at:iso(-6000)}
    ]
  }
}

export const demoToday: TodayDashboard = {
  overview:{ overdue_tasks:3,today_tasks:9,new_leads_today:8,priority_unhandled:2 },
  overdue_tasks:[
    {id:'to1',title:'Gọi Anh Hoàng – MG RX5',due_at:iso(-150),priority:'high',customer_id:'c3'},
    {id:'to2',title:'Follow-up báo giá Chị Mai',due_at:iso(-80),priority:'normal',customer_id:'c4'}
  ],
  upcoming_tasks:[
    {id:'t1',title:'Gọi Anh Nam – MG7',due_at:iso(45),priority:'high',customer_id:'c1',opportunity_id:'o1'},
    {id:'t2',title:'Nhắn Minh Facebook',due_at:iso(90),priority:'normal',customer_id:'c2'},
    {id:'t3',title:'Khách Tuấn đến showroom',due_at:iso(150),priority:'normal',customer_id:'c3'},
    {id:'t4',title:'Lái thử MG7',due_at:iso(300),priority:'high',customer_id:'c4'}
  ],
  priority_new_leads:[
    {id:'c2',display_name:'Minh Facebook',created_at:iso(-8),source_name:'Facebook Ads',response_sla_minutes:15,age_minutes:8},
    {id:'c6',display_name:'Khách Website #A102',created_at:iso(-22),source_name:'Website',response_sla_minutes:15,age_minutes:22}
  ]
}

export const demoTasks: TaskItem[] = [...demoToday.overdue_tasks, ...demoToday.upcoming_tasks].map(t => ({...t,status:'pending'}))
export const demoQuotes: QuoteItem[] = detailMap.c1.quotes

export function getDemoCustomer(id:string):CustomerDetail {
  if (detailMap[id]) return detailMap[id]
  const c=customers.find(x=>x.customer_id===id) ?? customers[0]
  return {...detailMap.c1,id:c.customer_id,display_name:c.display_name,source_name:c.source_name,contacts:[{id:'x',contact_type:'other',raw_value:c.primary_contact ?? 'Chưa có liên hệ',is_primary:true}],quotes:[],activities:[],tasks:[],opportunities:[{...detailMap.c1.opportunities[0],id:c.active_opportunity?.id ?? 'o-demo',priority:c.active_opportunity?.priority ?? 'normal',potential_level:c.active_opportunity?.potential_level ?? 'watch',stage:stages.find(s=>s.id===c.active_opportunity?.stage_id) ?? stages[0]}]}
}

export const demoPipeline: PipelineGroup[] = stages.map(stage => ({
  stage,
  customers: customers.filter(c=>c.active_opportunity?.stage_id===stage.id).map(c=>({customer_id:c.customer_id,display_name:c.display_name,source_name:c.source_name,opportunity:{id:c.active_opportunity!.id,status:'active' as const,priority:c.active_opportunity!.priority ?? 'normal',potential_level:c.active_opportunity!.potential_level ?? 'watch',purchase_timeline:'unknown',payment_type:'unknown',stage}}))
})).filter(g=>g.customers.length)

export const demoFunnel: FunnelRow[] = [
  ['new','Khách mới',100],['contacted','Đã liên hệ',72],['qualified','Đã xác định nhu cầu',48],['quoted','Đã báo giá',31],['appointment','Đã hẹn',16],['test_drive','Đã lái thử',10],['deposit','Đã đặt cọc',5],['won','Thành công',4]
].map(([stage_code,stage_name,reached_count])=>({stage_code:String(stage_code),stage_name:String(stage_name),reached_count:Number(reached_count)}))

export const demoSources: LeadSourceReportRow[] = [
  {source_id:'ls1',source_name:'Facebook Ads',lead_count:80,responded_count:68,quoted_count:30,deposit_count:8,won_count:5,avg_response_minutes:12},
  {source_id:'ls2',source_name:'Website',lead_count:25,responded_count:23,quoted_count:14,deposit_count:5,won_count:4,avg_response_minutes:9},
  {source_id:'ls3',source_name:'Sàn xe',lead_count:42,responded_count:30,quoted_count:13,deposit_count:3,won_count:2,avg_response_minutes:28},
  {source_id:'ls4',source_name:'TikTok',lead_count:36,responded_count:18,quoted_count:5,deposit_count:1,won_count:1,avg_response_minutes:34}
]
