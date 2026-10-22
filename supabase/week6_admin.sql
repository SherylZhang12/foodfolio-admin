-- Run as the database owner in the existing Foodfolio Supabase SQL Editor.
begin;
alter table public.profiles add column if not exists is_superadmin boolean not null default false;

-- Prevent an ordinary profile update/insert from promoting its own account.
create or replace function public.foodfolio_protect_admin_flag()
returns trigger language plpgsql set search_path = '' as $$
begin
  if current_user not in ('postgres','supabase_admin','service_role') then
    if (TG_OP = 'INSERT' and new.is_superadmin) then
      raise exception 'Administrator role can only be assigned by the database owner';
    end if;
    if TG_OP = 'UPDATE' then
      if new.is_superadmin is distinct from old.is_superadmin then
        raise exception 'Administrator role can only be assigned by the database owner';
      end if;
    end if;
  end if;
  return new;
end; $$;
drop trigger if exists foodfolio_admin_flag_guard on public.profiles;
create trigger foodfolio_admin_flag_guard before insert or update on public.profiles
for each row execute function public.foodfolio_protect_admin_flag();

create or replace function public.foodfolio_is_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.profiles p
    where p.id = auth.uid() and p.is_superadmin = true)
    and exists(select 1 from auth.identities i where i.user_id=auth.uid() and i.provider='google');
$$;
revoke all on function public.foodfolio_is_admin() from public, anon;
grant execute on function public.foodfolio_is_admin() to authenticated;

drop policy if exists foodfolio_admin_photo_read on storage.objects;
create policy foodfolio_admin_photo_read on storage.objects for select to authenticated
using (bucket_id='food-photos' and public.foodfolio_is_admin());

create or replace function public.foodfolio_admin_data()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare result jsonb;
begin
  if not public.foodfolio_is_admin() then raise exception 'Forbidden' using errcode='42501'; end if;
  select jsonb_build_object(
    'profiles',(select coalesce(jsonb_agg(x order by x.created_at desc),'[]'::jsonb) from
      (select u.id,u.email,u.created_at,p.first_name,p.last_name,p.avatar_path,coalesce(p.is_superadmin,false) as is_superadmin from auth.users u left join public.profiles p on p.id=u.id) x),
    'media',(select coalesce(jsonb_agg(x order by x.created_at desc),'[]'::jsonb) from
      (select id,user_id,dish,caption,tone,model,created_at,published_at,original_path,image_path from public.caption_generations) x),
    'votes',(select coalesce(jsonb_agg(x order by x.created_at desc),'[]'::jsonb) from public.caption_votes x),
    'preferences',(select coalesce(jsonb_agg(x order by x.updated_at desc),'[]'::jsonb) from public.user_food_preferences x),
    'sample_ratings',(select coalesce(jsonb_agg(x order by x.updated_at desc),'[]'::jsonb) from public.favorite_food_ratings x),
    'stats',jsonb_build_object(
      'users',(select count(*) from auth.users),
      'media',(select count(*) from public.caption_generations),
      'published',(select count(*) from public.caption_generations where published_at is not null),
      'upvotes',(select count(*) from public.caption_votes where value=1),
      'downvotes',(select count(*) from public.caption_votes where value=-1),
      'preferences',(select count(*) from public.user_food_preferences)),
    'personas',(select coalesce(jsonb_agg(x order by x.count desc),'[]'::jsonb) from (select tone as name,count(*) as count from public.caption_generations group by tone) x),
    'daily',(select jsonb_agg(x order by x.day) from (select to_char(d,'YYYY-MM-DD') as day,(select count(*) from public.caption_generations c where (c.created_at at time zone 'UTC')::date=d::date) as count from generate_series((now() at time zone 'UTC')::date-6,(now() at time zone 'UTC')::date,'1 day'::interval) d) x)
  ) into result;
  return result;
end; $$;
revoke all on function public.foodfolio_admin_data() from public, anon;
grant execute on function public.foodfolio_admin_data() to authenticated;

create or replace function public.foodfolio_admin_save_media(p_id uuid,p_dish text,p_caption text,p_tone text,p_model text,p_prompt text,p_system text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare saved uuid;
begin
  if not public.foodfolio_is_admin() then raise exception 'Forbidden' using errcode='42501'; end if;
  if p_dish is null or char_length(trim(p_dish)) not between 1 and 80
    or p_caption is null or char_length(trim(p_caption)) not between 1 and 800
    or p_model is null or char_length(trim(p_model)) not between 1 and 100
    or p_tone is null or p_tone not in ('Gordon Ramsay','Cat','Dog') then
    raise exception 'Invalid media fields' using errcode='22023';
  end if;
  if p_id is null then
    if p_prompt is null or char_length(trim(p_prompt)) not between 1 and 2000 or p_system is null or char_length(trim(p_system)) not between 1 and 4000 then
      raise exception 'Original prompts are required' using errcode='22023';
    end if;
    insert into public.caption_generations(user_id,scene,dish,caption,tone,model,prompt,system_prompt,media_kind)
      values(auth.uid(),'',trim(p_dish),trim(p_caption),p_tone,trim(p_model),p_prompt,p_system,'chef_text') returning id into saved;
  else
    update public.caption_generations set dish=trim(p_dish),caption=trim(p_caption),tone=p_tone,model=trim(p_model)
      where id=p_id returning id into saved;
    if saved is null then raise exception 'Media no longer exists' using errcode='P0002'; end if;
  end if;
  return saved;
end; $$;
revoke all on function public.foodfolio_admin_save_media(uuid,text,text,text,text,text,text) from public, anon;
grant execute on function public.foodfolio_admin_save_media(uuid,text,text,text,text,text,text) to authenticated;

create or replace function public.foodfolio_admin_delete_media(p_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.foodfolio_is_admin() then raise exception 'Forbidden' using errcode='42501'; end if;
  delete from public.caption_generations where id=p_id;
  if not found then raise exception 'Media no longer exists' using errcode='P0002'; end if;
end; $$;
revoke all on function public.foodfolio_admin_delete_media(uuid) from public, anon;
grant execute on function public.foodfolio_admin_delete_media(uuid) to authenticated;
commit;

-- BOOTSTRAP (run separately, after YOUR Google account has signed in once):
-- Copy your exact UUID from Authentication > Users, then run:
-- update public.profiles set is_superadmin=true where id='YOUR-EXACT-USER-UUID';
-- Check the result: select id, first_name, last_name, is_superadmin from public.profiles;
-- Never grant this role automatically to everyone who signs in.
