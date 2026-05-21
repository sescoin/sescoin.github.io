import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../models/marketplace_item.dart';
import '../models/transaction.dart';

/// Résultat d'un achat marketplace
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

  // ─── Lecture ─────────────────────────────────────────────────────────────────

  /// Items disponibles à l'achat (actifs + en stock)
  Future<List<MarketplaceItem>> getAvailableItems() async {
    final data = await _client
        .from(AppConstants.tableMarketplaceItems)
        .select()
        .eq('is_active', true)
        .order('category', ascending: true)
        .order('price', ascending: true);

    return (data as List).map((e) => MarketplaceItem.fromJson(e)).toList();
  }

  /// Tous les items (y compris inactifs — pour l'admin)
  Future<List<MarketplaceItem>> getAllItems() async {
    final data = await _client
        .from(AppConstants.tableMarketplaceItems)
        .select()
        .order('created_at', ascending: false);

    return (data as List).map((e) => MarketplaceItem.fromJson(e)).toList();
  }

  /// Items par catégorie
  Future<List<MarketplaceItem>> getItemsByCategory(String category) async {
    final data = await _client
        .from(AppConstants.tableMarketplaceItems)
        .select()
        .eq('category', category)
        .eq('is_active', true)
        .order('price', ascending: true);

    return (data as List).map((e) => MarketplaceItem.fromJson(e)).toList();
  }

  /// Un item en particulier
  Future<MarketplaceItem> getItem(String itemId) async {
    final data = await _client
        .from(AppConstants.tableMarketplaceItems)
        .select()
        .eq('id', itemId)
        .single();

    return MarketplaceItem.fromJson(data);
  }

  /// Historique d'achats d'un utilisateur
  Future<List<Map<String, dynamic>>> getPurchaseHistory(String userId) async {
    final data = await _client.from(AppConstants.tablePurchases).select('''
          *,
          item:marketplace_items(id, name, description, image_url, category, price)
        ''').eq('buyer_id', userId).order('created_at', ascending: false);

    return (data as List).cast<Map<String, dynamic>>();
  }

  // ─── Achat ───────────────────────────────────────────────────────────────────

  /// Achète un item du marketplace.
  /// La RPC vérifie le stock, débite le compte et crée la transaction atomiquement.
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

  // ─── Admin ───────────────────────────────────────────────────────────────────

  /// Crée un nouvel item
  Future<MarketplaceItem> createItem({
    required String name,
    required String description,
    required double price,
    required String category,
    required int stock,
    String? imageUrl,
  }) async {
    final data = await _client
        .from(AppConstants.tableMarketplaceItems)
        .insert({
          'name': name,
          'description': description,
          'price': price,
          'category': category,
          'stock': stock,
          'is_active': true,
          'image_url': imageUrl,
        })
        .select()
        .single();

    return MarketplaceItem.fromJson(data);
  }

  /// Met à jour un item existant
  Future<MarketplaceItem> updateItem({
    required String itemId,
    String? name,
    String? description,
    double? price,
    String? category,
    int? stock,
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

  /// Désactive un item (soft delete)
  Future<void> deactivateItem(String itemId) async {
    await _client.from(AppConstants.tableMarketplaceItems).update({
      'is_active': false,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', itemId);
  }

  /// Supprime définitivement un item (admin seulement)
  Future<void> deleteItem(String itemId) async {
    await _client
        .from(AppConstants.tableMarketplaceItems)
        .delete()
        .eq('id', itemId);
  }

  // ─── Realtime ────────────────────────────────────────────────────────────────

  /// Stream des items disponibles (stock mis à jour en temps réel)
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
