begin;
create or replace function public.foodfolio_admin_data()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare result jsonb;
begin
  if not public.foodfolio_is_admin() then raise exception 'Forbidden' using errcode='42501'; end if;
  select jsonb_build_object(
    'profiles',(select coalesce(jsonb_agg(x order by x.created_at desc),'[]'::jsonb) from
      (select u.id,u.email,u.created_at,p.first_name,p.last_name,p.avatar_path,coalesce(p.is_superadmin,false) as is_superadmin from auth.users u left join public.profiles p on p.id=u.id) x),
    'media',(select coalesce(jsonb_agg(x order by x.created_at desc),'[]'::jsonb) from
      (select id,user_id,dish,caption,tone,model,created_at,published_at,original_path,image_path,personal_rating,personal_review from public.caption_generations) x),
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

commit;
