import { useQuery, useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'
import { getAssignableUsers, transferCustomer } from '../lib/api'
import { Button } from './UI'
import { Sheet } from './Sheet'

export function TransferCustomerSheet({open,onClose,customerId}:{open:boolean;onClose:()=>void;customerId:string}){
  const q=useQuery({queryKey:['assignable-users'],queryFn:getAssignableUsers,enabled:open})
  const[user,setUser]=useState('');const[reason,setReason]=useState('');const[busy,setBusy]=useState(false);const[err,setErr]=useState('');const qc=useQueryClient()
  const save=async()=>{if(!user)return;setBusy(true);setErr('');try{await transferCustomer(customerId,user,reason);await Promise.all([qc.invalidateQueries({queryKey:['customer',customerId]}),qc.invalidateQueries({queryKey:['customers']}),qc.invalidateQueries({queryKey:['management-dashboard']})]);onClose()}catch(e){setErr(e instanceof Error?e.message:'Không thể chuyển khách')}finally{setBusy(false)}}
  return <Sheet open={open} onClose={onClose} title="Chuyển khách"><div className="form-stack"><label>Nhân viên nhận khách<select value={user} onChange={e=>setUser(e.target.value)}><option value="">Chọn nhân viên</option>{q.data?.filter((u:any)=>u.role==='sales'||u.role==='team_leader').map((u:any)=><option key={u.id} value={u.id}>{u.full_name}</option>)}</select></label><label>Lý do<textarea rows={3} value={reason} onChange={e=>setReason(e.target.value)} placeholder="Không bắt buộc"/></label><div className="status-message warning">Việc chuyển khách sẽ cập nhật người phụ trách hiện tại, nhưng vẫn giữ nguyên người đã tạo các tương tác/báo giá trước đó.</div>{q.isError&&<div className="form-error">{q.error.message}</div>}{err&&<div className="form-error">{err}</div>}<Button disabled={busy||!user||q.isError} onClick={save}>{busy?'Đang chuyển...':'Chuyển khách'}</Button></div></Sheet>
}
