import { useQuery } from '@tanstack/react-query'
import { ArrowUpRight, Layers3, ChevronRight } from 'lucide-react'
import { useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Badge, Button, Card, EmptyState, PageTitle, PriorityBadge, Skeleton } from '../components/UI'
import { getPipeline } from '../lib/api'
import { potentialLabel } from '../lib/format'

export function PipelinePage(){
  const q=useQuery({queryKey:['pipeline'],queryFn:getPipeline})
  const nav=useNavigate()
  const [selected,setSelected]=useState('all')
  const allCustomers=useMemo(()=>(q.data??[]).flatMap(g=>g.customers.map(c=>({...c,stage:g.stage}))),[q.data])
  const visible=selected==='all'?allCustomers:allCustomers.filter(c=>c.stage.id===selected)
  const selectedStage=q.data?.find(g=>g.stage.id===selected)?.stage
  return <div className="page">
    <PageTitle title="Phễu bán hàng" subtitle="Chọn giai đoạn để theo dõi và cập nhật cơ hội."/>
    {q.isLoading?<Skeleton lines={10}/>:q.isError?<EmptyState title="Không tải được phễu bán hàng" description={q.error.message} action={<Button onClick={()=>q.refetch()}>Thử lại</Button>}/>:q.data?.length?<div className="pipeline-browser">
      <aside className="pipeline-stage-panel" aria-label="Giai đoạn bán hàng">
        <div className="pipeline-stage-panel-title"><Layers3 className="h-4 w-4" strokeWidth={1.75}/><strong>Giai đoạn</strong></div>
        <button className={selected==='all'?'active':''} onClick={()=>setSelected('all')}><span>Tất cả cơ hội</span><b>{allCustomers.length}</b></button>
        {q.data.map(g=><button key={g.stage.id} className={selected===g.stage.id?'active':''} onClick={()=>setSelected(g.stage.id)}><span>{g.stage.display_name}</span><b>{g.customers.length}</b></button>)}
      </aside>
      <div className="pipeline-content">
        <div className="pipeline-stage-scroll" aria-label="Chọn giai đoạn">
          <button className={selected==='all'?'active':''} onClick={()=>setSelected('all')}>Tất cả <b>{allCustomers.length}</b></button>
          {q.data.map(g=><button key={g.stage.id} className={selected===g.stage.id?'active':''} onClick={()=>setSelected(g.stage.id)}>{g.stage.display_name} <b>{g.customers.length}</b></button>)}
        </div>
        <div className="pipeline-content-head">
          <div><p className="mb-1 text-[11px] font-semibold uppercase tracking-wider text-emerald-700">Cơ hội đang theo dõi</p><h2>{selectedStage?.display_name??'Tất cả cơ hội'}</h2><p>{visible.length} hồ sơ · Chọn khách để xem chi tiết</p></div>
          <span className="hidden h-10 w-10 place-items-center rounded-xl border border-slate-200 bg-white text-emerald-700 sm:grid"><Layers3 className="h-5 w-5" strokeWidth={1.75}/></span>
        </div>
        {visible.length?<div className="pipeline-list">{visible.map(c=><Card className={`pipeline-row ${c.opportunity.potential_level==='hot'?'pipeline-row-hot':''}`} key={c.opportunity.id} onClick={()=>nav(`/customers/${c.customer_id}`)} aria-label={`Mở hồ sơ ${c.display_name}`}>
          <div className="pipeline-row-main"><div className="pipeline-row-title"><span className="avatar">{c.display_name.slice(0,1)}</span><div><strong>{c.display_name}</strong><span>{c.source_name||'Chưa rõ nguồn'}</span></div><ChevronRight className="h-4 w-4 text-slate-400" strokeWidth={1.75}/></div><div className="meta-row mt-1">
            <Badge tone="success">{c.stage.display_name}</Badge>
            <Badge tone={c.opportunity.potential_level==='hot'?'hot':c.opportunity.potential_level==='potential'?'potential':'neutral'}>{potentialLabel(c.opportunity.potential_level)}</Badge>
            <PriorityBadge value={c.opportunity.priority}/>
          </div></div><ArrowUpRight className="pipeline-open-icon h-5 w-5" strokeWidth={1.75}/>
        </Card>)}</div>:<EmptyState title="Giai đoạn này chưa có khách" description="Chọn giai đoạn khác để tiếp tục."/>}
      </div>
    </div>:<EmptyState title="Chưa có cơ hội đang hoạt động" description="Khi tạo cơ hội từ hồ sơ khách, dữ liệu sẽ xuất hiện tại đây."/>}
  </div>
}
