import { useQuery } from '@tanstack/react-query'
import { AlertCircle, ArrowRight, CalendarDays, CarFront, CheckCircle2, ChevronRight, Clock3, Phone, Plus, UserRoundPlus, Zap } from 'lucide-react'
import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { CompleteTaskSheet } from '../components/CompleteTaskSheet'
import { CreateTaskSheet } from '../components/CreateTaskSheet'
import { QuickCreateLead } from '../components/QuickCreateLead'
import { Button, EmptyState, Skeleton } from '../components/UI'
import { useAuth } from '../context/AuthContext'
import { getToday, getTodayCustomerPreviews, type TodayCustomerPreview } from '../lib/api'
import { relativeTime, timeOnly } from '../lib/format'
import type { TodayTask } from '../lib/types'

const icon = {className:'h-4 w-4 shrink-0',strokeWidth:1.75}
const isAppointment = (title:string) => /lái thử|hẹn gặp|showroom|bàn giao|xem xe/i.test(title)
const phoneLink = (raw?:string|null) => {
  const number = raw?.replace(/[^\d+]/g,'')
  return number && /^\+?\d{8,15}$/.test(number) ? `tel:${number}` : null
}

export function TodayPage(){
  const {profile}=useAuth()
  const [scope,setScope]=useState<'self'|'team'|'department'>('self')
  const [task,setTask]=useState<string|null>(null)
  const [createTask,setCreateTask]=useState(false)
  const [createLead,setCreateLead]=useState(false)
  const nav=useNavigate()
  const q=useQuery({queryKey:['today',scope],queryFn:()=>getToday(scope)})
  const d=q.data
  const ids=Array.from(new Set([
    ...(d?.overdue_tasks??[]).map(t=>t.customer_id),
    ...(d?.upcoming_tasks??[]).map(t=>t.customer_id),
    ...(d?.priority_new_leads??[]).map(l=>l.id),
  ].filter((id):id is string=>!!id)))
  const customers=useQuery({queryKey:['today-customers',ids],queryFn:()=>getTodayCustomerPreviews(ids),enabled:ids.length>0,staleTime:60_000})
  const preview=(id?:string|null):TodayCustomerPreview|undefined=>id?customers.data?.[id]:undefined
  const manager=profile?.role==='sales_manager'
  const canChangeScope=manager||profile?.role==='team_leader'
  const appointments=(d?.upcoming_tasks??[]).filter(t=>isAppointment(t.title))
  const nextTasks=(d?.upcoming_tasks??[]).filter(t=>!isAppointment(t.title))
  const firstName=profile?.full_name?.trim().split(/\s+/).at(-1)??'bạn'
  const overdue=d?.overview.overdue_tasks??0
  const leads=d?.overview.priority_unhandled??0
  const today=d?.overview.today_tasks??0

  const customerLink=(id?:string|null)=>id&&<button type="button" className="today-open" onClick={()=>nav(`/customers/${id}`)} aria-label="Mở hồ sơ khách hàng"><ChevronRight {...icon}/></button>
  const taskCard=(t:TodayTask,late:boolean)=>{
    const customer=preview(t.customer_id)
    const call=phoneLink(customer?.phone)
    return <article className={`today-task-card ${late?'is-late':''}`} key={t.id}>
      <div className="today-task-head"><div className="min-w-0"><strong>{customer?.display_name??t.title}</strong>{customer&&<span className="today-contact">{customer.phone??'Chưa có số điện thoại'}</span>}</div><span className={`today-time-badge ${late?'late':''}`}>{late?relativeTime(t.due_at):timeOnly(t.due_at)}</span></div>
      {customer?.vehicle&&<span className="today-vehicle"><CarFront {...icon}/>{customer.vehicle}</span>}
      <p className="today-task-title">{t.title}</p>
      <div className="today-card-actions">
        {call?<a className="today-call" href={call}><Phone {...icon}/> Gọi ngay</a>:<button type="button" className="today-call outline" onClick={()=>t.customer_id?nav(`/customers/${t.customer_id}`):nav('/tasks')}>{t.customer_id?'Mở hồ sơ':'Xem công việc'} <ArrowRight {...icon}/></button>}
        {scope==='self'&&<button type="button" className="today-complete" onClick={()=>setTask(t.id)}><CheckCircle2 {...icon}/> Xong</button>}
        {customerLink(t.customer_id)}
      </div>
    </article>
  }

  return <div className="page today-page">
    <header className="today-header">
      <div><p className="today-eyebrow"><span className="today-online-dot"/> Ưu tiên hôm nay · Trợ lý bán hàng 360°</p><h1>Chào {firstName}</h1></div>
      <span className="today-date"><CalendarDays {...icon}/>{new Intl.DateTimeFormat('vi-VN',{weekday:'long',day:'2-digit',month:'2-digit'}).format(new Date())}</span>
    </header>
    {canChangeScope&&<div className="segmented today-scope" role="group" aria-label="Phạm vi tổng quan"><button className={scope==='self'?'active':''} onClick={()=>setScope('self')}>Cá nhân</button><button className={scope!=='self'?'active':''} onClick={()=>setScope(manager?'department':'team')}>{manager?'Phòng':'Nhóm'}</button></div>}
    {q.isLoading?<Skeleton lines={7}/>:q.isError?<EmptyState title="Không tải được Hôm nay" description={q.error.message} action={<Button onClick={()=>q.refetch()}>Thử lại</Button>}/>:d&&<>
      <div className="today-intro">Bạn có <b className="text-rose-600">{overdue} việc quá hạn</b> và <b className="text-sky-700">{leads} lead ưu tiên</b> cần xử lý.</div>
      <div className="today-metrics">
        <button type="button" className="today-metric rose" onClick={()=>document.getElementById('today-overdue')?.scrollIntoView({behavior:'smooth'})}><span>Quá hạn</span><strong>{overdue}<small> việc</small></strong></button>
        <button type="button" className="today-metric sky" onClick={()=>document.getElementById('today-leads')?.scrollIntoView({behavior:'smooth'})}><span>Lead ưu tiên</span><strong>{leads}<small> mới</small></strong></button>
        <button type="button" className="today-metric amber" onClick={()=>document.getElementById('today-next')?.scrollIntoView({behavior:'smooth'})}><span>Việc hôm nay</span><strong>{today}<small> việc</small></strong></button>
        <button type="button" className="today-metric emerald" onClick={()=>nav('/customers')}><span>Khách mới</span><strong>{d.overview.new_leads_today}<small> hôm nay</small></strong></button>
      </div>

      <div className="today-sections">
        <section id="today-overdue" className="today-section"><div className="today-section-head"><h2 className="text-rose-600"><AlertCircle {...icon}/> Cảnh báo quá hạn ({d.overdue_tasks.length})</h2><span>Ưu tiên số 1</span></div>
          {d.overdue_tasks.length?<div className="today-stack">{d.overdue_tasks.map(t=>taskCard(t,true))}</div>:<div className="today-empty"><CheckCircle2 {...icon}/> Không có việc quá hạn.</div>}
        </section>
        <section id="today-leads" className="today-section"><div className="today-section-head"><h2><Zap {...icon}/> Lead ưu tiên mới</h2><span>SLA phản hồi</span></div>
          {d.priority_new_leads.length?<div className="today-stack">{d.priority_new_leads.map(l=>{
            const c=preview(l.id)
            const call=phoneLink(c?.phone)
            const late=!!l.response_sla_minutes&&l.age_minutes>l.response_sla_minutes
            return <article className="today-lead-card" key={l.id}>
              <div className="today-lead-top"><span className="today-source">{l.source_name}</span><span className={`today-time-badge ${late?'late':''}`}><Clock3 {...icon}/>{Math.round(l.age_minutes)} phút</span></div>
              <h3>{l.display_name}</h3>{c?.vehicle&&<p className="today-interest">Quan tâm: {c.vehicle}</p>}{c?.note&&<p className="today-note">{c.note}</p>}
              <div className="today-sla"><span><CheckCircle2 {...icon}/> SLA {l.response_sla_minutes?`< ${l.response_sla_minutes} phút`:'chưa thiết lập'}</span><strong className={late?'text-rose-600':'text-emerald-700'}>{late?'Cần liên hệ ngay':'Đang trong hạn'}</strong></div>
              {call?<a className="today-call full" href={call}><Phone {...icon}/> Gọi ngay cho khách</a>:<button type="button" className="today-call full" onClick={()=>nav(`/customers/${l.id}`)}><ChevronRight {...icon}/> Mở hồ sơ để liên hệ</button>}
            </article>
          })}</div>:<div className="today-empty"><CheckCircle2 {...icon}/> Chưa có lead ưu tiên cần phản hồi.</div>}
        </section>
        <section className="today-section"><div className="today-section-head"><h2><CalendarDays {...icon}/> Lịch hẹn & lái thử</h2><span>{appointments.length} lịch</span></div>
          {appointments.length?<div className="today-stack">{appointments.map(t=><article className="today-appointment" key={t.id}>
            <div className="today-hour">{timeOnly(t.due_at)}</div><div className="min-w-0 flex-1"><strong>{t.title}</strong><span>{preview(t.customer_id)?.display_name??'Lịch hẹn hôm nay'}</span>{preview(t.customer_id)?.vehicle&&<small><CarFront {...icon}/>{preview(t.customer_id)?.vehicle}</small>}</div>
            {scope==='self'&&<button type="button" className="today-open" onClick={()=>setTask(t.id)} aria-label={`Hoàn thành ${t.title}`}><CheckCircle2 {...icon}/></button>}{customerLink(t.customer_id)}
          </article>)}</div>:<div className="today-empty">Chưa có lịch hẹn hoặc lái thử hôm nay.</div>}
        </section>
        <section id="today-next" className="today-section"><div className="today-section-head"><h2><CheckCircle2 {...icon}/> Công việc tiếp theo ({nextTasks.length})</h2><button type="button" onClick={()=>nav('/tasks')}>Xem tất cả <ChevronRight {...icon}/></button></div>
          {nextTasks.length?<div className="today-stack">{nextTasks.map(t=><article className="today-next-row" key={t.id}><span className="today-hour">{timeOnly(t.due_at)}</span><div className="min-w-0 flex-1"><strong>{t.title}</strong><span>{preview(t.customer_id)?.display_name??'Công việc hôm nay'}</span></div>{scope==='self'&&<button type="button" className="today-open" onClick={()=>setTask(t.id)} aria-label={`Hoàn thành ${t.title}`}><CheckCircle2 {...icon}/></button>}{customerLink(t.customer_id)}</article>)}</div>:<div className="today-empty">Không còn công việc sắp tới.</div>}
        </section>
      </div>
      <div className="today-quick-actions"><button type="button" onClick={()=>setCreateTask(true)}><Plus {...icon}/> Thêm việc cần làm</button><button type="button" onClick={()=>setCreateLead(true)}><UserRoundPlus {...icon}/> Nhập lead nhanh</button></div>
      {customers.isError&&<p className="mt-4 text-xs text-slate-500">Không tải được chi tiết liên hệ. Bạn vẫn có thể mở hồ sơ khách hàng.</p>}
    </>}
    <CompleteTaskSheet taskId={task} open={!!task} onClose={()=>setTask(null)}/>
    <CreateTaskSheet open={createTask} onClose={()=>setCreateTask(false)}/>
    <QuickCreateLead open={createLead} onClose={()=>setCreateLead(false)}/>
  </div>
}
