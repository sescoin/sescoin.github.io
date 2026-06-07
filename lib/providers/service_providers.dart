import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/class_service.dart';
import '../services/profile_service.dart';
import '../services/transaction_service.dart';
import '../services/marketplace_service.dart';
import '../services/auction_service.dart';
import '../services/loan_service.dart';
import '../services/currency_service.dart';
import '../services/notification_service.dart';
import '../services/chat_service.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(supabaseClientProvider));
});

final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService(ref.watch(supabaseClientProvider));
});

final transactionServiceProvider = Provider<TransactionService>((ref) {
  return TransactionService(ref.watch(supabaseClientProvider));
});

final marketplaceServiceProvider = Provider<MarketplaceService>((ref) {
  return MarketplaceService(ref.watch(supabaseClientProvider));
});

final auctionServiceProvider = Provider<AuctionService>((ref) {
  return AuctionService(ref.watch(supabaseClientProvider));
});

final loanServiceProvider = Provider<LoanService>((ref) {
  return LoanService(ref.watch(supabaseClientProvider));
});

final currencyServiceProvider = Provider<CurrencyService>((ref) {
  return CurrencyService(ref.watch(supabaseClientProvider));
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref.watch(supabaseClientProvider));
});

final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService(ref.watch(supabaseClientProvider));
});

final classServiceProvider = Provider<ClassService>((ref) {
  return ClassService(ref.watch(supabaseClientProvider));
});
