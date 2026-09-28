import { useState } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { completeTask } from '../lib/api'
import { Button } from './UI'
import { Sheet } from './Sheet'

const nextDate=(days:number)=>{const d=new Date();d.setDate(d.getDate()+days);d.setHours(9,0,0,0);return d.toISOString()}
export function CompleteTaskSheet({taskId,open,onClose}:{taskId:string|null;open:boolean;onClose:()=>void}){
  const[result,setResult]=useState('connected');const[note,setNote]=useState('');const[next,setNext]=useState('1');const[busy,setBusy]=useState(false);const[err,setErr]=useState('');const qc=useQueryClient()
  const save=async()=>{if(!taskId)return;setBusy(true);setErr('');try{const nextDue=next==='none'?null:nextDate(Number(next));await completeTask(taskId,{result,note,nextDueAt:nextDue});await Promise.all([qc.invalidateQueries({queryKey:['today']}),qc.invalidateQueries({queryKey:['tasks']}),qc.invalidateQueries({queryKey:['customer']})]);onClose()}catch(e){setErr(e instanceof Error?e.message:'Không thể hoàn thành công việc')}finally{setBusy(false)}}
  return <Sheet open={open} onClose={onClose} title="Hoàn thành công việc"><div className="form-stack">
    <label>Kết quả<select value={result} onChange={e=>setResult(e.target.value)}><option value="connected">Đã liên hệ được</option><option value="no_answer">Không nghe máy</option><option value="busy">Máy bận</option><option value="call_back">Hẹn gọi lại</option><option value="not_interested">Không còn nhu cầu</option></select></label>
    <label>Ghi chú<textarea value={note} onChange={e=>setNote(e.target.value)} rows={3} placeholder="Ghi ngắn nội dung cần nhớ"/></label>
    <fieldset><legend>Việc tiếp theo</legend><div className="choice-grid">{[['1','Ngày mai'],['2','2 ngày nữa'],['7','7 ngày nữa'],['none','Chưa cần']].map(([v,l])=><button type="button" key={v} className={next===v?'selected':''} onClick={()=>setNext(v)}>{l}</button>)}</div></fieldset>
    {err&&<div className="form-error">{err}</div>}
    <Button disabled={busy} onClick={save}>{busy?'Đang lưu...':'Hoàn thành'}</Button>
  </div></Sheet>
}
