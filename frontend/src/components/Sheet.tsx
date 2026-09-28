import { X } from 'lucide-react'
import { useEffect, type ReactNode } from 'react'

export function Sheet({open,onClose,title,children}:{open:boolean;onClose:()=>void;title:string;children:ReactNode}){
  useEffect(()=>{
    if(!open)return
    const handler=(e:KeyboardEvent)=>{if(e.key==='Escape')onClose()}
    document.addEventListener('keydown',handler)
    return()=>document.removeEventListener('keydown',handler)
  },[open,onClose])
  if(!open)return null
  return <div className="sheet-overlay" onMouseDown={e=>{if(e.target===e.currentTarget)onClose()}}>
    <section className="sheet" role="dialog" aria-modal="true" aria-label={title}>
      <div className="sheet-handle"/>
      <header><h2>{title}</h2><button className="icon-btn" onClick={onClose} aria-label="Đóng"><X className="h-5 w-5" strokeWidth={1.75}/></button></header>
      <div className="sheet-body">{children}</div>
    </section>
  </div>
}
