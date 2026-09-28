import { createContext, useContext, useEffect, useMemo, useState, type ReactNode } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import type { Profile, Role } from '../lib/types'
import { isDemoMode } from '../lib/config'
import { demoProfiles } from '../lib/demo'
import { supabase } from '../lib/supabase'

interface AuthValue {
  profile: Profile | null
  loading: boolean
  demo: boolean
  signIn: (email:string,password:string)=>Promise<void>
  signOut: ()=>Promise<void>
  setDemoRole: (role:Role)=>void
}
const AuthContext=createContext<AuthValue | null>(null)

export function AuthProvider({children}:{children:ReactNode}){
  const queryClient=useQueryClient()
  const [profile,setProfile]=useState<Profile|null>(isDemoMode?demoProfiles.sales:null)
  const [loading,setLoading]=useState(!isDemoMode)

  useEffect(()=>{
    if(isDemoMode||!supabase){setLoading(false);return}
    const client=supabase
    let active=true
    const load=async()=>{
      const {data}=await client.auth.getSession()
      if(!active)return
      if(!data.session){setProfile(null);setLoading(false);return}
      const {data:p,error}=await client.from('profiles').select('id,full_name,role,status,organization_id,department_id,team_id').eq('id',data.session.user.id).single()
      if(active){setProfile(error || p?.status !== 'active' || !p.organization_id ? null : p as Profile);setLoading(false)}
    }
    load()
    const {data:listener}=client.auth.onAuthStateChange((event)=>{
      if(event==='SIGNED_OUT'){queryClient.clear();setProfile(null);setLoading(false)}
      else if(event==='SIGNED_IN'){queryClient.clear();load()}
      else load()
    })
    return()=>{active=false;listener.subscription.unsubscribe()}
  },[queryClient])

  const value=useMemo<AuthValue>(()=>({
    profile,loading,demo:isDemoMode,
    signIn:async(email,password)=>{
      if(isDemoMode){setProfile(demoProfiles.sales);return}
      const {data,error}=await supabase!.auth.signInWithPassword({email:email.trim(),password})
      if(error){
        if(error.code==='invalid_credentials')throw new Error('Email hoặc mật khẩu chưa đúng. Kiểm tra tài khoản trong Supabase Auth của dự án DEV.')
        throw error
      }
      const {data:p,error:profileError}=await supabase!.from('profiles')
        .select('id,full_name,role,status,organization_id,department_id,team_id').eq('id',data.user.id).maybeSingle()
      if(profileError){await supabase!.auth.signOut();throw new Error('Không tải được hồ sơ CRM. Vui lòng thử lại.')}
      if(!p||p.status!=='active'||!p.organization_id){
        await supabase!.auth.signOut()
        throw new Error('Tài khoản CRM chưa được kích hoạt hoặc đang bị khóa. Liên hệ Admin.')
      }
      queryClient.clear()
      setProfile(p as Profile)
      setLoading(false)
    },
    signOut:async()=>{if(!isDemoMode)await supabase!.auth.signOut();queryClient.clear();setProfile(isDemoMode?demoProfiles.sales:null)},
    setDemoRole:(role)=>{if(isDemoMode){queryClient.clear();setProfile(demoProfiles[role])}}
  }),[profile,loading,queryClient])
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export const useAuth=()=>{const v=useContext(AuthContext);if(!v)throw new Error('AuthProvider missing');return v}
