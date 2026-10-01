import { useQuery } from '@tanstack/react-query'
import { BarChart3, Bell, BriefcaseBusiness, CalendarCheck2, ChevronDown, CircleDollarSign, ContactRound, LayoutDashboard, LogOut, Menu, CarFront, Plus, Settings2, UsersRound } from 'lucide-react'
import { useState } from 'react'
import { NavLink, Outlet, useLocation, useNavigate } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import { getNotifications } from '../lib/api'
import { roleLabel } from '../lib/format'
import { useCrmRealtime } from '../lib/realtime'
import { CreateTaskSheet } from './CreateTaskSheet'
import { NotificationSheet } from './NotificationSheet'
import { QuickCreateLead } from './QuickCreateLead'
import { Sheet } from './Sheet'
import { Button } from './UI'

const primaryNav=[
  {to:'/today',label:'Hôm nay',icon:LayoutDashboard},
  {to:'/customers',label:'Khách hàng',icon:ContactRound},
  {to:'/pipeline',label:'Phễu bán hàng',icon:BriefcaseBusiness},
  {to:'/tasks',label:'Công việc',icon:CalendarCheck2},
]
const secondaryNav=[
  {to:'/quotes',label:'Báo giá',icon:CircleDollarSign},
  {to:'/reports',label:'Báo cáo',icon:BarChart3},
]
const iconProps={className:'h-5 w-5 shrink-0',strokeWidth:1.75}

export function AppShell(){
  const {profile,signOut,demo,setDemoRole}=useAuth()
  const loc=useLocation()
  const navTo=useNavigate()
  const [more,setMore]=useState(false)
  const [add,setAdd]=useState(false)
  const [newTask,setNewTask]=useState(false)
  const [notificationsOpen,setNotificationsOpen]=useState(false)
  const admin=profile?.role==='admin'
  const canManage=profile&&['team_leader','sales_manager','admin'].includes(profile.role)
  useCrmRealtime(profile?.id)
  const notifications=useQuery({queryKey:['notifications'],queryFn:getNotifications,staleTime:30000})
  const unread=(notifications.data??[]).filter((n:any)=>!n.read_at).length
  const section=[...primaryNav,...secondaryNav,{to:'/management',label:'Quản lý'},{to:'/admin',label:'Cài đặt'}].find(n=>loc.pathname.startsWith(n.to))?.label??'Khách hàng'
  const navItem=(n:{to:string;label:string;icon:typeof LayoutDashboard})=><NavLink key={n.to} to={n.to} aria-label={n.label} className={({isActive})=>isActive?'active':''}><n.icon {...iconProps}/><span>{n.to==='/pipeline'?'Phễu':n.label}</span></NavLink>

  return <div className="app-shell">
    <aside className="sidebar">
      <div className="brand"><div className="brand-mark"><CarFront className="h-5 w-5" strokeWidth={1.75}/></div><div><strong>Sales CRM</strong><span>Không gian làm việc</span></div></div>
      <p className="sidebar-section-label">Điều hành</p>
      <nav aria-label="Điều hướng chính">{primaryNav.map(navItem)}</nav>
      <p className="sidebar-section-label mt-8">Phân tích & quản trị</p>
      <nav aria-label="Phân tích và quản trị">
        {secondaryNav.map(navItem)}
        {canManage&&navItem({to:'/management',label:'Quản lý',icon:UsersRound})}
        {admin&&navItem({to:'/admin',label:'Cài đặt',icon:Settings2})}
      </nav>
      <div className="sidebar-spacer"/>
      <button className="notification-button" onClick={()=>setNotificationsOpen(true)}><Bell {...iconProps}/><span>Thông báo</span>{unread>0&&<b>{unread>9?'9+':unread}</b>}</button>
      <div className="sidebar-user"><div className="avatar">{profile?.full_name?.slice(0,1)??'U'}</div><div className="grow"><strong>{profile?.full_name||'Người dùng'}</strong><span>{roleLabel(profile?.role??'')}</span></div><button className="icon-btn" aria-label="Đăng xuất" title="Đăng xuất" onClick={()=>void signOut()}><LogOut className="h-4 w-4" strokeWidth={1.75}/></button></div>
    </aside>

    <main className="main">
      {demo&&<div className="demo-bar"><span>Đang xem dữ liệu mẫu</span><select aria-label="Vai trò Demo" value={profile?.role} onChange={e=>setDemoRole(e.target.value as any)}><option value="sales">Nhân viên</option><option value="team_leader">Trưởng nhóm</option><option value="sales_manager">Trưởng phòng</option><option value="admin">Admin</option></select></div>}
      <div className="topbar">
        <div className="flex min-w-0 items-center gap-3"><div className="grid h-8 w-8 place-items-center rounded-lg bg-emerald-600 text-white lg:hidden"><CarFront className="h-4 w-4" strokeWidth={1.75}/></div><span className="topbar-label hidden sm:inline">Sales CRM</span><ChevronDown className="hidden h-3 w-3 text-slate-300 sm:inline" strokeWidth={1.75}/><span className="truncate text-sm font-semibold text-slate-800">{section}</span></div>
        <div className="topbar-actions"><Button className="hidden lg:inline-flex" onClick={()=>setAdd(true)}><Plus className="h-4 w-4" strokeWidth={1.75}/> Thêm khách</Button><button className="topbar-action" aria-label="Thông báo" onClick={()=>setNotificationsOpen(true)}><Bell className="h-4 w-4" strokeWidth={1.75}/>{unread>0&&<span className="topbar-count">{unread>9?'9+':unread}</span>}</button><div className="avatar ml-1 hidden sm:grid" title={profile?.full_name}>{profile?.full_name?.slice(0,1)??'U'}</div></div>
      </div>
      <Outlet/>
    </main>

    <nav className="bottom-nav" aria-label="Điều hướng trên điện thoại">
      {primaryNav.map(n=><NavLink key={n.to} to={n.to} aria-label={n.label} className={({isActive})=>isActive?'active':''}><n.icon {...iconProps}/><span>{n.to==='/pipeline'?'Phễu':n.label}</span></NavLink>)}
      <button className={more?'active':''} onClick={()=>setMore(true)}><Menu {...iconProps}/><span>Thêm</span></button>
    </nav>
    <Sheet open={more} onClose={()=>setMore(false)} title="Điều hướng & thao tác">
      <div className="menu-list">
        <button onClick={()=>{setMore(false);setAdd(true)}}><Plus {...iconProps}/> Khách mới</button>
        <button onClick={()=>{setMore(false);setNewTask(true)}}><CalendarCheck2 {...iconProps}/> Công việc mới</button>
        <button onClick={()=>{setMore(false);setNotificationsOpen(true)}}><Bell {...iconProps}/> Thông báo {unread>0?`(${unread})`:''}</button>
        <button onClick={()=>{setMore(false);navTo('/quotes')}}><CircleDollarSign {...iconProps}/> Báo giá</button>
        <button onClick={()=>{setMore(false);navTo('/reports')}}><BarChart3 {...iconProps}/> Báo cáo</button>
        {canManage&&<button onClick={()=>{setMore(false);navTo('/management')}}><UsersRound {...iconProps}/> Quản lý</button>}
        {admin&&<button onClick={()=>{setMore(false);navTo('/admin')}}><Settings2 {...iconProps}/> Cài đặt</button>}
        <button onClick={()=>{setMore(false);void signOut()}}><LogOut {...iconProps}/> Đăng xuất</button>
      </div>
    </Sheet>
    <NotificationSheet open={notificationsOpen} onClose={()=>setNotificationsOpen(false)}/>
    <QuickCreateLead open={add} onClose={()=>setAdd(false)}/>
    <CreateTaskSheet open={newTask} onClose={()=>setNewTask(false)}/>
  </div>
}
