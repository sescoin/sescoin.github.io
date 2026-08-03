-- ============================================================
-- RPC : admin_reset_password
--
-- Permet a l'administrateur de redefinir le mot de passe d'un compte depuis
-- l'ecran « Tous les comptes ». Un client ne peut pas modifier le mot de passe
-- d'un autre utilisateur : l'ecriture dans auth.users impose de passer par une
-- fonction SECURITY DEFINER, comme le fait deja approve_account_request.
--
-- Le controle de role se fait DANS la fonction : en SECURITY DEFINER, les
-- policies RLS ne s'appliquent pas, l'appartenance au role admin doit donc
-- etre verifiee explicitement, sans quoi n'importe quel compte connecte
-- pourrait reinitialiser le mot de passe de n'importe qui.
-- ============================================================

create or replace function public.admin_reset_password(
  p_user_id uuid,
  p_new_password text
)
returns void
language plpgsql security definer set search_path = public, auth, extensions
as $$
begin
  if not public.current_profile_is_admin() then
    raise exception 'Action reservee a l''administrateur.';
  end if;

  if p_new_password is null or length(p_new_password) < 8 then
    raise exception 'Le mot de passe doit contenir au moins 8 caracteres.';
  end if;

  if not exists (select 1 from public.profiles where id = p_user_id) then
    raise exception 'Compte introuvable.';
  end if;

  update auth.users
  set encrypted_password = crypt(p_new_password, gen_salt('bf')),
      updated_at = now()
  where id = p_user_id;

  if not found then
    raise exception 'Compte introuvable.';
  end if;
end;
$$;

-- Reserve aux comptes connectes : le controle d'admin a lieu dans le corps.
revoke all on function public.admin_reset_password(uuid, text) from public;
revoke all on function public.admin_reset_password(uuid, text) from anon;
grant execute on function public.admin_reset_password(uuid, text)
  to authenticated;
