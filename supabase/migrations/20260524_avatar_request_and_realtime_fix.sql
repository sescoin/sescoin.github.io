drop function if exists public.request_avatar_change(uuid, text);

create or replace function public.request_avatar_change(
  p_user_id uuid,
  p_pending_avatar_url text
)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_requester public.profiles%rowtype;
begin
  if auth.uid() <> p_user_id and not public.current_profile_is_admin() then
    raise exception 'Action reservee au proprietaire du compte.';
  end if;

  update public.profiles
  set pending_avatar_url = p_pending_avatar_url,
      updated_at = now()
  where id = p_user_id;

  select * into v_requester from public.profiles where id = p_user_id;

  insert into public.notifications (user_id, type, title, body, data)
  select
    id,
    'system',
    'Changement de photo demandé',
    v_requester.display_name || ' demande la validation de sa nouvelle photo',
    jsonb_build_object(
      'action', 'review_avatar',
      'user_id', p_user_id,
      'username', v_requester.username
    )
  from public.profiles
  where role = 'admin'
    and is_banned = false
    and id <> p_user_id;
end;
$$;

grant execute on function public.request_avatar_change(uuid, text) to authenticated;
