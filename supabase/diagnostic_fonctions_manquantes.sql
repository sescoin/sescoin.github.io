-- Diagnostic : fonctions attendues par l'application et absentes de la base.
-- Lecture seule, ne modifie rien. A coller dans l'editeur SQL de Supabase.
--
-- Les fonctions supprimees volontairement par une migration (citations de
-- profil, anciens declencheurs de censure) sont exclues de la liste.
with attendues(nom) as (
  values
    ('accept_chat_loan_request'),
    ('accept_loan'),
    ('acknowledge_payment'),
    ('admin_adjust_balance'),
    ('admin_ban_user'),
    ('admin_ban_user_temp'),
    ('admin_censor_message'),
    ('admin_chat_transcript'),
    ('admin_delete_auction'),
    ('admin_delete_auction_bid'),
    ('admin_delete_message'),
    ('admin_delete_purchase_record'),
    ('admin_delete_user'),
    ('admin_grouped_reports'),
    ('admin_reset_password'),
    ('admin_reward_all'),
    ('admin_tax_all'),
    ('admin_unban_user'),
    ('approve_account_request'),
    ('approve_avatar_change'),
    ('broadcast_notification'),
    ('calculate_currency_rate'),
    ('cancel_auction'),
    ('cancel_loan'),
    ('claim_chat_gift'),
    ('confirm_payment_request'),
    ('contains_forbidden_words'),
    ('create_class'),
    ('create_payment_request'),
    ('current_profile_is_admin'),
    ('current_school_year_start'),
    ('delete_chat_message'),
    ('delete_class'),
    ('delete_loan'),
    ('edit_chat_message'),
    ('edit_class_message'),
    ('enforce_chat_filter'),
    ('enforce_chat_flood'),
    ('finalize_auction'),
    ('finalize_expired_auctions'),
    ('get_classes'),
    ('is_username_available'),
    ('keep_original_content'),
    ('mark_ban_lifted'),
    ('mark_chat_read'),
    ('normalize_account_request_status'),
    ('normalize_for_filter'),
    ('on_report_reviewed'),
    ('place_auction_bid'),
    ('process_overdue_loans'),
    ('purchase_marketplace_item'),
    ('purge_expired_chat_messages'),
    ('reject_avatar_change'),
    ('reject_forbidden_chat_loan_note'),
    ('reject_forbidden_loan_note'),
    ('reject_forbidden_transaction_description'),
    ('reject_loan'),
    ('release_expired_sanctions'),
    ('rename_class'),
    ('repay_loan'),
    ('report_chat_message'),
    ('request_avatar_change'),
    ('request_loan'),
    ('send_chat_gift'),
    ('send_chat_message'),
    ('send_class_message'),
    ('send_global_message'),
    ('send_loan_request_chat'),
    ('set_account_request_class'),
    ('set_auction_winner_emoji'),
    ('set_user_class'),
    ('submit_account_request'),
    ('transfer_funds'),
    ('update_loan_config'),
    ('update_updated_at')
)
select a.nom as fonction_manquante
from attendues a
where not exists (
  select 1
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = a.nom
)
order by 1;
