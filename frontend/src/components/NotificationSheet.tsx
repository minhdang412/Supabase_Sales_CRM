import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Bell, Check } from 'lucide-react'
import { getNotifications, markNotificationRead } from '../lib/api'
import { dateTime } from '../lib/format'
import { Sheet } from './Sheet'
import { EmptyState, Skeleton } from './UI'

export function NotificationSheet({open,onClose}:{open:boolean;onClose:()=>void}){
  const qc=useQueryClient()
  const q=useQuery({queryKey:['notifications'],queryFn:getNotifications,enabled:open})
  const m=useMutation({mutationFn:markNotificationRead,onSuccess:()=>qc.invalidateQueries({queryKey:['notifications']})})
  return <Sheet open={open} onClose={onClose} title="Thông báo">
    {m.isError&&<div className="form-error">{m.error.message}</div>}
    {q.isLoading?<Skeleton lines={5}/>:q.isError?<EmptyState title="Không tải được thông báo" description={q.error.message}/>:q.data?.length?<div className="notification-list">{q.data.map((n:any)=><button key={n.id} className={`notification-item ${n.read_at?'':'unread'}`} onClick={()=>!n.read_at&&m.mutate(n.id)}><span className="notification-icon">{n.read_at?<Check className="h-4 w-4" strokeWidth={1.75}/>:<Bell className="h-4 w-4" strokeWidth={1.75}/>}</span><span className="notification-copy"><strong>{n.title}</strong><span>{n.message}</span><small>{dateTime(n.created_at)}</small></span></button>)}</div>:<EmptyState title="Chưa có thông báo"/>}
  </Sheet>
}
