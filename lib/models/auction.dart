enum AuctionStatus { upcoming, active, ended, cancelled }

class Auction {
  final String id;
  final String itemName;
  final String itemDescription;
  final String? itemImageUrl;
  final double startingPrice;
  final double currentPrice;
  final String? currentWinnerId;
  final String? currentWinnerUsername;
  final String? currentWinnerEmoji;
  final AuctionStatus status;
  final DateTime startsAt;
  final DateTime endsAt;
  final int bidCount;
  final DateTime createdAt;

  const Auction({
    required this.id,
    required this.itemName,
    required this.itemDescription,
    this.itemImageUrl,
    required this.startingPrice,
    required this.currentPrice,
    this.currentWinnerId,
    this.currentWinnerUsername,
    this.currentWinnerEmoji,
    required this.status,
    required this.startsAt,
    required this.endsAt,
    required this.bidCount,
    required this.createdAt,
  });

  bool get isActive => status == AuctionStatus.active;
  bool get hasEnded => status == AuctionStatus.ended;
  bool get isCancelled => status == AuctionStatus.cancelled;
  bool get isUpcoming => status == AuctionStatus.upcoming;

  Duration get timeRemaining {
    final now = DateTime.now();
    if (endsAt.isBefore(now)) return Duration.zero;
    return endsAt.difference(now);
  }

  double get minimumNextBid => currentPrice + 1;

  static AuctionStatus _statusFromString(String s) {
    switch (s) {
      case 'upcoming':
        return AuctionStatus.upcoming;
      case 'active':
        return AuctionStatus.active;
      case 'ended':
        return AuctionStatus.ended;
      case 'cancelled':
        return AuctionStatus.cancelled;
      default:
        return AuctionStatus.active;
    }
  }

  static String _statusToString(AuctionStatus s) {
    switch (s) {
      case AuctionStatus.upcoming:
        return 'upcoming';
      case AuctionStatus.active:
        return 'active';
      case AuctionStatus.ended:
        return 'ended';
      case AuctionStatus.cancelled:
        return 'cancelled';
    }
  }

  factory Auction.fromJson(Map<String, dynamic> json) {
    return Auction(
      id: json['id'] as String,
      itemName: json['item_name'] as String,
      itemDescription: json['item_description'] as String,
      itemImageUrl: json['item_image_url'] as String?,
      startingPrice: (json['starting_price'] as num).toDouble(),
      currentPrice: (json['current_price'] as num).toDouble(),
      currentWinnerId: json['current_winner_id'] as String?,
      currentWinnerUsername: json['current_winner_username'] as String?,
      currentWinnerEmoji: json['current_winner_emoji'] as String?,
      status: _statusFromString(json['status'] as String),
      startsAt: DateTime.parse(json['starts_at'] as String),
      endsAt: DateTime.parse(json['ends_at'] as String),
      bidCount: json['bid_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'item_name': itemName,
      'item_description': itemDescription,
      'item_image_url': itemImageUrl,
      'starting_price': startingPrice,
      'current_price': currentPrice,
      'current_winner_id': currentWinnerId,
      'current_winner_username': currentWinnerUsername,
      'current_winner_emoji': currentWinnerEmoji,
      'status': _statusToString(status),
      'starts_at': startsAt.toIso8601String(),
      'ends_at': endsAt.toIso8601String(),
      'bid_count': bidCount,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Auction copyWith({
    String? id,
    String? itemName,
    String? itemDescription,
    String? itemImageUrl,
    double? startingPrice,
    double? currentPrice,
    String? currentWinnerId,
    String? currentWinnerUsername,
    String? currentWinnerEmoji,
    AuctionStatus? status,
    DateTime? startsAt,
    DateTime? endsAt,
    int? bidCount,
    DateTime? createdAt,
  }) {
    return Auction(
      id: id ?? this.id,
      itemName: itemName ?? this.itemName,
      itemDescription: itemDescription ?? this.itemDescription,
      itemImageUrl: itemImageUrl ?? this.itemImageUrl,
      startingPrice: startingPrice ?? this.startingPrice,
      currentPrice: currentPrice ?? this.currentPrice,
      currentWinnerId: currentWinnerId ?? this.currentWinnerId,
      currentWinnerUsername:
          currentWinnerUsername ?? this.currentWinnerUsername,
      currentWinnerEmoji: currentWinnerEmoji ?? this.currentWinnerEmoji,
      status: status ?? this.status,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      bidCount: bidCount ?? this.bidCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Auction && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Auction(id: $id, item: $itemName, currentPrice: $currentPrice, status: $status)';
}

class AuctionBid {
  final String id;
  final String auctionId;
  final String bidderId;
  final String bidderUsername;
  final double amount;
  final DateTime createdAt;

  const AuctionBid({
    required this.id,
    required this.auctionId,
    required this.bidderId,
    required this.bidderUsername,
    required this.amount,
    required this.createdAt,
  });

  factory AuctionBid.fromJson(Map<String, dynamic> json) {
    return AuctionBid(
      id: json['id'] as String,
      auctionId: json['auction_id'] as String,
      bidderId: json['bidder_id'] as String,
      bidderUsername: json['bidder_username'] as String,
      amount: (json['amount'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'auction_id': auctionId,
      'bidder_id': bidderId,
      'bidder_username': bidderUsername,
      'amount': amount,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuctionBid &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'AuctionBid(id: $id, bidder: $bidderUsername, amount: $amount)';
}
