import { useEffect, useState } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { createQuote, markQuoteSent } from '../lib/api'
import { Button } from './UI'
import { Sheet } from './Sheet'

export function QuoteSheet({open,onClose,opportunityId}:{open:boolean;onClose:()=>void;opportunityId:string}) {
  const [list,setList]=useState('')
  const [discount,setDiscount]=useState('')
  const [final,setFinal]=useState('')
  const [promo,setPromo]=useState('')
  const [send,setSend]=useState(true)
  const [busy,setBusy]=useState(false)
  const [createdId,setCreatedId]=useState<string|null>(null)
  const [err,setErr]=useState('')
  useEffect(()=>{setCreatedId(null);setErr('')},[opportunityId])
  const qc=useQueryClient()
  const calc=()=>{if(final)return Number(final);if(list)return Math.max(0,Number(list)-Number(discount||0));return undefined}
  const save=async()=>{
    setBusy(true)
    setErr('')
    try{
      const id=createdId ?? await createQuote({opportunityId,listPrice:list?Number(list):undefined,discountAmount:discount?Number(discount):undefined,finalPrice:calc(),promotionNote:promo})
      setCreatedId(id)
      if(send)await markQuoteSent(id)
      await Promise.all([qc.invalidateQueries({queryKey:['customer']}),qc.invalidateQueries({queryKey:['pipeline']})])
      onClose();setList('');setDiscount('');setFinal('');setPromo('');setCreatedId(null)
    }catch(e){setErr(e instanceof Error?e.message:'Không thể lưu báo giá')
    }finally{setBusy(false)}
  }
  return <Sheet open={open} onClose={onClose} title="Tạo báo giá">
    <div className="form-stack">
      <label>Giá niêm yết<input type="number" inputMode="numeric" disabled={!!createdId} value={list} onChange={e=>setList(e.target.value)}/></label>
      <label>Giảm / ưu đãi<input type="number" inputMode="numeric" disabled={!!createdId} value={discount} onChange={e=>setDiscount(e.target.value)}/></label>
      <label>Giá cuối<input type="number" inputMode="numeric" disabled={!!createdId} value={final} onChange={e=>setFinal(e.target.value)} placeholder={calc()?.toString()||''}/></label>
      <label>Ưu đãi / Quà<textarea rows={3} disabled={!!createdId} value={promo} onChange={e=>setPromo(e.target.value)}/></label>
      <label className="checkline"><input type="checkbox" checked={send} onChange={e=>setSend(e.target.checked)}/><span>Đánh dấu đã gửi ngay sau khi tạo</span></label>
      {err&&<div className="form-error">{createdId?'Báo giá đã được tạo. Thử lại để đánh dấu đã gửi, không tạo bản mới. ':''}{err}</div>}
      <Button disabled={busy} onClick={save}>{busy?'Đang lưu...':createdId?'Thử đánh dấu đã gửi':'Tạo báo giá'}</Button>
    </div>
  </Sheet>
}
