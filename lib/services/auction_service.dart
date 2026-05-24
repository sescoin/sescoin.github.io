import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants.dart';
import '../models/auction.dart';

class AuctionService {
  final SupabaseClient _client;
  static const _pollInterval = Duration(seconds: 3);

  AuctionService(this._client);

  Future<List<Auction>> getActiveAuctions() async {
    await finalizeExpiredAuctions();
    final data = await _client
        .from(AppConstants.tableAuctions)
        .select()
        .inFilter('status', ['active', 'upcoming'])
        .order('ends_at', ascending: true);

    return (data as List).map((e) => Auction.fromJson(e)).toList();
  }

  Future<List<Auction>> getAllAuctions() async {
    await finalizeExpiredAuctions();
    final data = await _client
        .from(AppConstants.tableAuctions)
        .select()
        .order('created_at', ascending: false);

    return (data as List).map((e) => Auction.fromJson(e)).toList();
  }

  Future<Auction> getAuction(String auctionId) async {
    await finalizeExpiredAuctions();
    final data = await _client
        .from(AppConstants.tableAuctions)
        .select()
        .eq('id', auctionId)
        .single();

    return Auction.fromJson(data);
  }

  Future<List<AuctionBid>> getBids(String auctionId) async {
    final data = await _client
        .from(AppConstants.tableAuctionBids)
        .select()
        .eq('auction_id', auctionId)
        .order('amount', ascending: false);

    return (data as List).map((e) => AuctionBid.fromJson(e)).toList();
  }

  Future<List<Map<String, dynamic>>> getAuctionBidHistory(String auctionId) async {
    final data = await _client
        .from(AppConstants.tableAuctionBids)
        .select('''
          *,
          bidder:profiles(id, username, display_name, avatar_url)
        ''')
        .eq('auction_id', auctionId)
        .order('amount', ascending: false);

    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Auction>> getUserAuctions(String userId) async {
    await finalizeExpiredAuctions();
    final bidData = await _client
        .from(AppConstants.tableAuctionBids)
        .select('auction_id')
        .eq('bidder_id', userId);

    final auctionIds = (bidData as List)
        .map((e) => e['auction_id'] as String)
        .toSet()
        .toList();

    if (auctionIds.isEmpty) return [];

    final data = await _client
        .from(AppConstants.tableAuctions)
        .select()
        .inFilter('id', auctionIds)
        .order('ends_at', ascending: false);

    return (data as List).map((e) => Auction.fromJson(e)).toList();
  }

  Future<Auction> placeBid({
    required String bidderId,
    required String auctionId,
    required double amount,
  }) async {
    if (amount <= 0) {
      throw Exception('Le montant doit etre positif.');
    }

    final response = await _client.rpc('place_auction_bid', params: {
      'p_bidder_id': bidderId,
      'p_auction_id': auctionId,
      'p_amount': amount,
    });

    return Auction.fromJson(response as Map<String, dynamic>);
  }

  Future<Auction> createAuction({
    required String itemName,
    required String itemDescription,
    required double startingPrice,
    required DateTime startsAt,
    required DateTime endsAt,
    String? itemImageUrl,
  }) async {
    if (endsAt.isBefore(startsAt)) {
      throw Exception('La date de fin doit etre apres la date de debut.');
    }
    if (startingPrice < 0) {
      throw Exception('Le prix de depart doit etre positif.');
    }

    final now = DateTime.now();
    final status = startsAt.isAfter(now) ? 'upcoming' : 'active';

    final data = await _client
        .from(AppConstants.tableAuctions)
        .insert({
          'item_name': itemName,
          'item_description': itemDescription,
          'item_image_url': itemImageUrl,
          'starting_price': startingPrice,
          'current_price': startingPrice,
          'status': status,
          'starts_at': startsAt.toUtc().toIso8601String(),
          'ends_at': endsAt.toUtc().toIso8601String(),
          'bid_count': 0,
        })
        .select()
        .single();

    return Auction.fromJson(data);
  }

  Future<void> cancelAuction(String auctionId) async {
    await _client.rpc('cancel_auction', params: {
      'p_auction_id': auctionId,
    });
  }

  Future<void> finalizeAuction(String auctionId) async {
    await _client.rpc('finalize_auction', params: {
      'p_auction_id': auctionId,
    });
  }

  Future<void> finalizeExpiredAuctions() async {
    await _client.rpc('finalize_expired_auctions');
  }

  Future<Auction> setWinnerEmoji({
    required String auctionId,
    required String emoji,
  }) async {
    final response = await _client.rpc('set_auction_winner_emoji', params: {
      'p_auction_id': auctionId,
      'p_emoji': emoji,
    });
    return Auction.fromJson(response as Map<String, dynamic>);
  }

  Stream<Auction> watchAuction(String auctionId) {
    return _poll(() => getAuction(auctionId));
  }

  Stream<List<Auction>> watchActiveAuctions() {
    return _poll(getActiveAuctions);
  }

  Stream<List<Auction>> watchAllAuctions() {
    return _poll(getAllAuctions);
  }

  Stream<List<AuctionBid>> watchBids(String auctionId) {
    return _poll(() => getBids(auctionId));
  }

  Stream<T> _poll<T>(Future<T> Function() loader) async* {
    while (true) {
      yield await loader();
      await Future.delayed(_pollInterval);
    }
  }
}
