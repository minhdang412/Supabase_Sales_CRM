import { lazy, Suspense, type ReactNode } from 'react'
import { Navigate, Route, Routes } from 'react-router-dom'
import { AppShell } from './components/AppShell'
import { useAuth } from './context/AuthContext'

const AdminPage = lazy(() => import('./pages/AdminPage').then(m => ({ default: m.AdminPage })))
const CustomerDetailPage = lazy(() => import('./pages/CustomerDetailPage').then(m => ({ default: m.CustomerDetailPage })))
const CustomersPage = lazy(() => import('./pages/CustomersPage').then(m => ({ default: m.CustomersPage })))
const LoginPage = lazy(() => import('./pages/LoginPage').then(m => ({ default: m.LoginPage })))
const ManagementPage = lazy(() => import('./pages/ManagementPage').then(m => ({ default: m.ManagementPage })))
const NotFoundPage = lazy(() => import('./pages/NotFoundPage').then(m => ({ default: m.NotFoundPage })))
const PipelinePage = lazy(() => import('./pages/PipelinePage').then(m => ({ default: m.PipelinePage })))
const QuotesPage = lazy(() => import('./pages/QuotesPage').then(m => ({ default: m.QuotesPage })))
const ReportsPage = lazy(() => import('./pages/ReportsPage').then(m => ({ default: m.ReportsPage })))
const SetPasswordPage = lazy(() => import('./pages/SetPasswordPage').then(m => ({ default: m.SetPasswordPage })))
const TasksPage = lazy(() => import('./pages/TasksPage').then(m => ({ default: m.TasksPage })))
const TodayPage = lazy(() => import('./pages/TodayPage').then(m => ({ default: m.TodayPage })))

function Protected(){const{profile,loading}=useAuth();if(loading)return <div className="app-loading">Đang tải...</div>;if(!profile)return <Navigate to="/login" replace/>;if(profile.status==='locked')return <div className="locked">Tài khoản đang bị khóa.</div>;return <AppShell/>}
function RoleRoute({children,roles}:{children:ReactNode;roles:string[]}){const{profile}=useAuth();return profile&&roles.includes(profile.role)?children:<Navigate to="/today" replace/>}
export default function App(){return <Suspense fallback={<div className="app-loading">Đang tải...</div>}><Routes><Route path="/login" element={<LoginPage/>}/><Route path="/set-password" element={<SetPasswordPage/>}/><Route element={<Protected/>}><Route index element={<Navigate to="/today" replace/>}/><Route path="/today" element={<TodayPage/>}/><Route path="/customers" element={<CustomersPage/>}/><Route path="/customers/:id" element={<CustomerDetailPage/>}/><Route path="/pipeline" element={<PipelinePage/>}/><Route path="/tasks" element={<TasksPage/>}/><Route path="/quotes" element={<QuotesPage/>}/><Route path="/reports" element={<ReportsPage/>}/><Route path="/management" element={<RoleRoute roles={['team_leader','sales_manager','admin']}><ManagementPage/></RoleRoute>}/><Route path="/admin" element={<RoleRoute roles={['admin']}><AdminPage/></RoleRoute>}/><Route path="*" element={<NotFoundPage/>}/></Route></Routes></Suspense>}
