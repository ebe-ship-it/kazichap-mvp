"use client";
import { useEffect, useRef, useId, type ReactNode, type FormEvent } from "react";
import { X } from "lucide-react";
export function ActionDialog({title,children,busy,onClose,onSubmit,submitLabel}:{title:string;children:ReactNode;busy:boolean;onClose:()=>void;onSubmit:(event:FormEvent<HTMLFormElement>)=>void;submitLabel:string}) {
 const ref=useRef<HTMLDialogElement>(null);const titleId=useId();
 useEffect(()=>{const el=ref.current;el?.showModal();return()=>el?.close();},[]);
 return <dialog className="action-dialog" ref={ref} aria-labelledby={titleId} onCancel={event=>{event.preventDefault();if(!busy)onClose();}}><form onSubmit={onSubmit}><div className="section-head"><h2 id={titleId}>{title}</h2><button type="button" aria-label="Close dialog" className="btn btn-ghost" disabled={busy} onClick={onClose}><X size={18}/></button></div>{children}<button className="btn btn-primary full" disabled={busy}>{busy?"Please wait…":submitLabel}</button></form></dialog>;
}
