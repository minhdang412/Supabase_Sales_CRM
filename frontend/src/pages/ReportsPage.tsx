import { useQuery } from '@tanstack/react-query'
import { BarChart3, CalendarDays, Target, TrendingUp, UsersRound } from 'lucide-react'
import { useState } from 'react'
import { Button, Card, EmptyState, PageTitle, Skeleton } from '../components/UI'
import { getReports } from '../lib/api'
import { localDate } from '../lib/format'

export function ReportsPage(){
  const today=new Date()
  const first=new Date(today.getFullYear(),today.getMonth(),1)
  const [from,setFrom]=useState(localDate(first))
  const [to,setTo]=useState(localDate(today))
  const valid=!!from&&!!to&&from<=to
  const q=useQuery({queryKey:['reports',from,to],queryFn:()=>getReports(from,to),enabled:valid})
  const max=Math.max(1,...(q.data?.funnel.map(x=>x.reached_count)??[]))
  const leadTotal=q.data?.sources.reduce((sum,x)=>sum+x.lead_count,0)??0
  const wonTotal=q.data?.sources.reduce((sum,x)=>sum+x.won_count,0)??0
  const quotedTotal=q.data?.sources.reduce((sum,x)=>sum+x.quoted_count,0)??0
  const kpis=[{label:'Tổng lead',value:leadTotal,icon:UsersRound},{label:'Đã báo giá',value:quotedTotal,icon:BarChart3},{label:'Thành công',value:wonTotal,icon:Target}]
  return <div className="page">
    <PageTitle title="Báo cáo" subtitle="Theo dõi nguồn khách và tiến độ chuyển đổi." actions={<div className="date-range"><CalendarDays className="hidden h-4 w-4 text-slate-400 sm:block" strokeWidth={1.75}/><input aria-label="Từ ngày" type="date" value={from} onChange={e=>setFrom(e.target.value)}/><span>—</span><input aria-label="Đến ngày" type="date" value={to} onChange={e=>setTo(e.target.value)}/></div>}/>
    {!valid?<EmptyState title="Khoảng ngày không hợp lệ" description="Chọn ngày bắt đầu không muộn hơn ngày kết thúc."/>:q.isLoading?<Skeleton lines={10}/>:q.isError?<EmptyState title="Không tải được báo cáo" description={q.error.message} action={<Button onClick={()=>q.refetch()}>Thử lại</Button>}/>:q.data&&<>
      <div className="grid gap-3 sm:grid-cols-3">{kpis.map(k=><Card key={k.label} className="flex items-center justify-between gap-4"><div><span className="text-[11px] font-semibold uppercase tracking-wider text-slate-400">{k.label}</span><strong className="mt-2 block text-2xl font-semibold tracking-tight text-slate-900">{k.value.toLocaleString('vi-VN')}</strong></div><span className="grid h-10 w-10 place-items-center rounded-xl bg-emerald-50 text-emerald-700"><k.icon className="h-5 w-5" strokeWidth={1.75}/></span></Card>)}</div>
      <div className="report-grid mt-5">
        <Card><div className="mb-6 flex items-center gap-2"><TrendingUp className="h-5 w-5 text-emerald-600" strokeWidth={1.75}/><h2>Phễu bán hàng</h2></div><div className="funnel">{q.data.funnel.map(x=><div key={x.stage_code}><div><span>{x.stage_name}</span><strong>{x.reached_count.toLocaleString('vi-VN')}</strong></div><div className="bar"><i style={{width:`${x.reached_count?Math.max(4,x.reached_count/max*100):0}%`}}/></div></div>)}</div></Card>
        <Card className="wide"><div className="mb-5"><h2>Hiệu quả theo nguồn khách</h2><p className="mt-1 text-xs text-slate-400">Số liệu trong khoảng thời gian đã chọn</p></div><div className="table-wrap"><table><thead><tr><th>Nguồn</th><th>Lead</th><th>Đã xử lý</th><th>Báo giá</th><th>Cọc</th><th>Thành công</th><th>Phản hồi TB</th></tr></thead><tbody>{q.data.sources.map(x=><tr key={x.source_id}><td><strong className="font-semibold text-slate-800">{x.source_name}</strong></td><td>{x.lead_count}</td><td>{x.responded_count}</td><td>{x.quoted_count}</td><td>{x.deposit_count}</td><td>{x.won_count}</td><td>{x.avg_response_minutes!=null?`${x.avg_response_minutes} phút`:'—'}</td></tr>)}</tbody></table></div></Card>
      </div>
    </>}
  </div>
}
