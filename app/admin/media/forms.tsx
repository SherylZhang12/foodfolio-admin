'use client';
import {useActionState,useEffect,useState} from 'react';
import {createBrowserClient} from '@supabase/ssr';
import {saveMedia,deleteMedia,type Result} from './actions';
import type {Media} from '@/lib/db';
const empty:Result={};
export function MediaForm({item}:{item?:Media}){const [photo,setPhoto]=useState<File|null>(null);const [preview,setPreview]=useState('');
useEffect(()=>{if(!photo){setPreview('');return;}const url=URL.createObjectURL(photo);setPreview(url);return ()=>URL.revokeObjectURL(url);},[photo]);
const [state,action,pending]=useActionState(async(previous:Result,form:FormData):Promise<Result>=>{
const file=form.get('photo');form.delete('photo');let path:string|undefined;
const client=createBrowserClient(process.env.NEXT_PUBLIC_SUPABASE_URL!,process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!);
if(file instanceof File&&file.size){
 const extensions:Record<string,string>={'image/jpeg':'jpg','image/png':'png','image/webp':'webp'};
 if(!extensions[file.type]||file.size>10*1024*1024)return {error:'Choose a JPG, PNG or WebP photo up to 10 MB.'};
 const {data:{user}}=await client.auth.getUser();if(!user)return {error:'Please sign in again before uploading.'};
 path=`${user.id}/admin/${crypto.randomUUID()}.${extensions[file.type]}`;
 const {error}=await client.storage.from('food-photos').upload(path,file,{contentType:file.type,upsert:false});
 if(error)return {error:'Photo upload failed. Please try again.'};form.set('photo_path',path);
}
try{const result=await saveMedia(previous,form);if(result.error&&path)await client.storage.from('food-photos').remove([path]);if(result.success)setPhoto(null);return result;}
catch{if(path)await client.storage.from('food-photos').remove([path]);return {error:'Could not save. Please refresh and try again.'};}
},empty);return <form action={action} className="form"><input type="hidden" name="id" value={item?.id||''}/><label>{item?'Add or replace food photo':'Food photo (optional)'}<input type="file" name="photo" accept="image/jpeg,image/png,image/webp" onChange={event=>setPhoto(event.target.files?.[0]||null)} disabled={pending}/></label><small>JPG, PNG or WebP · up to 10 MB. Uploaded photos stay private.</small>{preview&&<img src={preview} alt="Selected food photo preview" style={{width:'100%',maxHeight:240,objectFit:'contain',borderRadius:10}}/>}<label>Food name<input name="dish" defaultValue={item?.dish} required maxLength={80}/></label><div className="form-row"><label>Character<select name="tone" defaultValue={item?.tone||'Gordon Ramsay'}>{['Gordon Ramsay','Cat','Dog'].map(x=><option key={x}>{x}</option>)}</select></label><label>AI model<input name="model" defaultValue={item?.model} placeholder="Original model name" required maxLength={100}/></label></div><label>AI-generated caption<textarea name="caption" defaultValue={item?.caption} required maxLength={800} rows={4}/></label>{!item&&<><p>Import a real AI-generated reaction. It stays private until published through the main app.</p><label>Original prompt<textarea name="prompt" required maxLength={2000} rows={2}/></label><label>Original system prompt<textarea name="system_prompt" required maxLength={4000} rows={2}/></label></>}<button disabled={pending}>{pending?'Saving…':item?'Save changes':'Create AI media record'}</button>{state.error&&<p role="alert" className="notice">{state.error}</p>}{state.success&&<p role="status">✓ {state.success}</p>}</form>;}
export function DeleteForm({id}:{id:string}){const [state,action,pending]=useActionState(deleteMedia,empty);return <details className="danger"><summary>Delete creation</summary><p>This also deletes linked votes and bookmarks. The original image file is retained.</p><form action={action}><input type="hidden" name="id" value={id}/><label>Type DELETE to confirm<input name="confirm" required pattern="DELETE"/></label><button disabled={pending}>{pending?'Deleting…':'Delete permanently'}</button></form>{state.error&&<p role="alert">{state.error}</p>}{state.success&&<p role="status">{state.success}</p>}</details>;}
