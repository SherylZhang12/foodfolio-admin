import { createServerClient } from '@supabase/ssr';
import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';

export async function db() {
  const jar = await cookies();
  return createServerClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!, {
    cookies: { getAll: () => jar.getAll(), setAll: values => { try { values.forEach(({name,value,options}) => jar.set(name,value,options)); } catch {} } }
  });
}
export async function requireAdmin() {
  const client = await db();
  const {data:{user},error} = await client.auth.getUser();
  if (error || !user) redirect('/login');
  const {data:allowed,error:denied} = await client.rpc('foodfolio_is_admin');
  if (denied || allowed !== true) redirect('/login?denied=1');
  return {client,user};
}
export async function adminData() {
  const {client,user} = await requireAdmin();
  const {data,error} = await client.rpc('foodfolio_admin_data');
  if (error) throw new Error('Admin data unavailable. Check the Week 6 database migration.');
  return {data:data as AdminData,user};
}
export type Media = {id:string;user_id:string;dish:string;caption:string;tone:string;model:string;created_at:string;published_at:string|null;original_path:string|null;image_path:string|null;personal_rating:number|null;personal_review:string|null};
export type AdminData = {profiles:Record<string,unknown>[];media:Media[];votes:Record<string,unknown>[];preferences:Record<string,unknown>[];sample_ratings:Record<string,unknown>[];stats:{users:number;media:number;published:number;upvotes:number;downvotes:number;preferences:number};personas:{name:string;count:number}[];daily:{day:string;count:number}[]};
