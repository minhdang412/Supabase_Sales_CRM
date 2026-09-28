import { useQuery } from '@tanstack/react-query'
import { CalendarPlus, Plus } from 'lucide-react'
import { useState } from 'react'
import { CompleteTaskSheet } from '../components/CompleteTaskSheet'
import { CreateTaskSheet } from '../components/CreateTaskSheet'
import { ScheduleSheet } from '../components/ScheduleSheet'
import { Button, Card, EmptyState, PageTitle, PriorityBadge, Skeleton } from '../components/UI'
import { getScheduleBlocks, getTasks } from '../lib/api'
import { dateTime } from '../lib/format'
import type { TaskItem } from '../lib/types'

const dayName=(d:number)=>['Chủ Nhật','Thứ Hai','Thứ Ba','Thứ Tư','Thứ Năm','Thứ Sáu','Thứ Bảy'][d]

export function TasksPage(){
  const q=useQuery({queryKey:['tasks'],queryFn:getTasks})
  const schedule=useQuery({queryKey:['schedule'],queryFn:getScheduleBlocks})
  const [task,setTask]=useState<string|null>(null)
  const [create,setCreate]=useState(false)
  const [addBlock,setAddBlock]=useState(false)
  const [tab,setTab]=useState<'today'|'upcoming'|'schedule'>('today')
  const now=new Date()
  const start=new Date(now.getFullYear(),now.getMonth(),now.getDate()).getTime()
  const tomorrow=new Date(now.getFullYear(),now.getMonth(),now.getDate()+1).getTime()
  const overdue=q.data?.filter(t=>Date.parse(t.due_at)<start)??[]
  const today=q.data?.filter(t=>Date.parse(t.due_at)>=start&&Date.parse(t.due_at)<tomorrow)??[]
  const upcoming=q.data?.filter(t=>Date.parse(t.due_at)>=tomorrow)??[]
  const taskCard=(t:TaskItem,late=false)=><Card className={late?'task-card overdue':'task-card'} key={t.id}>
    <div className="grow"><strong>{t.title}</strong><span>{dateTime(t.due_at)}</span></div>
    <PriorityBadge value={t.priority}/>
    <Button variant="secondary" onClick={()=>setTask(t.id)}>Hoàn thành</Button>
  </Card>
  return <div className="page">
    <PageTitle title="Công việc" subtitle="Việc cần làm và lịch làm việc mẫu" actions={<Button onClick={()=>setCreate(true)}><CalendarPlus className="h-4 w-4" strokeWidth={1.75}/> Tạo công việc</Button>}/>
    <div className="tabs">
      <button className={tab==='today'?'active':''} onClick={()=>setTab('today')}>Hôm nay</button>
      <button className={tab==='upcoming'?'active':''} onClick={()=>setTab('upcoming')}>Sắp tới</button>
      <button className={tab==='schedule'?'active':''} onClick={()=>setTab('schedule')}>Lịch làm việc</button>
    </div>
    {tab!=='schedule' && (q.isLoading?<Skeleton lines={8}/>:q.isError?<EmptyState title="Không tải được công việc" description={q.error.message} action={<Button onClick={()=>q.refetch()}>Thử lại</Button>}/>:tab==='today'?<>
      {overdue.length>0&&<section><div className="section-title"><h2>Quá hạn</h2><span>{overdue.length}</span></div><div className="stack">{overdue.map(t=>taskCard(t,true))}</div></section>}
      <section><div className="section-title"><h2>Hôm nay</h2><span>{today.length}</span></div>
        {today.length?<div className="stack">{today.map(t=>taskCard(t))}</div>:<EmptyState title="Không có việc hôm nay" action={<Button onClick={()=>setCreate(true)}>Tạo công việc</Button>}/>}
      </section>
    </>:<section>{upcoming.length?<div className="stack">{upcoming.map(t=>taskCard(t))}</div>:<EmptyState title="Chưa có việc sắp tới"/>}</section>)}
    {tab==='schedule'&&<section><div className="section-title"><h2>Lịch làm việc mẫu</h2><Button variant="secondary" onClick={()=>setAddBlock(true)}><Plus className="h-4 w-4" strokeWidth={1.75}/> Khung giờ</Button></div>
      {schedule.isLoading?<Skeleton lines={7}/>:schedule.isError?<EmptyState title="Không tải được lịch làm việc" description={schedule.error.message} action={<Button onClick={()=>schedule.refetch()}>Thử lại</Button>}/>:<div className="schedule-week">{[1,2,3,4,5,6,0].map(day=><Card key={day} className="schedule-day"><h3>{dayName(day)}</h3>{(schedule.data??[]).filter((b:any)=>b.day_of_week===day).length?(schedule.data??[]).filter((b:any)=>b.day_of_week===day).map((b:any)=><div className="schedule-block" key={b.id}><span>{String(b.start_time).slice(0,5)}–{String(b.end_time).slice(0,5)}</span><strong>{b.title}</strong></div>):<span className="muted">Chưa có khung giờ</span>}</Card>)}</div>}
    </section>}
    <CompleteTaskSheet taskId={task} open={!!task} onClose={()=>setTask(null)}/>
    <CreateTaskSheet open={create} onClose={()=>setCreate(false)}/>
    <ScheduleSheet open={addBlock} onClose={()=>setAddBlock(false)}/>
  </div>
}
