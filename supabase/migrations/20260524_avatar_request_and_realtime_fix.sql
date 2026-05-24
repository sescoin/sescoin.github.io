drop function if exists public.request_avatar_change(uuid, text);
drop function if exists public.approve_avatar_change(uuid);
drop function if exists public.reject_avatar_change(uuid);

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

  delete from public.notifications
  where type = 'system'
    and data->>'action' = 'review_avatar'
    and data->>'user_id' = p_user_id::text;

  insert into public.notifications (user_id, type, title, body, data)
  select
    id,
    'system',
    'Changement de photo demandé',
    v_requester.display_name || ' demande la validation de sa nouvelle photo',
    jsonb_build_object(
      'action', 'review_avatar',
      'user_id', p_user_id,
      'username', v_requester.username,
      'pending_avatar_url', p_pending_avatar_url
    )
  from public.profiles
  where role = 'admin'
    and is_banned = false
    and id <> p_user_id;
end;
$$;

create or replace function public.approve_avatar_change(p_user_id uuid)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if not public.current_profile_is_admin() then
    raise exception 'Action reservee a l''administrateur.';
  end if;

  update public.profiles
  set avatar_url = pending_avatar_url,
      pending_avatar_url = null,
      updated_at = now()
  where id = p_user_id and pending_avatar_url is not null;

  delete from public.notifications
  where type = 'system'
    and data->>'action' = 'review_avatar'
    and data->>'user_id' = p_user_id::text;

  insert into public.notifications (user_id, type, title, body, data)
  values (
    p_user_id,
    'system',
    'Photo de profil acceptée',
    'Ta nouvelle photo de profil a été acceptée',
    jsonb_build_object('action', 'avatar_approved')
  );
end;
$$;

create or replace function public.reject_avatar_change(p_user_id uuid)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if not public.current_profile_is_admin() then
    raise exception 'Action reservee a l''administrateur.';
  end if;

  update public.profiles
  set pending_avatar_url = null,
      updated_at = now()
  where id = p_user_id;

  delete from public.notifications
  where type = 'system'
    and data->>'action' = 'review_avatar'
    and data->>'user_id' = p_user_id::text;

  insert into public.notifications (user_id, type, title, body, data)
  values (
    p_user_id,
    'system',
    'Photo de profil refusée',
    'Ta demande de changement de photo a été refusée',
    jsonb_build_object('action', 'avatar_rejected')
  );
end;
$$;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'marketplace', 'marketplace', true, 5242880,
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
on conflict (id) do update set public = true;

drop policy if exists "marketplace_public_read" on storage.objects;
drop policy if exists "marketplace_auth_write" on storage.objects;
drop policy if exists "marketplace_auth_update" on storage.objects;
drop policy if exists "marketplace_auth_delete" on storage.objects;

create policy "marketplace_public_read" on storage.objects
  for select using (bucket_id = 'marketplace');

create policy "marketplace_auth_write" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'marketplace');

create policy "marketplace_auth_update" on storage.objects
  for update to authenticated
  using (bucket_id = 'marketplace');

create policy "marketplace_auth_delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'marketplace');

grant execute on function public.request_avatar_change(uuid, text) to authenticated;
grant execute on function public.approve_avatar_change(uuid) to authenticated;
grant execute on function public.reject_avatar_change(uuid) to authenticated;
