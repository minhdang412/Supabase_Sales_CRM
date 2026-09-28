import { useQuery, useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { createLead, getMasterData } from '../lib/api'
import { Button } from './UI'
import { Sheet } from './Sheet'

export function QuickCreateLead({open,onClose}:{open:boolean;onClose:()=>void}){
  const q=useQuery({queryKey:['master'],queryFn:getMasterData,enabled:open})
  const qc=useQueryClient();const nav=useNavigate()
  const [source,setSource]=useState('');const[name,setName]=useState('');const[contact,setContact]=useState('');const[product,setProduct]=useState('');const[note,setNote]=useState('');const[busy,setBusy]=useState(false);const[err,setErr]=useState('')
  const submit=async()=>{if(!source){setErr('Vui lòng chọn nguồn khách');return}setBusy(true);setErr('');try{const out=await createLead({sourceId:source,displayName:name,contact,productId:product,note});qc.invalidateQueries({queryKey:['customers']});qc.invalidateQueries({queryKey:['today']});onClose();setName('');setContact('');setProduct('');setNote('');if(out?.customer_id)nav(`/customers/${out.customer_id}`)}catch(e:any){setErr(e.message||'Không thể tạo khách')}finally{setBusy(false)}}
  return <Sheet open={open} onClose={onClose} title="Thêm khách">
    <div className="form-stack">
      <label>Nguồn khách <b>*</b><select value={source} onChange={e=>setSource(e.target.value)}><option value="">Chọn nguồn</option>{q.data?.sources.map(x=><option key={x.id} value={x.id}>{x.name}</option>)}</select></label>
      <label>Tên / Tên hiển thị<input value={name} onChange={e=>setName(e.target.value)} placeholder="Ví dụ: Minh Facebook"/></label>
      <label>Thông tin liên hệ<input value={contact} onChange={e=>setContact(e.target.value)} placeholder="Messenger / TikTok / SĐT / Link..."/></label>
      <label>Xe quan tâm<select value={product} onChange={e=>setProduct(e.target.value)}><option value="">Chưa xác định</option>{q.data?.products.map(x=><option key={x.id} value={x.id}>{x.name}</option>)}</select></label>
      <label>Ghi chú<textarea rows={3} value={note} onChange={e=>setNote(e.target.value)} placeholder="Thông tin đầu tiên khách đang hỏi..."/></label>
      {err&&<div className="form-error">{err}</div>}
      <Button disabled={busy||q.isLoading} onClick={submit}>{busy?'Đang lưu...':'Lưu khách'}</Button>
      <p className="form-hint">Chỉ Nguồn khách là bắt buộc. SĐT có thể bổ sung sau.</p>
    </div>
  </Sheet>
}
