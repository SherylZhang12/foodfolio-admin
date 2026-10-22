import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import ts from 'typescript';
function load(path,deps){const module={exports:{}};vm.runInNewContext(ts.transpileModule(fs.readFileSync(path,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText,{module,exports:module.exports,require:n=>{if(!(n in deps))throw Error(n);return deps[n]},process});return module.exports;}
function guard({user={id:'owner'},allowed=true,rpcError=null}={}){const calls=[];const client={auth:{getUser:async()=>({data:{user}})},rpc:async name=>{calls.push(name);return {data:allowed,error:rpcError}}};const api=load('lib/db.ts',{'@supabase/ssr':{createServerClient:()=>client},'next/headers':{cookies:async()=>({getAll:()=>[]})},'next/navigation':{redirect:url=>{throw Error('redirect:'+url)}}});return {api,calls};}
test('signed-out request never queries admin records',async()=>{const {api,calls}=guard({user:null});await assert.rejects(api.adminData(),/redirect:\/login/);assert.equal(calls.length,0)});
test('ordinary user cannot query admin data',async()=>{const {api,calls}=guard({allowed:false});await assert.rejects(api.adminData(),/denied/);assert.equal(calls.includes('foodfolio_admin_data'),false)});
test('role lookup error fails closed',async()=>{const {api}=guard({rpcError:{message:'failure'}});await assert.rejects(api.requireAdmin(),/denied/)});
test('approved admin can proceed',async()=>{const {api,calls}=guard();await api.requireAdmin();assert.equal(calls[0],'foodfolio_is_admin')});
test('direct mutation calls recheck admin before writes',async()=>{let writes=0;const api=load('app/admin/media/actions.ts',{'@/lib/db':{requireAdmin:async()=>{throw Error('forbidden')}},'next/cache':{revalidatePath:()=>writes++}});await assert.rejects(api.saveMedia({},new FormData()),/forbidden/);await assert.rejects(api.deleteMedia({},new FormData()),/forbidden/);assert.equal(writes,0)});
test('all privileged database functions deny nonadmins and revoke public access',()=>{const sql=fs.readFileSync('supabase/week6_admin.sql','utf8');for(const name of ['foodfolio_admin_data','foodfolio_admin_save_media','foodfolio_admin_delete_media']){const fn=sql.split(`function public.${name}(`)[1];assert.match(fn.split('end; $$;')[0],/if not public.foodfolio_is_admin\(\)/);assert.ok(sql.includes(`revoke all on function public.${name}`));}assert.match(sql,/new.is_superadmin is distinct from old.is_superadmin/);assert.match(sql,/i.provider='google'/)});
