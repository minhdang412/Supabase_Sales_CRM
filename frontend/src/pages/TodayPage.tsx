import { useQuery } from '@tanstack/react-query'
import { ArrowUpRight, CalendarClock, ChevronRight, CircleAlert, Clock3, Flame, UserRoundPlus, Zap } from 'lucide-react'
import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { CompleteTaskSheet } from '../components/CompleteTaskSheet'
import { Badge, Button, Card, EmptyState, PageTitle, PriorityBadge, Skeleton } from '../components/UI'
import { useAuth } from '../context/AuthContext'
import { getToday } from '../lib/api'
import { relativeTime, timeOnly } from '../lib/format'

const iconProps={className:'h-5 w-5',strokeWidth:1.75}

export function TodayPage(){
  const {profile}=useAuth()
  const [scope,setScope]=useState('self')
  const [task,setTask]=useState<string|null>(null)
  const nav=useNavigate()
  const q=useQuery({queryKey:['today',scope],queryFn:()=>getToday(scope)})
  const d=q.data
  const manager=profile?.role==='sales_manager'
  const leader=profile?.role==='team_leader'
  const scopeControl=(leader||manager)&&<div className="segmented" role="group" aria-label="Phạm vi tổng quan"><button className={scope==='self'?'active':''} onClick={()=>setScope('self')}>Cá nhân</button><button className={scope!=='self'?'active':''} onClick={()=>setScope(manager?'department':'team')}>{manager?'Phòng':'Nhóm'}</button></div>
  const stats=d?[{label:'Việc cần xử lý',value:d.overview.today_tasks+d.overview.overdue_tasks,icon:CalendarClock},{label:'Đang quá hạn',value:d.overview.overdue_tasks,icon:Clock3,warn:true},{label:'Khách mới hôm nay',value:d.overview.new_leads_today,icon:UserRoundPlus},{label:'Lead ưu tiên',value:d.overview.priority_unhandled,icon:Zap}]:[]

  return <div className="page">
    <PageTitle title="Hôm nay" subtitle={new Intl.DateTimeFormat('vi-VN',{weekday:'long',day:'2-digit',month:'2-digit',year:'numeric'}).format(new Date())} actions={scopeControl}/>
    {q.isLoading?<Skeleton lines={7}/>:q.isError?<EmptyState title="Không tải được Hôm nay" description={q.error.message} action={<Button onClick={()=>q.refetch()}>Thử lại</Button>}/>:d&&<>
      <div className="stats-grid">
        {stats.map(s=><Card key={s.label} className={s.warn?'stat-warn':''}><div className="flex items-center justify-between"><span>{s.label}</span><s.icon {...iconProps} className={`h-5 w-5 ${s.warn?'text-rose-500':'text-emerald-600'}`}/></div><div className="flex items-end justify-between"><strong>{s.value}</strong><ArrowUpRight className="h-4 w-4 text-slate-300" strokeWidth={1.75}/></div></Card>)}
      </div>

      {d.overdue_tasks.length>0&&<section><div className="section-title"><h2><CircleAlert {...iconProps}/> Việc quá hạn</h2><span>{d.overdue_tasks.length} việc cần ưu tiên</span></div><div className="stack">{d.overdue_tasks.map(t=><Card className="task-card overdue" key={t.id}><div className="task-time">{timeOnly(t.due_at)}</div><div className="grow"><strong>{t.title}</strong><span>Hẹn thực hiện {relativeTime(t.due_at)}</span></div><PriorityBadge value={t.priority}/>{scope==='self'&&<Button variant="secondary" onClick={()=>setTask(t.id)}>Xử lý</Button>}</Card>)}</div></section>}

      {d.priority_new_leads.length>0&&<section><div className="section-title"><h2><Zap {...iconProps}/> Khách cần liên hệ</h2><span>Nguồn ưu tiên chưa phản hồi</span></div><div className="lead-grid">{d.priority_new_leads.slice(0,4).map(l=><Card className="lead-card" key={l.id}><div><Badge tone={l.response_sla_minutes&&l.age_minutes>l.response_sla_minutes?'danger':'success'}>{l.source_name}</Badge><h3>{l.display_name}</h3><p>{Math.round(l.age_minutes)} phút trước</p>{l.response_sla_minutes&&l.age_minutes>l.response_sla_minutes&&<span className="sla"><Flame className="h-4 w-4" strokeWidth={1.75}/> Quá SLA {l.response_sla_minutes} phút</span>}</div><Button variant="secondary" onClick={()=>nav(`/customers/${l.id}`)}>Mở hồ sơ <ChevronRight className="h-4 w-4" strokeWidth={1.75}/></Button></Card>)}</div></section>}

      <section><div className="section-title"><h2><CalendarClock {...iconProps}/> Lịch cần làm</h2><span>{d.upcoming_tasks.length} việc trong hôm nay</span></div>{d.upcoming_tasks.length?<div className="stack">{d.upcoming_tasks.slice(0,8).map(t=><Card className="task-card" key={t.id}><div className="task-time">{timeOnly(t.due_at)}</div><div className="grow"><strong>{t.title}</strong><span>{relativeTime(t.due_at)}</span></div><PriorityBadge value={t.priority}/>{scope==='self'&&<Button variant="secondary" onClick={()=>setTask(t.id)}>Hoàn thành</Button>}</Card>)}</div>:<EmptyState title="Hôm nay chưa có việc sắp tới" description="Các công việc đã lên lịch sẽ xuất hiện ở đây."/>}</section>
    </>}
    <CompleteTaskSheet taskId={task} open={!!task} onClose={()=>setTask(null)}/>
  </div>
}
