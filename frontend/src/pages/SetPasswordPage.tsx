import { ArrowRight, KeyRound, ShieldCheck } from 'lucide-react'
import { useState, type FormEvent } from 'react'
import { Navigate, Link } from 'react-router-dom'
import { Button } from '../components/UI'
import { useAuth } from '../context/AuthContext'
import { supabase } from '../lib/supabase'

export function SetPasswordPage() {
  const { profile, loading } = useAuth()
  const [password, setPassword] = useState('')
  const [confirm, setConfirm] = useState('')
  const [busy, setBusy] = useState(false)
  const [done, setDone] = useState(false)
  const [error, setError] = useState('')

  if (loading) return <div className="app-loading">Đang xác nhận lời mời...</div>
  if (done) return <Navigate to="/today" replace />

  const submit = async (event: FormEvent) => {
    event.preventDefault()
    setError('')
    if (password.length < 12) { setError('Mật khẩu cần ít nhất 12 ký tự.'); return }
    if (password !== confirm) { setError('Hai lần nhập mật khẩu chưa khớp.'); return }
    if (!supabase) { setError('Chưa cấu hình Supabase.'); return }
    setBusy(true)
    try {
      const { error: updateError } = await supabase.auth.updateUser({ password })
      if (updateError) throw updateError
      setDone(true)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Không thể đặt mật khẩu. Vui lòng thử lại.')
    } finally {
      setBusy(false)
    }
  }

  return <div className="login-page">
    <div className="login-card">
      <div className="login-logo"><KeyRound className="h-5 w-5" strokeWidth={1.75} /></div>
      <p className="mb-2 text-[11px] font-semibold uppercase tracking-[0.16em] text-emerald-700">Kích hoạt tài khoản</p>
      <h1>Đặt mật khẩu</h1>
      <p>Hoàn tất lời mời để đăng nhập Sales CRM những lần sau.</p>
      {!profile ? <div className="form-stack">
        <div className="form-error">Liên kết mời đã hết hạn hoặc chưa được xác thực. Hãy mở lại email mời hoặc liên hệ Admin.</div>
        <Link to="/login" className="text-sm font-medium text-emerald-700">Về trang đăng nhập</Link>
      </div> : <form className="form-stack" onSubmit={submit}>
        <label>Mật khẩu mới<input type="password" autoComplete="new-password" minLength={12} required value={password} onChange={e => setPassword(e.target.value)} placeholder="Ít nhất 12 ký tự" /></label>
        <label>Nhập lại mật khẩu<input type="password" autoComplete="new-password" minLength={12} required value={confirm} onChange={e => setConfirm(e.target.value)} placeholder="Nhập lại mật khẩu" /></label>
        {error && <div className="form-error">{error}</div>}
        <Button type="submit" className="mt-1 w-full" disabled={busy}>{busy ? 'Đang lưu...' : 'Hoàn tất tài khoản'}<ArrowRight className="h-4 w-4" strokeWidth={1.75} /></Button>
      </form>}
      <div className="mt-7 flex items-center gap-2 border-t border-slate-100 pt-5 text-xs text-slate-400"><ShieldCheck className="h-4 w-4 text-emerald-600" strokeWidth={1.75} /> Tài khoản chỉ được cấp quyền bởi Quản trị viên.</div>
    </div>
  </div>
}
