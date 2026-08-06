-- ============================================================
-- Refus a l'envoi des motifs inappropries, et retrait des citations
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- 1. Motifs inappropries : refuser plutot que censurer
--
-- Les declencheurs precedents remplacaient le texte par « Motif censure » :
-- l'operation aboutissait malgre tout, et la notification envoyee au
-- destinataire conservait le motif d'origine, ecrite avant que le
-- declencheur ne s'applique.
--
-- Ils levent desormais une exception. L'insertion echoue, la transaction est
-- annulee dans son ensemble — transfert, pret ET notification — et l'auteur
-- recoit un message clair au lieu de constater apres coup une censure.
-- ─────────────────────────────────────────────────────────────

create or replace function public.reject_forbidden_transaction_description()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.description is not null
     and public.contains_forbidden_words(new.description) then
    raise exception 'Le motif contient des termes inappropriés.';
  end if;
  return new;
end;
$$;

create or replace function public.reject_forbidden_loan_note()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.note is not null
     and public.contains_forbidden_words(new.note) then
    raise exception 'Le motif contient des termes inappropriés.';
  end if;
  return new;
end;
$$;

create or replace function public.reject_forbidden_chat_loan_note()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.loan_note is not null
     and public.contains_forbidden_words(new.loan_note) then
    raise exception 'Le motif contient des termes inappropriés.';
  end if;
  return new;
end;
$$;

-- Remplace les declencheurs de censure par ceux de refus.
drop trigger if exists trg_censor_transaction_description on public.transactions;
drop trigger if exists trg_censor_loan_note on public.loans;
drop trigger if exists trg_censor_chat_loan_note on public.chat_messages;

drop function if exists public.censor_transaction_description();
drop function if exists public.censor_loan_note();
drop function if exists public.censor_chat_loan_note();

drop trigger if exists trg_reject_transaction_description on public.transactions;
create trigger trg_reject_transaction_description
  before insert or update of description on public.transactions
  for each row execute function public.reject_forbidden_transaction_description();

drop trigger if exists trg_reject_loan_note on public.loans;
create trigger trg_reject_loan_note
  before insert or update of note on public.loans
  for each row execute function public.reject_forbidden_loan_note();

drop trigger if exists trg_reject_chat_loan_note on public.chat_messages;
create trigger trg_reject_chat_loan_note
  before insert or update of loan_note on public.chat_messages
  for each row execute function public.reject_forbidden_chat_loan_note();

-- Repare les motifs deja remplaces par l'ancien mecanisme, qui portait en
-- prime un libelle sans accent.
update public.transactions
set description = null
where description in ('Description censuree', 'Description censurée');

update public.loans
set note = null
where note in ('Motif censure', 'Motif censuré');

update public.chat_messages
set loan_note = null
where loan_note in ('Motif censure', 'Motif censuré');

-- ─────────────────────────────────────────────────────────────
-- 2. Retrait des citations de profil
-- ─────────────────────────────────────────────────────────────

drop function if exists public.set_profile_quote(text);
drop function if exists public.admin_clear_quote(uuid);

alter table public.profiles drop column if exists quote;
