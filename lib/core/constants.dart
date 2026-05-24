// Constantes globales de l'app SES Coin

class AppConstants {
  AppConstants._();

  static const String appName = 'SES Coin';
  static const String currencySymbol = 'SC';
  static const String currencyName = 'SES Coin';

  static const int passwordMinLength = 8;
  static const int maxAccountRequestsPerDevice = 3;
  static const String adminRole = 'admin';
  static const String studentRole = 'student';

  static const double minTransferAmount = 0.01;
  static const double maxTransferAmount = 999999.99;
  static const int transactionHistoryPageSize = 20;

  static const double minLoanInterestRate = 0.0;
  static const double maxLoanInterestRate = 100.0;
  static const int minLoanDurationDays = 1;
  static const int maxLoanDurationDays = 365;

  static const double minBidIncrement = 0.01;
  static const int auctionDefaultDurationHours = 0;

  static const double exchangeRateBase = 1.0;
  static const int exchangeRateHistoryDays = 30;

  static const String nfcRecordType = 'application/ses-coin';
  static const int nfcTimeoutSeconds = 30;

  static const int leaderboardMaxEntries = 50;

  static const String tableProfiles = 'profiles';
  static const String tableTransactions = 'transactions';
  static const String tableAccountRequests = 'account_requests';
  static const String tableMarketplaceItems = 'marketplace_items';
  static const String tablePurchases = 'purchases';
  static const String tableAuctions = 'auctions';
  static const String tableAuctionBids = 'auction_bids';
  static const String tableLoans = 'loans';
  static const String tableExchangeRates = 'exchange_rates';
  static const String tableNotifications = 'notifications';

  static const String bucketAvatars = 'avatars';
  static const String bucketMarketplace = 'marketplace';

  static const String channelTransactions = 'transactions';
  static const String channelAuctions = 'auctions';
  static const String channelBalances = 'balances';
}

enum TransactionType {
  transfer,
  purchase,
  auction,
  loan,
  reward,
  tax,
  adminCredit,
  adminDebit,
  initialBalance,
}

extension TransactionTypeX on TransactionType {
  String get label => switch (this) {
        TransactionType.transfer => 'Virement',
        TransactionType.purchase => 'Achat',
        TransactionType.auction => 'Enchère',
        TransactionType.loan => 'Prêt',
        TransactionType.reward => 'Récompense',
        TransactionType.tax => 'Taxe',
        TransactionType.adminCredit => 'Crédit',
        TransactionType.adminDebit => 'Débit',
        TransactionType.initialBalance => 'Solde initial',
      };

  String get dbValue => switch (this) {
        TransactionType.transfer => 'transfer',
        TransactionType.purchase => 'purchase',
        TransactionType.auction => 'auction',
        TransactionType.loan => 'loan',
        TransactionType.reward => 'reward',
        TransactionType.tax => 'tax',
        TransactionType.adminCredit => 'admin_credit',
        TransactionType.adminDebit => 'admin_debit',
        TransactionType.initialBalance => 'initial_balance',
      };

  static TransactionType fromDb(String value) => switch (value) {
        'transfer' => TransactionType.transfer,
        'purchase' => TransactionType.purchase,
        'auction' => TransactionType.auction,
        'loan' => TransactionType.loan,
        'reward' => TransactionType.reward,
        'tax' => TransactionType.tax,
        'admin_credit' => TransactionType.adminCredit,
        'admin_debit' => TransactionType.adminDebit,
        'initial_balance' => TransactionType.initialBalance,
        _ => TransactionType.transfer,
      };
}

enum AccountRequestStatus { pending, approved, refused }

extension AccountRequestStatusX on AccountRequestStatus {
  String get dbValue => switch (this) {
        AccountRequestStatus.pending => 'pending',
        AccountRequestStatus.approved => 'approved',
        AccountRequestStatus.refused => 'refused',
      };

  static AccountRequestStatus fromDb(String value) => switch (value) {
        'approved' => AccountRequestStatus.approved,
        'refused' => AccountRequestStatus.refused,
        _ => AccountRequestStatus.pending,
      };
}

enum LoanStatus { pending, active, repaid, defaulted }

extension LoanStatusX on LoanStatus {
  String get dbValue => switch (this) {
        LoanStatus.pending => 'pending',
        LoanStatus.active => 'active',
        LoanStatus.repaid => 'repaid',
        LoanStatus.defaulted => 'defaulted',
      };

  static LoanStatus fromDb(String value) => switch (value) {
        'active' => LoanStatus.active,
        'repaid' => LoanStatus.repaid,
        'defaulted' => LoanStatus.defaulted,
        _ => LoanStatus.pending,
      };
}

enum AuctionStatus { active, ended, cancelled }

extension AuctionStatusX on AuctionStatus {
  String get dbValue => switch (this) {
        AuctionStatus.active => 'active',
        AuctionStatus.ended => 'ended',
        AuctionStatus.cancelled => 'cancelled',
      };

  static AuctionStatus fromDb(String value) => switch (value) {
        'ended' => AuctionStatus.ended,
        'cancelled' => AuctionStatus.cancelled,
        _ => AuctionStatus.active,
      };
}
