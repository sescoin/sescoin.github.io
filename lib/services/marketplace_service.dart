import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants.dart';
import '../models/marketplace_item.dart';
import '../models/transaction.dart';

class PurchaseResult {
  final String purchaseId;
  final Transaction transaction;
  final MarketplaceItem item;

  const PurchaseResult({
    required this.purchaseId,
    required this.transaction,
    required this.item,
  });
}

class MarketplaceService {
  final SupabaseClient _client;

  MarketplaceService(this._client);

  Future<List<MarketplaceItem>> getAvailableItems() async {
    final data = await _client
        .from(AppConstants.tableMarketplaceItems)
        .select()
        .eq('is_active', true)
        .order('category', ascending: true)
        .order('price', ascending: true);

    return (data as List).map((e) => MarketplaceItem.fromJson(e)).toList();
  }

  Future<List<MarketplaceItem>> getAllItems() async {
    final data = await _client
        .from(AppConstants.tableMarketplaceItems)
        .select()
        .order('created_at', ascending: false);

    return (data as List).map((e) => MarketplaceItem.fromJson(e)).toList();
  }

  Future<List<MarketplaceItem>> getItemsByCategory(String category) async {
    final data = await _client
        .from(AppConstants.tableMarketplaceItems)
        .select()
        .eq('category', category)
        .eq('is_active', true)
        .order('price', ascending: true);

    return (data as List).map((e) => MarketplaceItem.fromJson(e)).toList();
  }

  Future<MarketplaceItem> getItem(String itemId) async {
    final data = await _client
        .from(AppConstants.tableMarketplaceItems)
        .select()
        .eq('id', itemId)
        .single();

    return MarketplaceItem.fromJson(data);
  }

  Future<List<Map<String, dynamic>>> getPurchaseHistory(String userId) async {
    final data = await _client.from(AppConstants.tablePurchases).select('''
          *,
          buyer:profiles(id, username, display_name, avatar_url),
          item:marketplace_items(id, name, description, image_url, category, price, max_per_user)
        ''').eq('buyer_id', userId).order('created_at', ascending: false);

    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getItemBuyers(String itemId) async {
    final data = await _client.from(AppConstants.tablePurchases).select('''
          *,
          buyer:profiles(id, username, display_name, avatar_url)
        ''').eq('item_id', itemId).order('created_at', ascending: false);

    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<void> deletePurchaseRecord(String purchaseId) async {
    await _client.rpc('admin_delete_purchase_record', params: {
      'p_purchase_id': purchaseId,
    });
  }

  Future<PurchaseResult> purchaseItem({
    required String buyerId,
    required String itemId,
    int quantity = 1,
  }) async {
    if (quantity < 1) {
      throw Exception('La quantité doit être au moins 1.');
    }

    final response = await _client.rpc('purchase_marketplace_item', params: {
      'p_buyer_id': buyerId,
      'p_item_id': itemId,
      'p_quantity': quantity,
    });

    final result = response as Map<String, dynamic>;

    return PurchaseResult(
      purchaseId: result['purchase_id'] as String,
      transaction:
          Transaction.fromJson(result['transaction'] as Map<String, dynamic>),
      item: MarketplaceItem.fromJson(result['item'] as Map<String, dynamic>),
    );
  }

  Future<MarketplaceItem> createItem({
    required String name,
    String? description,
    required double price,
    required String category,
    required int stock,
    required int maxPerUser,
    String? imageUrl,
  }) async {
    final data = await _client
        .from(AppConstants.tableMarketplaceItems)
        .insert({
          'name': name,
          'description': description ?? '',
          'price': price,
          'category': category,
          'stock': stock,
          'max_per_user': maxPerUser,
          'is_active': true,
          'image_url': imageUrl,
        })
        .select()
        .single();

    return MarketplaceItem.fromJson(data);
  }

  Future<MarketplaceItem> updateItem({
    required String itemId,
    String? name,
    String? description,
    double? price,
    String? category,
    int? stock,
    int? maxPerUser,
    bool? isActive,
    String? imageUrl,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (price != null) updates['price'] = price;
    if (category != null) updates['category'] = category;
    if (stock != null) updates['stock'] = stock;
    if (maxPerUser != null) updates['max_per_user'] = maxPerUser;
    if (isActive != null) updates['is_active'] = isActive;
    if (imageUrl != null) updates['image_url'] = imageUrl;

    final data = await _client
        .from(AppConstants.tableMarketplaceItems)
        .update(updates)
        .eq('id', itemId)
        .select()
        .single();

    return MarketplaceItem.fromJson(data);
  }

  Future<void> deactivateItem(String itemId) async {
    await _client.from(AppConstants.tableMarketplaceItems).update({
      'is_active': false,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', itemId);
  }

  Future<void> deleteItem(String itemId) async {
    await _client
        .from(AppConstants.tableMarketplaceItems)
        .delete()
        .eq('id', itemId);
  }

  Stream<List<MarketplaceItem>> watchAvailableItems() {
    return _client
        .from(AppConstants.tableMarketplaceItems)
        .stream(primaryKey: ['id'])
        .order('price', ascending: true)
        .map((rows) => rows
            .where((r) => r['is_active'] == true)
            .map((r) => MarketplaceItem.fromJson(r))
            .toList());
  }
}
