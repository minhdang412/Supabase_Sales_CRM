import { useState } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { addActivity } from '../lib/api'
import { Button } from './UI'
import { Sheet } from './Sheet'

const types=[['call','Gọi điện'],['message','Nhắn tin'],['consultation','Tư vấn'],['meeting','Gặp khách'],['test_drive','Lái thử'],['negotiation','Thương lượng'],['note','Ghi chú'],['other','Khác']]
export function AddActivitySheet({open,onClose,customerId,opportunityId}:{open:boolean;onClose:()=>void;customerId:string;opportunityId?:string}){
  const[type,setType]=useState('call');const[result,setResult]=useState('connected');const[note,setNote]=useState('');const[busy,setBusy]=useState(false);const[err,setErr]=useState('');const qc=useQueryClient()
  const save=async()=>{setBusy(true);setErr('');try{await addActivity({customerId,opportunityId,activityType:type,resultCode:result,note});await qc.invalidateQueries({queryKey:['customer',customerId]});onClose();setNote('')}catch(e){setErr(e instanceof Error?e.message:'Không thể lưu tương tác')}finally{setBusy(false)}}
  return <Sheet open={open} onClose={onClose} title="Thêm tương tác"><div className="form-stack"><label>Loại tương tác<select value={type} onChange={e=>setType(e.target.value)}>{types.map(([v,l])=><option key={v} value={v}>{l}</option>)}</select></label>{type==='call'&&<label>Kết quả<select value={result} onChange={e=>setResult(e.target.value)}><option value="connected">Đã liên hệ được</option><option value="no_answer">Không nghe máy</option><option value="busy">Máy bận</option><option value="call_back">Hẹn gọi lại</option><option value="not_interested">Không còn nhu cầu</option></select></label>}<label>Ghi chú<textarea rows={4} value={note} onChange={e=>setNote(e.target.value)} placeholder="Nội dung cần nhớ..."/></label>{err&&<div className="form-error">{err}</div>}<Button disabled={busy} onClick={save}>{busy?'Đang lưu...':'Lưu tương tác'}</Button></div></Sheet>
}
