import { useInfiniteQuery, useQuery } from '@tanstack/react-query'
import { ArrowUpRight, Clock3, Filter, Plus, Search, UsersRound, CalendarClock, CarFront } from 'lucide-react'
import { useMemo, useState } from 'react'
import { useNavigate, useSearchParams } from 'react-router-dom'
import { QuickCreateLead } from '../components/QuickCreateLead'
import { Sheet } from '../components/Sheet'
import { Badge, Button, Card, EmptyState, PageTitle, PriorityBadge, Skeleton } from '../components/UI'
import { getMasterData, searchCustomers } from '../lib/api'
import { potentialLabel, relativeTime } from '../lib/format'

type QuickFilter='all'|'hot'|'high'|'no_next'|'stale'
const quickFilters:Array<{key:QuickFilter;label:string}>=[
  {key:'all',label:'Tất cả'},
  {key:'hot',label:'Khách nóng'},
  {key:'high',label:'Ưu tiên cao'},
  {key:'no_next',label:'Chưa có việc tiếp theo'},
  {key:'stale',label:'Lâu chưa chăm'},
]

export function CustomersPage(){
  const [params]=useSearchParams()
  const [qv,setQv]=useState(params.get('q')??'')
  const [add,setAdd]=useState(false)
  const [filterOpen,setFilterOpen]=useState(false)
  const [quickFilter,setQuickFilter]=useState<QuickFilter>('all')
  const [sourceId,setSourceId]=useState('')
  const [stageId,setStageId]=useState('')
  const nav=useNavigate()
  const master=useQuery({queryKey:['master-data'],queryFn:getMasterData,staleTime:120000})
  const pageSize=25
  const q=useInfiniteQuery({
    queryKey:['customers',qv,quickFilter,sourceId,stageId],
    initialPageParam:0,
    queryFn:({pageParam})=>searchCustomers(qv,{quickFilter,sourceId:sourceId||undefined,stageId:stageId||undefined,limit:pageSize,offset:pageParam}),
    getNextPageParam:(lastPage,pages)=>lastPage.length===pageSize?pages.length*pageSize:undefined,
    staleTime:30000,
  })
  const customers=q.data?.pages.flat()??[]
  const filterCount=useMemo(()=>Number(Boolean(sourceId))+Number(Boolean(stageId)),[sourceId,stageId])
  const clearAdvanced=()=>{setSourceId('');setStageId('')}

  return <div className="page">
    <PageTitle title="Khách hàng" subtitle="Theo dõi khách, nhu cầu và lịch chăm sóc tại một nơi." actions={<Button onClick={()=>setAdd(true)}><Plus className="h-4 w-4" strokeWidth={1.75}/> Thêm khách</Button>}/>
    <div className="search-row">
      <label className="searchbox"><Search className="h-5 w-5" strokeWidth={1.75}/><input aria-label="Tìm khách hàng" value={qv} onChange={e=>setQv(e.target.value)} placeholder="Tên, SĐT, Facebook..."/></label>
      <Button variant="secondary" className={filterCount?'filter-active':''} onClick={()=>setFilterOpen(true)}><Filter className="h-4 w-4" strokeWidth={1.75}/> Bộ lọc{filterCount? ` (${filterCount})`:''}</Button>
    </div>
    <div className="chips customer-quick-filters" role="group" aria-label="Lọc nhanh">
      {quickFilters.map(f=><button key={f.key} className={quickFilter===f.key?'active':''} onClick={()=>setQuickFilter(f.key)}>{f.label}</button>)}
    </div>
    <div className="section-title mt-3"><h2><UsersRound className="h-5 w-5" strokeWidth={1.75}/> Danh sách khách hàng</h2><span>{q.isLoading?'Đang tải...':`${customers.length} khách`}</span></div>

    {q.isLoading?<Skeleton lines={8}/>:q.isError&&!customers.length?<EmptyState title="Không tải được khách hàng" description={q.error.message} action={<Button onClick={()=>q.refetch()}>Thử lại</Button>}/>:customers.length?<div className="customer-list">
      {customers.map(c=><Card className={`customer-card ${c.active_opportunity?.potential_level==='hot'?'customer-card-hot':!c.next_task_at?'customer-card-attention':''}`} key={c.customer_id} onClick={()=>nav(`/customers/${c.customer_id}`)} aria-label={`Mở hồ sơ ${c.display_name}`}>
        <div className="customer-card-head"><div className="customer-main"><div className="avatar soft">{c.display_name.slice(0,1)}</div><div className="grow">
          <strong>{c.display_name}</strong><span>{c.primary_contact||'Chưa có thông tin liên hệ'}</span>
        </div></div><ArrowUpRight className="h-4 w-4 shrink-0 text-slate-400" strokeWidth={1.75}/></div>
        <div className="meta-row"><Badge tone="info">{c.source_name}</Badge>{c.active_opportunity?.potential_level&&<Badge tone={c.active_opportunity.potential_level==='hot'?'hot':c.active_opportunity.potential_level==='potential'?'potential':'neutral'}>{potentialLabel(c.active_opportunity.potential_level)}</Badge>}{c.active_opportunity?.priority==='high'&&<PriorityBadge value="high"/>}</div>
        {c.active_opportunity?.product_id&&<div className="customer-vehicle"><CarFront className="h-4 w-4" strokeWidth={1.75}/><span>{master.data?.products.find(p=>p.id===c.active_opportunity?.product_id)?.name??'Xe đang quan tâm'}</span></div>}
        <div className="customer-card-foot"><span><Clock3 className="h-4 w-4" strokeWidth={1.75}/> {relativeTime(c.last_activity_at)}</span><span className={!c.next_task_at?'needs-task':''}><CalendarClock className="h-4 w-4" strokeWidth={1.75}/> {c.next_task_at?`Việc tiếp theo ${new Intl.DateTimeFormat('vi-VN',{day:'2-digit',month:'2-digit'}).format(new Date(c.next_task_at))}`:'Chưa có việc tiếp theo'}</span></div>
      </Card>)}
      {q.isFetchNextPageError&&<div className="form-error">Không tải được trang tiếp theo: {q.error?.message}</div>}
      {q.hasNextPage&&<div className="flex justify-center pt-3"><Button variant="secondary" disabled={q.isFetchingNextPage} onClick={()=>q.fetchNextPage()}>{q.isFetchingNextPage?'Đang tải...':'Xem thêm khách hàng'}</Button></div>}
    </div>:<EmptyState title="Chưa có khách phù hợp" description="Thử đổi bộ lọc hoặc từ khóa tìm kiếm." action={<Button onClick={()=>{setQuickFilter('all');clearAdvanced();setQv('')}}>Xóa bộ lọc</Button>}/>}

    <Sheet open={filterOpen} onClose={()=>setFilterOpen(false)} title="Bộ lọc khách hàng"><div className="form-stack">
      {master.isError&&<div className="form-error">Không tải được danh mục: {master.error.message}</div>}
      <label>Nguồn khách<select value={sourceId} onChange={e=>setSourceId(e.target.value)}><option value="">Tất cả nguồn</option>{(master.data?.sources??[]).map(s=><option key={s.id} value={s.id}>{s.name}</option>)}</select></label>
      <label>Giai đoạn<select value={stageId} onChange={e=>setStageId(e.target.value)}><option value="">Tất cả giai đoạn</option>{(master.data?.stages??[]).map(s=><option key={s.id} value={s.id}>{s.display_name}</option>)}</select></label>
      <div className="filter-sheet-actions"><Button variant="secondary" onClick={clearAdvanced}>Xóa lọc</Button><Button onClick={()=>setFilterOpen(false)}>Áp dụng</Button></div>
    </div></Sheet>
    <QuickCreateLead open={add} onClose={()=>setAdd(false)}/>
  </div>
}
