"use client";
import { type FormEvent, useCallback, useEffect, useRef, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { ArrowLeft, Send } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { errorMessage } from "@/lib/validation";
import { useRefresh } from "@/lib/use-refresh";
import { Logo } from "@/components/logo";
type Message={id:string;sender_id:string;body:string;created_at:string};
type Conversation={id:string;engagement_id:string;customer_id:string;provider_id:string};
export default function ChatPage(){
 const {conversationId}=useParams<{conversationId:string}>();const router=useRouter();const supabase=createClient();
 const [conversation,setConversation]=useState<Conversation|null>(null);const [messages,setMessages]=useState<Message[]>([]);const [me,setMe]=useState('');const [error,setError]=useState('');const [busy,setBusy]=useState(false);const [body,setBody]=useState('');const end=useRef<HTMLDivElement>(null);
 const load=useCallback(async()=>{const {data:{user}}=await supabase.auth.getUser();if(!user){router.replace('/login');return;}setMe(user.id);
 const {data:c,error:ce}=await supabase.from('conversations').select('id,engagement_id,customer_id,provider_id').eq('id',conversationId).single();if(ce)throw new Error('Conversation not found, or you do not have access.');setConversation(c as Conversation);
 const {data:m,error:msgError}=await supabase.from('messages').select('id,sender_id,body,created_at').eq('conversation_id',conversationId).order('created_at',{ascending:false}).order('id',{ascending:false}).limit(300);if(msgError)throw msgError;setMessages(((m||[]) as Message[]).reverse());},[conversationId,router,supabase]);
 useRefresh(load,setError,5000);
 useEffect(()=>{const channel=supabase.channel(`chat:${conversationId}`).on('postgres_changes',{event:'INSERT',schema:'public',table:'messages',filter:`conversation_id=eq.${conversationId}`},()=>{void load().catch(e=>setError(errorMessage(e)));}).subscribe();return()=>{void supabase.removeChannel(channel);};},[supabase,conversationId,load]);
 const lastMessageId=messages.at(-1)?.id;
 useEffect(()=>{end.current?.scrollIntoView({behavior:'auto'});},[lastMessageId]);
 async function send(event:FormEvent<HTMLFormElement>){event.preventDefault();if(busy||!conversation||!body.trim())return;setBusy(true);setError('');try{const {error}=await supabase.from('messages').insert({conversation_id:conversationId,sender_id:me,body:body.trim()});if(error)throw error;setBody('');await load();}catch(e){setError(errorMessage(e));}finally{setBusy(false);}}
 return <main className="chat-layout"><header className="chat-head"><div className="shell row between"><div className="row"><button aria-label="Back to dashboard" className="btn btn-ghost" onClick={()=>router.push('/dashboard')}><ArrowLeft size={16}/></button><Logo/></div>{conversation&&<button className="btn btn-secondary" onClick={()=>router.push(`/match/${conversation.engagement_id}`)}>Open match</button>}</div></header><section className="messages" aria-label="Conversation">{error&&<div className="error" role="alert">{error}</div>}{messages.length>=300&&<p className="muted tiny">Showing the latest 300 messages.</p>}{messages.length?messages.map(m=><div key={m.id} className={`bubble ${m.sender_id===me?'mine':''}`}><span className="tiny muted">{m.sender_id===me?'You':'Other participant'}</span><div>{m.body}</div><time dateTime={m.created_at}>{new Date(m.created_at).toLocaleString()}</time></div>):<div className="empty">{conversation?'Start the conversation. Keep job agreements here.':'Loading conversation…'}</div>}<div ref={end}/></section><footer className="composer"><form onSubmit={send}><input className="input" aria-label="Your message" value={body} maxLength={2000} onChange={e=>setBody(e.target.value)} autoComplete="off" placeholder="Write a message…" disabled={!conversation||busy}/><button className="btn btn-primary" aria-label="Send message" disabled={busy||!conversation||!body.trim()}><Send size={18}/></button></form></footer></main>;
}
