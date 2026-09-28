import { ArrowRight, PanelLeft, ShieldCheck } from 'lucide-react'
import { useState, type FormEvent } from 'react'
import { Navigate } from 'react-router-dom'
import { Button } from '../components/UI'
import { useAuth } from '../context/AuthContext'
import { configError } from '../lib/config'

export function LoginPage(){
  const {profile,signIn,demo}=useAuth()
  const [email,setEmail]=useState('')
  const [pw,setPw]=useState('')
  const [err,setErr]=useState('')
  const [busy,setBusy]=useState(false)
  if(profile)return <Navigate to="/today" replace/>
  const submit=async(event:FormEvent)=>{
    event.preventDefault()
    setBusy(true)
    setErr('')
    try{await signIn(email,pw)}
    catch(e){setErr(e instanceof Error?e.message:'Đăng nhập không thành công')}
    finally{setBusy(false)}
  }
  return <div className="login-page">
    <div className="login-card">
      <div className="login-logo"><PanelLeft className="h-5 w-5" strokeWidth={1.75}/></div>
      <p className="mb-2 text-[11px] font-semibold uppercase tracking-[0.16em] text-emerald-700">Không gian làm việc</p>
      <h1>Chào mừng trở lại</h1>
      <p>Đăng nhập để quản lý khách hàng và công việc hằng ngày.</p>
      {demo&&<div className="demo-login">Đang xem dữ liệu mẫu. Bấm đăng nhập để khám phá giao diện.</div>}
      <form className="form-stack" onSubmit={submit}>
        <label>Email<input type="email" autoComplete="username" required={!demo} value={email} onChange={e=>setEmail(e.target.value)} placeholder="ten@congty.vn"/></label>
        <label>Mật khẩu<input type="password" autoComplete="current-password" required={!demo} value={pw} onChange={e=>setPw(e.target.value)} placeholder="Nhập mật khẩu"/></label>
        {err&&<div className="form-error">{err}</div>}
        {configError&&!demo&&<div className="form-error">{configError}</div>}
        <Button type="submit" className="mt-1 w-full" disabled={busy||!!configError&&!demo}>{busy?'Đang đăng nhập...':demo?'Xem bản Demo':'Đăng nhập'}<ArrowRight className="h-4 w-4" strokeWidth={1.75}/></Button>
      </form>
      <div className="mt-7 flex items-center gap-2 border-t border-slate-100 pt-5 text-xs text-slate-400"><ShieldCheck className="h-4 w-4 text-emerald-600" strokeWidth={1.75}/> Dữ liệu chỉ dành cho đội ngũ được cấp quyền.</div>
    </div>
  </div>
}
