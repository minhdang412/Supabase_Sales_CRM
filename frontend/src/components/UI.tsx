import type { ButtonHTMLAttributes, HTMLAttributes, KeyboardEvent, ReactNode } from 'react'
import { AlertCircle, CheckCircle2, Inbox, Flame } from 'lucide-react'

const buttonStyles = {
  primary: 'border-emerald-600 bg-emerald-600 text-white hover:bg-emerald-700 hover:border-emerald-700 focus-visible:ring-emerald-200',
  secondary: 'border-slate-200 bg-white text-slate-700 hover:bg-slate-50 hover:border-slate-300 focus-visible:ring-slate-200',
  ghost: 'border-transparent bg-transparent text-slate-600 hover:bg-slate-100 hover:text-slate-900 focus-visible:ring-slate-200',
  danger: 'border-rose-600 bg-rose-600 text-white hover:bg-rose-700 focus-visible:ring-rose-200',
}

export function Button({className='',variant='primary',type='button',...props}:ButtonHTMLAttributes<HTMLButtonElement>&{variant?:'primary'|'secondary'|'ghost'|'danger'}){
  return <button type={type} className={`btn inline-flex min-h-10 items-center justify-center gap-2 rounded-xl border px-4 py-2.5 text-sm font-semibold shadow-sm transition-all duration-150 active:scale-[0.98] focus-visible:outline-none focus-visible:ring-4 disabled:cursor-not-allowed disabled:opacity-50 disabled:active:scale-100 ${buttonStyles[variant]} ${className}`} {...props}/>
}

export function Card({className='',onClick,onKeyDown,tabIndex,...props}:HTMLAttributes<HTMLDivElement>){
  const interactive=!!onClick
  const handleKeyDown=(event:KeyboardEvent<HTMLDivElement>)=>{
    if(interactive && (event.key==='Enter'||event.key===' ')){event.preventDefault();event.currentTarget.click()}
    onKeyDown?.(event)
  }
  return <div className={`card rounded-2xl border border-slate-200/80 bg-white p-5 shadow-sm shadow-slate-100/70 ${interactive?'cursor-pointer transition-all duration-150 hover:-translate-y-0.5 hover:border-emerald-200 hover:bg-slate-50/50 hover:shadow-md active:scale-[0.99] focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-emerald-100':''} ${className}`} onClick={onClick} onKeyDown={handleKeyDown} role={interactive?'button':undefined} tabIndex={interactive?(tabIndex??0):tabIndex} {...props}/>
}

const badgeStyles={
  neutral:'border-slate-200 bg-slate-50 text-slate-600',
  success:'border-emerald-200 bg-emerald-50 text-emerald-700',
  danger:'border-rose-200 bg-rose-50 text-rose-700',
  hot:'border-rose-300 bg-rose-100 text-rose-800',
  potential:'border-violet-200 bg-violet-50 text-violet-700',
  high:'border-amber-200 bg-amber-50 text-amber-800',
  info:'border-slate-200 bg-white text-slate-700',
}
export function Badge({children,tone='neutral'}:{children:ReactNode;tone?:keyof typeof badgeStyles}){
  return <span className={`badge inline-flex w-fit items-center gap-1 rounded-full border px-2.5 py-1 text-[11px] font-semibold leading-none ${badgeStyles[tone]}`}>{children}</span>
}
export function PriorityBadge({value}:{value:string}){
  return value==='high'?<Badge tone="high"><Flame className="h-3.5 w-3.5" strokeWidth={1.75}/> Cao</Badge>:<Badge>Bình thường</Badge>
}
export function StatusMessage({type,children}:{type:'warning'|'success';children:ReactNode}){
  const Icon=type==='warning'?AlertCircle:CheckCircle2
  return <div className={`flex items-start gap-2.5 rounded-xl border p-3 text-sm ${type==='warning'?'border-amber-200 bg-amber-50 text-amber-800':'border-emerald-200 bg-emerald-50 text-emerald-800'}`}><Icon className="mt-0.5 h-4 w-4 shrink-0" strokeWidth={1.75}/><span>{children}</span></div>
}
export function Skeleton({lines=3}:{lines?:number}){
  return <div className="space-y-3" aria-label="Đang tải">{Array.from({length:lines}).map((_,i)=><div key={i} className="h-16 animate-pulse rounded-2xl border border-slate-100 bg-slate-100/80" style={{width:`${Math.max(56,100-i*5)}%`}}/>)}</div>
}
export function EmptyState({title,description,action}:{title:string;description?:string;action?:ReactNode}){
  return <div className="empty flex min-h-52 flex-col items-center justify-center rounded-2xl border border-dashed border-slate-200 bg-white/70 p-8 text-center"><span className="mb-4 grid h-11 w-11 place-items-center rounded-xl bg-slate-100 text-slate-400"><Inbox className="h-5 w-5" strokeWidth={1.75}/></span><strong className="text-sm font-semibold text-slate-800">{title}</strong>{description&&<p className="mt-1.5 max-w-sm text-sm leading-6 text-slate-500">{description}</p>}{action&&<div className="mt-4">{action}</div>}</div>
}
export function PageTitle({title,subtitle,actions}:{title:string;subtitle?:string;actions?:ReactNode}){
  return <header className="page-title mb-7 flex flex-col justify-between gap-4 border-b border-slate-200/70 pb-6 sm:flex-row sm:items-end"><div className="min-w-0"><p className="mb-2 text-[11px] font-semibold uppercase tracking-[0.16em] text-emerald-700">Không gian bán hàng</p><h1 className="text-[26px] font-semibold tracking-tight text-slate-900 sm:text-[30px]">{title}</h1>{subtitle&&<p className="mt-1.5 text-sm text-slate-500">{subtitle}</p>}</div>{actions&&<div className="page-actions flex shrink-0 flex-wrap items-center gap-2">{actions}</div>}</header>
}
