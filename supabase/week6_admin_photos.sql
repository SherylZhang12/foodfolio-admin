begin;
create or replace function public.foodfolio_admin_save_media(p_id uuid,p_dish text,p_caption text,p_tone text,p_model text,p_prompt text,p_system text,p_photo text)
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
  if p_photo is not null then
    if p_photo not like auth.uid()::text || '/admin/%' or not exists(
      select 1 from storage.objects where bucket_id='food-photos' and name=p_photo
        and metadata->>'mimetype' in ('image/jpeg','image/png','image/webp')
        and (metadata->>'size')::bigint <= 10485760
    ) then raise exception 'Invalid food photo' using errcode='22023'; end if;
  end if;
  if p_id is null then
    if p_prompt is null or char_length(trim(p_prompt)) not between 1 and 2000 or p_system is null or char_length(trim(p_system)) not between 1 and 4000 then
      raise exception 'Original prompts are required' using errcode='22023';
    end if;
    insert into public.caption_generations(user_id,scene,dish,caption,tone,model,prompt,system_prompt,media_kind,original_path)
      values(auth.uid(),'',trim(p_dish),trim(p_caption),p_tone,trim(p_model),p_prompt,p_system,'chef_text',p_photo) returning id into saved;
  else
    update public.caption_generations set dish=trim(p_dish),caption=trim(p_caption),tone=p_tone,model=trim(p_model),original_path=coalesce(p_photo,original_path)
      where id=p_id returning id into saved;
    if saved is null then raise exception 'Media no longer exists' using errcode='P0002'; end if;
  end if;
  return saved;
end; $$;
revoke all on function public.foodfolio_admin_save_media(uuid,text,text,text,text,text,text,text) from public, anon;
grant execute on function public.foodfolio_admin_save_media(uuid,text,text,text,text,text,text,text) to authenticated;

commit;
