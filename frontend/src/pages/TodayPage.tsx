import { useQuery } from '@tanstack/react-query'
import { AlertTriangle, CalendarDays, CarFront, CheckCheck, CheckCircle2, ChevronRight, CircleGauge, Clock3, Flame, MessageCircle, Phone, Plus, SlidersHorizontal, Trophy, UserRound, UserRoundPlus, UsersRound, Zap } from 'lucide-react'
import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { CompleteTaskSheet } from '../components/CompleteTaskSheet'
import { CreateTaskSheet } from '../components/CreateTaskSheet'
import { QuickCreateLead } from '../components/QuickCreateLead'
import { Button, EmptyState, Skeleton } from '../components/UI'
import { useAuth } from '../context/AuthContext'
import { getToday, getTodayCompleted, getTodayCustomerPreviews, type TodayCustomerPreview } from '../lib/api'
import { relativeTime, timeOnly } from '../lib/format'
import type { PriorityLead, TodayTask } from '../lib/types'

const icon={className:'h-4 w-4 shrink-0',strokeWidth:1.75}
const phoneNumber=(raw?:string|null)=>{
  const digits=raw?.replace(/[^\d+]/g,'')
  return digits && /^\+?\d{8,15}$/.test(digits)?digits:null
}
const isAppointment=(title:string)=>/lái thử|hẹn gặp|showroom|bàn giao|xem xe/i.test(title)
const initials=(name:string)=>name.trim().split(/\s+/).slice(-2).map(word=>word[0]).join('').toUpperCase()
const slaClock=(lead:PriorityLead,now:number)=>{
  if(!lead.response_sla_minutes)return null
  const remain=Math.max(0,Math.round((Date.parse(lead.created_at)+lead.response_sla_minutes*60000-now)/1000))
  return remain?`${String(Math.floor(remain/60)).padStart(2,'0')}:${String(remain%60).padStart(2,'0')}`:'Đã quá SLA'
}

export function TodayPage(){
  const {profile}=useAuth()
  const nav=useNavigate()
  const [scope,setScope]=useState<'self'|'team'|'department'>('self')
  const [selectedTask,setSelectedTask]=useState<string|null>(null)
  const [newTask,setNewTask]=useState(false)
  const [newLead,setNewLead]=useState(false)
  const [now,setNow]=useState(Date.now())
  useEffect(()=>{const timer=window.setInterval(()=>setNow(Date.now()),1000);return()=>window.clearInterval(timer)},[])
  const dashboard=useQuery({queryKey:['today',scope],queryFn:()=>getToday(scope),refetchInterval:60_000})
  const data=dashboard.data
  const doneQuery=useQuery({queryKey:['today-completed',scope,profile?.id],queryFn:()=>getTodayCompleted(scope,profile!),enabled:!!profile,refetchInterval:60_000})
  const ids=Array.from(new Set([
    ...(data?.overdue_tasks??[]).map(t=>t.customer_id),
    ...(data?.upcoming_tasks??[]).map(t=>t.customer_id),
    ...(data?.priority_new_leads??[]).map(l=>l.id),
  ].filter((id):id is string=>!!id)))
  const customers=useQuery({queryKey:['today-customers',ids],queryFn:()=>getTodayCustomerPreviews(ids),enabled:ids.length>0,staleTime:60_000})
  const preview=(id?:string|null):TodayCustomerPreview|undefined=>id?customers.data?.[id]:undefined
  const manager=profile?.role==='sales_manager'||profile?.role==='admin'
  const canChangeScope=manager||profile?.role==='team_leader'
  const otherScope=manager?'department':'team'
  const appointments=(data?.upcoming_tasks??[]).filter(t=>isAppointment(t.title))
  const nextTasks=(data?.upcoming_tasks??[]).filter(t=>!isAppointment(t.title))
  const done=doneQuery.data
  const pending=data?.overview.today_tasks??0
  const total=pending+(done??0)
  const completion=total?Math.round((done??0)/total*100):0
  const name=profile?.full_name?.trim().split(/\s+/).at(-1)??'bạn'

  const contactActions=(id?:string|null,phone?:string|null)=>{
    const number=phoneNumber(phone)
    return <>
      {number&&<a href={`tel:${number}`} className="today-action primary"><Phone {...icon}/> Gọi ngay</a>}
      {number&&<a href={`https://zalo.me/${number.replace(/^\+84/,'0')}`} target="_blank" rel="noreferrer" className="today-action secondary today-desktop-extra"><MessageCircle {...icon}/> Nhắn Zalo</a>}
      {id&&<button type="button" className={`today-action ${number?'quiet':'primary'}`} onClick={()=>nav(`/customers/${id}`)}><ChevronRight {...icon}/><span className="today-desktop-extra">Chi tiết khách</span><span className="today-mobile-only">Hồ sơ</span></button>}
      {!number&&!id&&<button type="button" className="today-action primary" onClick={()=>nav('/tasks')}>Xem công việc</button>}
    </>
  }
  const overdueCard=(task:TodayTask)=>{
    const customer=preview(task.customer_id)
    const label=customer?.display_name??task.title
    return <article className="today-overdue-card" key={task.id}>
      <div className="today-person-line"><div className="today-initials">{initials(label)}</div><div className="today-person-copy"><div className="today-person-name"><strong>{label}</strong>{customer?.phone&&<span>{customer.phone}</span>}{customer?.potential==='hot'&&<span className="today-hot"><Flame {...icon}/> Nóng</span>}</div>{customer?.vehicle&&<span className="today-car"><CarFront {...icon}/>{customer.vehicle}</span>}</div><span className="today-late"><Clock3 {...icon}/>{relativeTime(task.due_at)}</span></div>
      <p className="today-action-detail"><span className="today-desktop-extra">Hành động: </span>{task.title}</p>
      <div className="today-actions">{contactActions(task.customer_id,customer?.phone)}{scope==='self'&&<button type="button" className="today-action done" onClick={()=>setSelectedTask(task.id)}><CheckCircle2 {...icon}/> Xong</button>}</div>
    </article>
  }
  const leadCard=(lead:PriorityLead)=>{
    const customer=preview(lead.id)
    const clock=slaClock(lead,now)
    const late=!!lead.response_sla_minutes&&clock==='Đã quá SLA'
    return <article className="today-lead-card" key={lead.id}>
      <div className="today-lead-top"><span className="today-source"><span className="today-online-dot"/>{lead.source_name}</span><span className={`today-sla-clock ${late?'late':''}`}><Clock3 {...icon}/>{clock??`${Math.round(lead.age_minutes)} phút trước`}</span></div>
      <div className="today-lead-person"><div className="today-initials green">{initials(lead.display_name)}</div><div className="min-w-0 flex-1"><div className="today-person-name"><strong>{lead.display_name}</strong>{customer?.potential==='hot'&&<span className="today-hot"><Flame {...icon}/> Nóng</span>}</div>{customer?.phone&&<span className="today-contact">{customer.phone}</span>}{customer?.vehicle&&<span className="today-interest">Quan tâm: {customer.vehicle}</span>}</div></div>
      {customer?.note&&<div className="today-lead-note"><span>Ghi chú</span>{customer.note}</div>}
      <div className="today-sla-row"><span><CheckCircle2 {...icon}/> {lead.response_sla_minutes?`Cam kết SLA < ${lead.response_sla_minutes} phút`:'SLA chưa thiết lập'}</span><strong className={late?'danger':''}>{late?'Cần liên hệ ngay':clock?'Trong thời gian phản hồi':'Lead cần phản hồi'}</strong></div>
      <div className="today-actions">{contactActions(lead.id,customer?.phone)}</div>
    </article>
  }

  return <div className="page today-page">
    <div className="today-hero"><div className="today-hero-mark"><CircleGauge className="h-6 w-6" strokeWidth={1.75}/>{(data?.overview.overdue_tasks??0)>0&&<span/>}</div><div className="today-hero-copy"><p className="today-eyebrow"><span className="today-online-dot"/> Trợ lý bán hàng 360°</p><h1>Chào {name} <span className="today-hero-tail">– Trợ lý Bán hàng 360°</span></h1><p className="today-hero-desktop">Tiến độ hôm nay: <strong>{done??'—'}/{total||'—'}</strong> việc đã xong · {new Intl.DateTimeFormat('vi-VN',{weekday:'long',day:'2-digit',month:'2-digit'}).format(new Date())}</p></div><div className="today-hero-controls"><span className="today-hero-pill"><Trophy {...icon}/> Hôm nay: {done??'—'}/{total||'—'}</span>{canChangeScope&&<div className="segmented today-scope" role="group" aria-label="Phạm vi tổng quan"><button className={scope==='self'?'active':''} onClick={()=>setScope('self')}><UserRound {...icon}/> Cá nhân</button><button className={scope!=='self'?'active':''} onClick={()=>setScope(otherScope)}><UsersRound {...icon}/> {manager?'Phòng':'Nhóm'}</button></div>}<button className="today-hero-filter" onClick={()=>nav('/tasks')}><SlidersHorizontal {...icon}/> Bộ lọc</button><button className="today-hero-create" onClick={()=>setNewTask(true)}><Plus {...icon}/> Tạo tác vụ</button></div></div>
    {dashboard.isLoading?<Skeleton lines={8}/>:dashboard.isError?<EmptyState title="Không tải được Hôm nay" description={dashboard.error.message} action={<Button onClick={()=>dashboard.refetch()}>Thử lại</Button>}/>:data&&<>
      <p className="today-mobile-intro">Bạn có <strong>{data.overview.overdue_tasks} việc quá hạn</strong> và <b>{data.overview.priority_unhandled} lead mới</b> cần xử lý ngay.</p>
      {done!==undefined&&<div className="today-mobile-progress" role="progressbar" aria-label="Tỷ lệ công việc hoàn thành hôm nay" aria-valuemin={0} aria-valuemax={100} aria-valuenow={completion}><span style={{width:`${completion}%`}}/></div>}
      <div className="today-kpis">
        <button type="button" className="today-kpi rose" onClick={()=>document.getElementById('today-overdue')?.scrollIntoView({behavior:'smooth'})}><span className="today-kpi-label">Cần xử lý gấp<span className="today-mobile-only">Quá hạn</span></span><AlertTriangle {...icon}/><div><strong>{data.overview.overdue_tasks}</strong><small>mục quá hạn</small></div><p>Việc cần xử lý ngay</p><i/></button>
        <button type="button" className="today-kpi blue" onClick={()=>document.getElementById('today-leads')?.scrollIntoView({behavior:'smooth'})}><span className="today-kpi-label">Lead ưu tiên (SLA)</span><Zap {...icon}/><div><strong>{data.overview.priority_unhandled}</strong><small>lead cần phản hồi</small></div><p>Ưu tiên liên hệ từ nguồn trả phí</p><i/></button>
        <button type="button" className="today-kpi amber" onClick={()=>document.getElementById('today-next')?.scrollIntoView({behavior:'smooth'})}><span className="today-kpi-label">Trong ngày<span className="today-mobile-only">Cần xử lý</span></span><CalendarDays {...icon}/><div><strong>{data.overview.today_tasks}</strong><small>việc hôm nay</small></div><p>{appointments.length} lịch hẹn · {nextTasks.length} việc tiếp theo</p><i/></button>
        <div className="today-kpi emerald"><span className="today-kpi-label">Hiệu suất hôm nay<span className="today-mobile-only">Đã xong</span></span><CheckCheck {...icon}/><div><strong>{done??'—'}<em>/{total||'—'}</em></strong><small>{done===undefined?'Đang tải':`Đạt ${completion}%`}</small></div><p>{done===undefined?'Đang tải số việc hoàn thành':`${data.overview.new_leads_today} khách mới hôm nay`}</p><i style={{width:`${completion}%`}}/></div>
      </div>
      <div className="today-main-grid">
        <div className="today-main-left">
          <section id="today-overdue" className="today-panel"><div className="today-panel-head"><h2><span className="today-panel-dot rose"/> <span className="today-desktop-extra">Tác vụ Quá hạn & Vi phạm SLA</span><span className="today-mobile-only">Cảnh báo quá hạn ({data.overdue_tasks.length})</span></h2><span className="today-priority-pill">{data.overdue_tasks.length} mục ưu tiên</span></div>{data.overdue_tasks.length?<div className="today-panel-list">{data.overdue_tasks.map(overdueCard)}</div>:<div className="today-empty"><CheckCircle2 {...icon}/> Không có việc quá hạn.</div>}</section>
          <section id="today-leads" className="today-panel"><div className="today-panel-head"><h2><span className="today-panel-dot blue"/><span className="today-desktop-extra">Lead Mới Ưu Tiên · Realtime First-Call</span><span className="today-mobile-only">Lead ưu tiên mới</span></h2><span className="today-sla-pill">First Call</span></div>{data.priority_new_leads.length?<div className="today-panel-list">{data.priority_new_leads.map(leadCard)}</div>:<div className="today-empty">Chưa có lead ưu tiên cần phản hồi.</div>}</section>
        </div>
        <div className="today-main-right">
          <section className="today-panel today-appointments"><div className="today-panel-head"><h2><CalendarDays {...icon}/> <span className="today-desktop-extra">Lái thử Showroom Hôm nay</span><span className="today-mobile-only">Lịch hẹn & lái thử (hôm nay)</span></h2><span className="today-panel-count">{appointments.length} lịch</span></div>{appointments.length?<div className="today-panel-list">{appointments.map(t=><article className="today-appointment" key={t.id}><div className="today-appointment-top"><span className="today-hour">{timeOnly(t.due_at)}</span><strong>{t.title}</strong></div><div className="today-appointment-info"><span>Khách hàng</span><strong>{preview(t.customer_id)?.display_name??'Chưa liên kết khách'}</strong>{preview(t.customer_id)?.vehicle&&<><span>Xe quan tâm</span><strong>{preview(t.customer_id)?.vehicle}</strong></>}</div><div className="today-appointment-actions">{t.customer_id&&<button type="button" onClick={()=>nav(`/customers/${t.customer_id}`)}><ChevronRight {...icon}/> Mở hồ sơ</button>}{scope==='self'&&<button type="button" onClick={()=>setSelectedTask(t.id)}><CheckCircle2 {...icon}/> Hoàn thành</button>}</div></article>)}</div>:<div className="today-empty">Chưa có lịch hẹn hoặc lái thử hôm nay.</div>}</section>
          <section className="today-panel today-summary"><div className="today-panel-head"><h2><Trophy {...icon}/><span className="today-desktop-extra">Tiến Độ Công Việc Hôm Nay</span><span className="today-mobile-only">Tiến độ hôm nay</span></h2><span className="today-panel-count">{completion}%</span></div><div className="today-summary-body"><div><strong>{done??'—'}/{total||'—'} việc</strong><span>{done===undefined?'Đang tải tiến độ':`${done} đã hoàn thành · ${pending} còn chờ`}</span></div>{done!==undefined&&<div className="today-summary-bar"><span style={{width:`${completion}%`}}/></div>}</div></section>
          <section id="today-next" className="today-panel today-next"><div className="today-panel-head"><h2><CheckCheck {...icon}/><span className="today-desktop-extra">Kế Hoạch Tiếp Theo</span><span className="today-mobile-only">Công việc tiếp theo ({nextTasks.length})</span></h2><button onClick={()=>nav('/tasks')} className="today-panel-count">Xem tất cả</button></div>{nextTasks.length?<div className="today-panel-list">{nextTasks.map(t=><article className="today-next-task" key={t.id}><span className="today-hour">{timeOnly(t.due_at)}</span><div className="min-w-0 flex-1"><strong>{t.title}</strong><span>{preview(t.customer_id)?.display_name??'Công việc hôm nay'}{preview(t.customer_id)?.vehicle?` · ${preview(t.customer_id)?.vehicle}`:''}</span></div>{scope==='self'&&<button type="button" onClick={()=>setSelectedTask(t.id)} aria-label={`Hoàn thành ${t.title}`}><CheckCircle2 {...icon}/></button>}</article>)}</div>:<div className="today-empty">Không còn công việc sắp tới.</div>}<div className="today-quick-actions"><button onClick={()=>setNewTask(true)}><Plus {...icon}/> Thêm việc cần làm</button><button onClick={()=>setNewLead(true)}><UserRoundPlus {...icon}/> Nhập lead nhanh</button></div></section>
        </div>
      </div>
      {customers.isError&&<p className="mt-4 text-xs text-slate-500">Không tải được chi tiết liên hệ. Có thể mở hồ sơ khách hàng để xem thông tin.</p>}
      {doneQuery.isError&&<p className="mt-2 text-xs text-slate-500">Chưa tải được số việc đã hoàn thành.</p>}
    </>}
    <CompleteTaskSheet taskId={selectedTask} open={!!selectedTask} onClose={()=>setSelectedTask(null)}/>
    <CreateTaskSheet open={newTask} onClose={()=>setNewTask(false)}/>
    <QuickCreateLead open={newLead} onClose={()=>setNewLead(false)}/>
  </div>
}
