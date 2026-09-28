import { useEffect } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { isDemoMode } from './config'
import { supabase } from './supabase'

export function useCrmRealtime(userId?:string){
  const qc=useQueryClient()
  useEffect(()=>{
    if(isDemoMode||!supabase||!userId)return
    const client=supabase
    const channel=client.channel(`crm-user-${userId}`)
      .on('postgres_changes',{event:'*',schema:'public',table:'tasks',filter:`assigned_user_id=eq.${userId}`},()=>{qc.invalidateQueries({queryKey:['tasks']});qc.invalidateQueries({queryKey:['today']})})
      .on('postgres_changes',{event:'*',schema:'public',table:'notifications',filter:`user_id=eq.${userId}`},()=>qc.invalidateQueries({queryKey:['notifications']}))
      .subscribe()
    return()=>{client.removeChannel(channel)}
  },[userId,qc])
}
