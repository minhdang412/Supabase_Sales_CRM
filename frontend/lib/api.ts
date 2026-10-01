import { isDemoMode } from './config'
import { supabase } from './supabase'
import { customers as demoCustomers, demoFunnel, demoPipeline, demoQuotes, demoSources, demoTasks, demoToday, getDemoCustomer } from './demo'
import type { CustomerDetail, CustomerListItem, FunnelRow, LeadSourceReportRow, MasterItem, PipelineGroup, ProductItem, StageItem, TaskItem, TaskTypeItem, TodayDashboard } from './types'

const wait = (ms=220) => new Promise(r => setTimeout(r, ms))
const sb = () => { if (!supabase) throw new Error('Supabase chưa được cấu hình'); return supabase }

export async function getToday(scope='self'): Promise<TodayDashboard> {
  if (isDemoMode) { await wait(); return demoToday }
  const { data, error } = await sb().rpc('get_today_dashboard', { p_scope: scope })
  if (error) throw error
  return data as TodayDashboard
}

export interface TodayCustomerPreview {
  id: string
  display_name: string
  note?: string | null
  phone?: string | null
  vehicle?: string | null
}

export async function getTodayCustomerPreviews(ids: string[]): Promise<Record<string, TodayCustomerPreview>> {
  if (!ids.length) return {}
  if (isDemoMode) {
    const previews:Record<string,TodayCustomerPreview>={}
    ids.forEach(id => {
      const customer = demoCustomers.find(c => c.customer_id === id)
      if (!customer) return
      const detail = id === 'c1' ? getDemoCustomer(id) : null
      const opportunity = detail?.opportunities[0]
      previews[id] = {
        id,
        display_name: customer.display_name,
        note: detail?.note ?? null,
        phone: detail?.contacts.find(c => c.contact_type === 'phone')?.raw_value ?? customer.primary_contact ?? null,
        vehicle: [opportunity?.product?.name, opportunity?.variant?.name].filter(Boolean).join(' ') || null,
      }
    })
    return previews
  }
  const {data, error} = await sb().from('customers').select(`
    id, display_name, note,
    customer_contacts(contact_type,raw_value,is_primary),
    opportunities(products(name),product_variants(name))
  `).in('id', ids)
  if (error) throw error
  return Object.fromEntries((data ?? []).map((row:any) => {
    const phone = row.customer_contacts?.find((c:any) => c.contact_type === 'phone' && c.is_primary)
      ?? row.customer_contacts?.find((c:any) => c.contact_type === 'phone')
    const opportunity = row.opportunities?.[0]
    return [row.id, {
      id:row.id, display_name:row.display_name, note:row.note,
      phone:phone?.raw_value ?? null,
      vehicle:[opportunity?.products?.name, opportunity?.product_variants?.name].filter(Boolean).join(' ') || null,
    }]
  }))
}

export async function searchCustomers(query='', options?:{quickFilter?:'all'|'hot'|'high'|'no_next'|'stale';sourceId?:string;stageId?:string;limit?:number;offset?:number}): Promise<CustomerListItem[]> {
  const limit=options?.limit ?? 25
  const offset=options?.offset ?? 0
  const quickFilter=options?.quickFilter ?? 'all'
  if (isDemoMode) {
    await wait()
    const q=query.toLowerCase().trim()
    const staleBefore=Date.now()-3*24*60*60*1000
    return demoCustomers.filter(c=>{
      const matchesQuery=!q || [c.display_name,c.source_name,c.primary_contact].some(x=>String(x??'').toLowerCase().includes(q))
      const matchesSource=!options?.sourceId || c.source_id===options.sourceId
      const matchesStage=!options?.stageId || c.active_opportunity?.stage_id===options.stageId
      const matchesQuick=quickFilter==='all'
        || (quickFilter==='hot' && c.active_opportunity?.potential_level==='hot')
        || (quickFilter==='high' && c.active_opportunity?.priority==='high')
        || (quickFilter==='no_next' && !c.next_task_at)
        || (quickFilter==='stale' && (!c.last_activity_at || Date.parse(c.last_activity_at)<staleBefore))
      return matchesQuery && matchesSource && matchesStage && matchesQuick
    }).slice(offset,offset+limit)
  }
  const { data, error } = await sb().rpc('search_customers_filtered', {
    p_query: query || null,
    p_quick_filter: quickFilter,
    p_source_id: options?.sourceId || null,
    p_stage_id: options?.stageId || null,
    p_limit: limit,
    p_offset: offset
  })
  if (error) throw error
  return (data ?? []) as CustomerListItem[]
}

export async function getCustomerDetail(id:string): Promise<CustomerDetail> {
  if (isDemoMode) { await wait(); return getDemoCustomer(id) }
  const { data: c, error } = await sb().from('customers').select(`
    id, owner_user_id, display_name, note, created_at, last_activity_at,
    lead_sources(name),
    customer_contacts(id,contact_type,raw_value,is_primary),
    opportunities(id,status,priority,potential_level,purchase_timeline,payment_type,loan_ratio,budget_min,budget_max,competitor_note,
      pipeline_stages(id,code,display_name,sort_order), products(id,name), product_variants(id,name)),
    activities(id,activity_type,result_code,note,occurred_at,is_voided),
    quotes(id,version,final_price,list_price,discount_amount,promotion_note,storage_path,status,created_at,sent_at),
    tasks(id,title,due_at,priority,status,note,opportunity_id)
  `).eq('id',id).single()
  if (error) throw error
  const raw:any=c
  return {
    id: raw.id, owner_user_id: raw.owner_user_id, display_name: raw.display_name, source_name: raw.lead_sources?.name ?? 'Không rõ nguồn', note: raw.note, created_at: raw.created_at, last_activity_at: raw.last_activity_at,
    contacts: raw.customer_contacts ?? [],
    opportunities: (raw.opportunities ?? []).map((o:any)=>({...o,stage:o.pipeline_stages,product:o.products,variant:o.product_variants})),
    activities: (raw.activities ?? []).filter((a:any)=>!a.is_voided).sort((a:any,b:any)=>Date.parse(b.occurred_at)-Date.parse(a.occurred_at)),
    quotes: (raw.quotes ?? []).sort((a:any,b:any)=>b.version-a.version),
    tasks: (raw.tasks ?? []).sort((a:any,b:any)=>Date.parse(a.due_at)-Date.parse(b.due_at))
  }
}

export async function getMasterData(): Promise<{sources:MasterItem[];products:ProductItem[];stages:StageItem[];taskTypes:TaskTypeItem[]}> {
  if (isDemoMode) {
    return {
      sources:[{id:'ls1',name:'Facebook Ads'},{id:'ls2',name:'Website'},{id:'ls3',name:'Sàn xe'},{id:'ls4',name:'TikTok'},{id:'ls5',name:'Zalo'},{id:'ls6',name:'Facebook Marketplace'}],
      products:[{id:'p1',name:'MG7',code:'MG7'},{id:'p2',name:'MG5',code:'MG5'},{id:'p3',name:'MG ZS',code:'MGZS'},{id:'p4',name:'MG RX5',code:'MGRX5'}],
      stages:[{id:'s1',code:'new',display_name:'Khách mới',sort_order:10},{id:'s2',code:'contacted',display_name:'Đã liên hệ',sort_order:20},{id:'s3',code:'qualified',display_name:'Đã xác định nhu cầu',sort_order:30},{id:'s4',code:'quoted',display_name:'Đã báo giá',sort_order:40},{id:'s5',code:'appointment',display_name:'Đã hẹn',sort_order:50},{id:'s6',code:'test_drive',display_name:'Đã lái thử',sort_order:60},{id:'s7',code:'negotiation',display_name:'Đang thương lượng',sort_order:70},{id:'s8',code:'deposit',display_name:'Đã đặt cọc',sort_order:80}],
      taskTypes:[{id:'tt1',code:'call',display_name:'Gọi khách'},{id:'tt2',code:'message',display_name:'Nhắn khách'},{id:'tt3',code:'appointment',display_name:'Hẹn gặp'},{id:'tt4',code:'test_drive',display_name:'Lái thử'}]
    }
  }
  const [s,p,st,tt] = await Promise.all([
    sb().from('lead_sources').select('id,name,code,sort_order').eq('is_active',true).order('sort_order'),
    sb().from('products').select('id,name,code').eq('is_active',true).order('sort_order'),
    sb().from('pipeline_stages').select('id,code,display_name,sort_order').eq('is_active',true).order('sort_order'),
    sb().from('task_types').select('id,code,display_name').eq('is_active',true).order('sort_order')
  ])
  for (const r of [s,p,st,tt]) if (r.error) throw r.error
  return { sources:s.data ?? [], products:p.data ?? [], stages:st.data ?? [], taskTypes:tt.data ?? [] } as any
}

export async function createLead(input:{sourceId:string;displayName?:string;contact?:string;productId?:string;note?:string}) {
  if (isDemoMode) { await wait(450); return { customer_id:'demo-new', opportunity_id:'demo-opportunity' } }
  const { data,error }=await sb().rpc('create_lead',{p_source_id:input.sourceId,p_display_name:input.displayName||null,p_contact_raw:input.contact||null,p_contact_type:null,p_product_id:input.productId||null,p_variant_id:null,p_note:input.note||null})
  if(error) throw error
  return data?.[0]
}

export async function completeTask(taskId:string, input:{result?:string;note?:string;nextDueAt?:string|null}) {
  if (isDemoMode) { await wait(350); return {task_id:taskId,activity_id:'demo-act',next_task_id:input.nextDueAt?'demo-next':null} }
  const {data,error}=await sb().rpc('complete_task',{p_task_id:taskId,p_result_code:input.result||null,p_note:input.note||null,p_next_due_at:input.nextDueAt||null,p_next_task_type_id:null,p_next_note:null})
  if(error) throw error
  return data
}

export async function getTasks(): Promise<TaskItem[]> {
  if(isDemoMode){await wait();return demoTasks}
  const {data:{user},error:authError}=await sb().auth.getUser()
  if(authError)throw authError
  if(!user)throw new Error('Chưa đăng nhập')
  const rows:TaskItem[]=[]
  const pageSize=500
  for(let from=0;;from+=pageSize){
    const {data,error}=await sb().from('tasks').select('id,title,due_at,priority,status,note,customer_id,opportunity_id').eq('assigned_user_id',user.id).eq('status','pending').order('due_at').order('id').range(from,from+pageSize-1)
    if(error) throw error
    rows.push(...(data??[]) as TaskItem[])
    if((data??[]).length<pageSize)break
  }
  return rows
}

export async function getPipeline(): Promise<PipelineGroup[]> {
  if(isDemoMode){await wait();return demoPipeline}
  const master=await getMasterData()
  const rows:any[]=[]
  const pageSize=500
  for(let from=0;;from+=pageSize){
    const {data,error}=await sb().from('opportunities').select(`id,customer_id,status,priority,potential_level,purchase_timeline,payment_type,stage_id, customers(id,display_name,lead_sources(name))`).in('status',['active','paused']).order('id').range(from,from+pageSize-1)
    if(error)throw error
    rows.push(...(data??[]))
    if((data??[]).length<pageSize)break
  }
  return master.stages.map(stage=>({stage,customers:rows.filter(o=>o.stage_id===stage.id&&o.customers).map(o=>({customer_id:o.customers.id,display_name:o.customers.display_name,source_name:o.customers.lead_sources?.name??'',opportunity:{id:o.id,status:o.status,priority:o.priority,potential_level:o.potential_level,purchase_timeline:o.purchase_timeline,payment_type:o.payment_type,stage}}))})).filter(g=>g.customers.length)
}

export async function getQuotes() {
  if(isDemoMode){await wait();return demoQuotes.map(q=>({...q,customer_name:'Nguyễn Văn Nam',product_name:'MG7 Luxury'}))}
  const {data,error}=await sb().from('quotes').select(`id,version,final_price,list_price,discount_amount,promotion_note,storage_path,status,created_at,sent_at, customers(display_name), products(name), product_variants(name)`).order('created_at',{ascending:false}).limit(100)
  if(error) throw error
  return (data??[]).map((q:any)=>({...q,customer_name:q.customers?.display_name??'Khách hàng',product_name:[q.products?.name,q.product_variants?.name].filter(Boolean).join(' ')}))
}

export async function getReports(from:string,to:string):Promise<{funnel:FunnelRow[];sources:LeadSourceReportRow[]}> {
  if(isDemoMode){await wait();return {funnel:demoFunnel,sources:demoSources}}
  const [f,s]=await Promise.all([sb().rpc('get_funnel_report',{p_from:from,p_to:to}),sb().rpc('get_lead_source_report',{p_from:from,p_to:to})])
  if(f.error) throw f.error
  if(s.error) throw s.error
  return {funnel:(f.data??[]) as FunnelRow[],sources:(s.data??[]) as LeadSourceReportRow[]}
}

export async function getDuplicateCustomers() {
  if(isDemoMode) return [
    {match_type:'phone',match_value:'0909123456',record_count:3,records:[{customer_id:'c1',display_name:'Nguyễn Văn Nam',last_activity_at:new Date().toISOString()},{customer_id:'c7',display_name:'Nam Nguyễn',last_activity_at:null},{customer_id:'c8',display_name:'Anh Nam MG7',last_activity_at:null}]}
  ]
  const {data,error}=await sb().rpc('get_duplicate_customers',{p_contact_type:null})
  if(error) throw error
  return data??[]
}

export async function addCustomerContact(input:{customerId:string;contactType:string;rawValue:string;isPrimary?:boolean}) {
  if(isDemoMode){await wait(250);return 'demo-contact'}
  const {data,error}=await sb().rpc('add_customer_contact',{p_customer_id:input.customerId,p_contact_type:input.contactType,p_raw_value:input.rawValue,p_is_primary:!!input.isPrimary})
  if(error) throw error
  return data as string
}

export async function createOpportunity(input:{customerId:string;productId?:string;variantId?:string;sourceId?:string}) {
  if(isDemoMode){await wait(250);return 'demo-opportunity-new'}
  const {data,error}=await sb().rpc('create_opportunity',{p_customer_id:input.customerId,p_product_id:input.productId||null,p_variant_id:input.variantId||null,p_source_id:input.sourceId||null})
  if(error) throw error
  return data as string
}

export async function updateOpportunity(id:string, patch:Record<string,unknown>) {
  if(isDemoMode){await wait(250);return}
  const allowed=['product_id','variant_id','potential_level','potential_mode','priority','purchase_timeline','expected_purchase_date','budget_min','budget_max','payment_type','loan_ratio','current_vehicle_note','wants_trade_in','competitor_note','note']
  const safe=Object.fromEntries(Object.entries(patch).filter(([k])=>allowed.includes(k)))
  const {error}=await sb().from('opportunities').update(safe).eq('id',id)
  if(error) throw error
}

export async function changeOpportunityStage(opportunityId:string,stageId:string){
  if(isDemoMode){await wait(200);return}
  const {error}=await sb().rpc('change_opportunity_stage',{p_opportunity_id:opportunityId,p_stage_id:stageId});if(error)throw error
}
export async function pauseOpportunity(opportunityId:string,until:string,note?:string){
  if(isDemoMode){await wait(200);return}
  const {error}=await sb().rpc('pause_opportunity',{p_opportunity_id:opportunityId,p_until:until,p_note:note||null});if(error)throw error
}
export async function markWon(opportunityId:string,price?:number,note?:string){
  if(isDemoMode){await wait(200);return}
  const {error}=await sb().rpc('mark_opportunity_won',{p_opportunity_id:opportunityId,p_final_sale_price:price||null,p_note:note||null});if(error)throw error
}
export async function getLostReasons(){
  if(isDemoMode)return [{id:'lr1',display_name:'Giá chưa phù hợp'},{id:'lr2',display_name:'Mua hãng khác'},{id:'lr3',display_name:'Mua đại lý khác'},{id:'lr4',display_name:'Chưa đủ tài chính'},{id:'lr5',display_name:'Không vay được'},{id:'lr6',display_name:'Hoãn mua'},{id:'lr7',display_name:'Không liên hệ được'},{id:'lr8',display_name:'Không còn nhu cầu'},{id:'lr9',display_name:'Lead rác / sai thông tin'},{id:'lr10',display_name:'Khác'}]
  const {data,error}=await sb().from('lost_reasons').select('id,display_name').eq('is_active',true).order('sort_order');if(error)throw error;return data??[]
}
export async function markLost(opportunityId:string,lostReasonId:string,note?:string){
  if(isDemoMode){await wait(200);return}
  const {error}=await sb().rpc('mark_opportunity_lost',{p_opportunity_id:opportunityId,p_lost_reason_id:lostReasonId,p_note:note||null});if(error)throw error
}

export async function createTask(input:{assignedUserId:string;taskTypeId:string;customerId?:string;opportunityId?:string;title?:string;note?:string;dueAt:string;priority?:'normal'|'high'}){
  if(isDemoMode){await wait(250);return 'demo-task-new'}
  const {data,error}=await sb().rpc('create_task',{p_assigned_user_id:input.assignedUserId,p_task_type_id:input.taskTypeId,p_customer_id:input.customerId||null,p_opportunity_id:input.opportunityId||null,p_title:input.title||null,p_note:input.note||null,p_due_at:input.dueAt,p_priority:input.priority||'normal'});if(error)throw error;return data as string
}
export async function cancelTask(taskId:string,note?:string){
  if(isDemoMode){await wait(180);return true}
  const {data,error}=await sb().rpc('cancel_task',{p_task_id:taskId,p_note:note||null});if(error)throw error;return !!data
}
export async function addActivity(input:{customerId:string;opportunityId?:string;activityType:string;resultCode?:string;note?:string}){
  if(isDemoMode){await wait(200);return 'demo-activity-new'}
  const {data,error}=await sb().rpc('add_activity',{p_customer_id:input.customerId,p_opportunity_id:input.opportunityId||null,p_activity_type:input.activityType,p_result_code:input.resultCode||null,p_note:input.note||null,p_occurred_at:new Date().toISOString()});if(error)throw error;return data as string
}

export async function createQuote(input:{opportunityId:string;listPrice?:number;discountAmount?:number;finalPrice?:number;promotionNote?:string}){
  if(isDemoMode){await wait(260);return 'demo-quote-new'}
  const {data,error}=await sb().rpc('create_quote',{p_opportunity_id:input.opportunityId,p_list_price:input.listPrice||null,p_discount_amount:input.discountAmount||null,p_final_price:input.finalPrice||null,p_promotion_note:input.promotionNote||null,p_storage_path:null});if(error)throw error;return data as string
}
export async function markQuoteSent(quoteId:string){if(isDemoMode){await wait(160);return}const{error}=await sb().rpc('mark_quote_sent',{p_quote_id:quoteId,p_sent_at:new Date().toISOString()});if(error)throw error}

export async function getAdminUsers(){
  if(isDemoMode)return [
    {id:'u1',full_name:'Nguyễn Minh Đăng',role:'sales',status:'active',team_id:'t1',department_id:'d1'},
    {id:'u2',full_name:'Trưởng nhóm 1',role:'team_leader',status:'active',team_id:'t1',department_id:'d1'},
    {id:'u3',full_name:'Trưởng phòng Kinh doanh',role:'sales_manager',status:'active',team_id:null,department_id:'d1'}
  ]
  const {data,error}=await sb().from('profiles').select('id,full_name,role,status,team_id,department_id,teams(name),departments(name)').order('full_name');if(error)throw error;return data??[]
}
export async function getOrgStructure(){
  if(isDemoMode)return {departments:[{id:'d1',name:'Phòng Kinh doanh'}],teams:[{id:'t1',name:'Nhóm 1',department_id:'d1'},{id:'t2',name:'Nhóm 2',department_id:'d1'}]}
  const [d,t]=await Promise.all([sb().from('departments').select('id,name').eq('is_active',true).order('name'),sb().from('teams').select('id,name,department_id').eq('is_active',true).order('name')]);if(d.error)throw d.error;if(t.error)throw t.error;return {departments:d.data??[],teams:t.data??[]}
}
async function invokeAdmin(name:string,body:Record<string,unknown>){
  const {data,error}=await sb().functions.invoke(name,{body})
  if(error){
    const response=(error as {context?:unknown}).context
    if(response instanceof Response){
      const detail=(await response.text()).trim()
      if(detail)throw new Error(detail)
    }
    throw error
  }
  return data
}
export async function adminCreateUser(input:{email:string;full_name:string;role:string;department_id?:string|null;team_id?:string|null}){if(isDemoMode){await wait(300);return {user_id:'demo-user'}}return invokeAdmin('admin-create-user',input)}
export async function adminLockUser(userId:string,locked:boolean){if(isDemoMode){await wait(200);return}await invokeAdmin('admin-lock-user',{user_id:userId,locked})}
export async function adminUpdateUser(input:{user_id:string;full_name:string;role:string;department_id?:string|null;team_id?:string|null}){if(isDemoMode){await wait(220);return}await invokeAdmin('admin-update-user',input)}

export async function getAssignableUsers(){
  if(isDemoMode)return [{id:'u1',full_name:'Nguyễn Minh Đăng',role:'sales',team_id:'t1',department_id:'d1'},{id:'u4',full_name:'Sales B',role:'sales',team_id:'t1',department_id:'d1'}]
  const {data,error}=await sb().from('profiles').select('id,full_name,role,team_id,department_id,status').eq('status','active').order('full_name');if(error)throw error;return data??[]
}
export async function transferCustomer(customerId:string,newOwnerUserId:string,reason?:string){if(isDemoMode){await wait(220);return}const{error}=await sb().rpc('transfer_customer',{p_customer_id:customerId,p_new_owner_user_id:newOwnerUserId,p_reason:reason||null});if(error)throw error}

export async function getScheduleBlocks(){
  if(isDemoMode)return [
    {id:'ws1',day_of_week:1,start_time:'08:00:00',end_time:'08:20:00',title:'Kiểm tra công việc',is_active:true},
    {id:'ws2',day_of_week:1,start_time:'08:20:00',end_time:'09:30:00',title:'Chăm sóc khách',is_active:true},
    {id:'ws3',day_of_week:1,start_time:'09:30:00',end_time:'10:30:00',title:'Tìm khách mới',is_active:true},
    {id:'ws4',day_of_week:1,start_time:'10:30:00',end_time:'12:00:00',title:'Tư vấn / báo giá',is_active:true},
    {id:'ws5',day_of_week:1,start_time:'13:20:00',end_time:'14:30:00',title:'Khách ưu tiên',is_active:true},
    {id:'ws6',day_of_week:1,start_time:'14:30:00',end_time:'15:30:00',title:'Tìm khách mới',is_active:true},
    {id:'ws7',day_of_week:1,start_time:'15:30:00',end_time:'16:20:00',title:'Chăm sóc lần 2',is_active:true},
    {id:'ws8',day_of_week:1,start_time:'16:20:00',end_time:'17:00:00',title:'Xử lý tồn / hoàn tất ngày',is_active:true}
  ]
  const {data,error}=await sb().from('work_schedule_blocks').select('id,day_of_week,start_time,end_time,title,is_active').eq('user_id',(await sb().auth.getUser()).data.user?.id).eq('is_active',true).order('day_of_week').order('start_time');if(error)throw error;return data??[]
}
export async function createScheduleBlock(input:{dayOfWeek:number;startTime:string;endTime:string;title:string}){
  if(isDemoMode){await wait(150);return 'demo-block'}
  const {data:{user}}=await sb().auth.getUser();if(!user)throw new Error('Chưa đăng nhập')
  const {data:p,error:pe}=await sb().from('profiles').select('organization_id,department_id,team_id').eq('id',user.id).single();if(pe)throw pe
  const {data,error}=await sb().from('work_schedule_blocks').insert({organization_id:p.organization_id,department_id:p.department_id,team_id:p.team_id,user_id:user.id,day_of_week:input.dayOfWeek,start_time:input.startTime,end_time:input.endTime,title:input.title,is_active:true}).select('id').single();if(error)throw error;return data.id
}
export async function updateScheduleBlock(id:string,patch:Record<string,unknown>){if(isDemoMode){await wait(120);return}const{error}=await sb().from('work_schedule_blocks').update(patch).eq('id',id);if(error)throw error}

export async function getNotifications(){
  if(isDemoMode)return [
    {id:'n1',type:'assignment',title:'Bạn có khách mới',message:'Khách Minh Nguyễn đã được giao cho bạn.',read_at:null,created_at:new Date().toISOString()},
    {id:'n2',type:'info',title:'Nhắc công việc',message:'Bạn có công việc cần xử lý trong hôm nay.',read_at:new Date().toISOString(),created_at:new Date(Date.now()-3600000).toISOString()}
  ]
  const {data,error}=await sb().from('notifications').select('id,type,title,message,customer_id,task_id,opportunity_id,read_at,created_at').order('created_at',{ascending:false}).limit(30)
  if(error)throw error
  return data??[]
}
export async function markNotificationRead(id:string){
  if(isDemoMode){await wait(100);return}
  const {error}=await sb().from('notifications').update({read_at:new Date().toISOString()}).eq('id',id)
  if(error)throw error
}

async function currentOrganizationId(){
  if(isDemoMode)return 'org-demo'
  const {data:{user}}=await sb().auth.getUser();if(!user)throw new Error('Chưa đăng nhập')
  const {data,error}=await sb().from('profiles').select('organization_id').eq('id',user.id).single();if(error)throw error
  if(!data?.organization_id)throw new Error('Tài khoản chưa thuộc tổ chức')
  return data.organization_id as string
}
export async function getAdminMasterConfig(){
  if(isDemoMode)return {
    sources:[{id:'ls1',code:'facebook_ads',name:'Facebook Ads',sort_order:10,is_priority:true,response_sla_minutes:15,is_active:true},{id:'ls2',code:'website',name:'Website',sort_order:20,is_priority:true,response_sla_minutes:15,is_active:true}],
    stages:[{id:'s1',code:'new',display_name:'Khách mới',sort_order:10,is_active:true},{id:'s2',code:'contacted',display_name:'Đã liên hệ',sort_order:20,is_active:true},{id:'s7',code:'negotiation',display_name:'Đang thương lượng',sort_order:70,is_active:true}],
    products:[{id:'p1',brand:'MG',name:'MG7',code:'MG7',sort_order:10,is_active:true,product_variants:[{id:'v1',name:'Luxury',code:'LUX',list_price:738000000,sort_order:10,is_active:true}]},{id:'p2',brand:'MG',name:'MG5',code:'MG5',sort_order:20,is_active:true,product_variants:[]}],
    careRules:[{id:'cr1',potential_level:'hot',max_inactive_hours:24,is_active:true},{id:'cr2',potential_level:'potential',max_inactive_hours:72,is_active:true},{id:'cr3',potential_level:'watch',max_inactive_hours:168,is_active:true}]
  }
  const [sources,stages,products,care]=await Promise.all([
    sb().from('lead_sources').select('id,code,name,sort_order,is_priority,response_sla_minutes,is_active').order('sort_order'),
    sb().from('pipeline_stages').select('id,code,display_name,sort_order,is_active').order('sort_order'),
    sb().from('products').select('id,brand,name,code,sort_order,is_active,product_variants(id,name,code,list_price,sort_order,is_active)').order('sort_order'),
    sb().from('care_rules').select('id,potential_level,max_inactive_hours,is_active').order('max_inactive_hours')
  ])
  for(const r of [sources,stages,products,care])if(r.error)throw r.error
  return {sources:sources.data??[],stages:stages.data??[],products:products.data??[],careRules:care.data??[]}
}
export async function createLeadSource(input:{name:string;code:string;sort_order:number;is_priority:boolean;response_sla_minutes?:number|null}){
  if(isDemoMode){await wait(150);return}
  const organization_id=await currentOrganizationId()
  const {error}=await sb().from('lead_sources').insert({...input,organization_id,is_active:true});if(error)throw error
}
export async function updateLeadSource(id:string,patch:Record<string,unknown>){if(isDemoMode){await wait(120);return}const{error}=await sb().from('lead_sources').update(patch).eq('id',id);if(error)throw error}
export async function updatePipelineStage(id:string,patch:{display_name?:string;sort_order?:number;is_active?:boolean}){if(isDemoMode){await wait(120);return}const{error}=await sb().from('pipeline_stages').update(patch).eq('id',id);if(error)throw error}
export async function createProduct(input:{name:string;code:string;brand?:string;sort_order:number}){
  if(isDemoMode){await wait(150);return}
  const organization_id=await currentOrganizationId();const{error}=await sb().from('products').insert({organization_id,brand:input.brand||'MG',name:input.name,code:input.code,sort_order:input.sort_order,is_active:true});if(error)throw error
}
export async function updateProduct(id:string,patch:Record<string,unknown>){if(isDemoMode){await wait(120);return}const{error}=await sb().from('products').update(patch).eq('id',id);if(error)throw error}
export async function createProductVariant(input:{productId:string;name:string;code:string;listPrice?:number|null;sortOrder:number}){if(isDemoMode){await wait(150);return}const{error}=await sb().from('product_variants').insert({product_id:input.productId,name:input.name,code:input.code,list_price:input.listPrice||null,sort_order:input.sortOrder,is_active:true});if(error)throw error}
export async function updateProductVariant(id:string,patch:Record<string,unknown>){if(isDemoMode){await wait(120);return}const{error}=await sb().from('product_variants').update(patch).eq('id',id);if(error)throw error}
export async function updateCareRule(id:string,patch:{max_inactive_hours?:number;is_active?:boolean}){if(isDemoMode){await wait(120);return}const{error}=await sb().from('care_rules').update(patch).eq('id',id);if(error)throw error}
