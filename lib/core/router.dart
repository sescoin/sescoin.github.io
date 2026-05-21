import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/admin/admin_accounts_screen.dart';
import '../screens/admin/admin_market_screen.dart';
import '../screens/admin/admin_rate_screen.dart';
import '../screens/admin/admin_requests_screen.dart';
import '../screens/admin/admin_screen.dart';
import '../screens/admin/admin_tax_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/request_sent_screen.dart';
import '../screens/explorer/transaction_explorer_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/home/leaderboard_screen.dart';
import '../screens/market/auction_detail_screen.dart';
import '../screens/market/market_screen.dart';
import '../screens/pay/pay_screen.dart';
import '../screens/profile/loan_create_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/public_profile_screen.dart';
import '../screens/wallet/transfer_screen.dart';
import '../screens/wallet/wallet_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const String login = '/login';
  static const String register = '/register';
  static const String requestSent = '/request-sent';

  static const String shell = '/';
  static const String home = '/home';
  static const String wallet = '/wallet';
  static const String pay = '/pay';
  static const String market = '/market';
  static const String profile = '/profile';

  static const String transferManual = '/transfer';
  static const String auctionDetail = '/auction/:id';
  static const String loanCreate = '/loan/create';
  static const String loanDetail = '/loan/:id';
  static const String publicProfile = '/user/:username';
  static const String leaderboard = '/leaderboard';
  static const String transactionExplorer = '/explorer';

  static const String adminDashboard = '/admin';
  static const String adminRequests = '/admin/requests';
  static const String adminAccounts = '/admin/accounts';
  static const String adminMarketEdit = '/admin/market';
  static const String adminTax = '/admin/tax';
  static const String adminRate = '/admin/rate';

  static String publicProfilePath(String username) => '/user/$username';
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isAuthenticated = session != null;
      final isOnAuthRoute = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register ||
          state.matchedLocation == AppRoutes.requestSent;

      if (!isAuthenticated && !isOnAuthRoute) {
        return AppRoutes.login;
      }
      if (isAuthenticated && isOnAuthRoute) {
        return AppRoutes.home;
      }
      return null;
    },
    refreshListenable: GoRouterRefreshStream(
      Supabase.instance.client.auth.onAuthStateChange,
    ),
    routes: [
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: LoginScreen()),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: RegisterScreen()),
      ),
      GoRoute(
        path: AppRoutes.requestSent,
        name: 'requestSent',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: RequestSentScreen()),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                name: 'home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.wallet,
                name: 'wallet',
                builder: (context, state) => const WalletScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.pay,
                name: 'pay',
                builder: (context, state) => const PayScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.market,
                name: 'market',
                builder: (context, state) => const MarketScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                name: 'profile',
                builder: (context, state) => ProfileScreen(
                  initialTab: state.uri.queryParameters['tab'] == 'notifications'
                      ? 1
                      : 0,
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.transferManual,
        name: 'transfer',
        builder: (context, state) => const TransferScreen(),
      ),
      GoRoute(
        path: AppRoutes.auctionDetail,
        name: 'auctionDetail',
        builder: (context, state) => AuctionDetailScreen(
          auctionId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.leaderboard,
        name: 'leaderboard',
        builder: (context, state) => const LeaderboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.loanCreate,
        name: 'loanCreate',
        builder: (context, state) => const LoanCreateScreen(),
      ),
      GoRoute(
        path: AppRoutes.publicProfile,
        name: 'publicProfile',
        builder: (context, state) => PublicProfileScreen(
          username: state.pathParameters['username']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.transactionExplorer,
        name: 'transactionExplorer',
        builder: (context, state) => const TransactionExplorerScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminDashboard,
        name: 'admin',
        builder: (context, state) => const AdminScreen(),
        routes: [
          GoRoute(
            path: 'requests',
            name: 'adminRequests',
            builder: (context, state) => const AdminRequestsScreen(),
          ),
          GoRoute(
            path: 'accounts',
            name: 'adminAccounts',
            builder: (context, state) => const AdminAccountsScreen(),
          ),
          GoRoute(
            path: 'market',
            name: 'adminMarket',
            builder: (context, state) => AdminMarketScreen(
              initialTab:
                  state.uri.queryParameters['tab'] == 'auctions' ? 1 : 0,
            ),
          ),
          GoRoute(
            path: 'tax',
            name: 'adminTax',
            builder: (context, state) => const AdminTaxScreen(),
          ),
          GoRoute(
            path: 'rate',
            name: 'adminRate',
            builder: (context, state) => const AdminRateScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Page introuvable : ${state.matchedLocation}'),
            TextButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('Retour à l’accueil'),
            ),
          ],
        ),
      ),
    ),
  );
});

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _tabs = [
    (icon: Icons.home_rounded, label: 'Accueil'),
    (icon: Icons.account_balance_wallet_rounded, label: 'Portefeuille'),
    (icon: Icons.qr_code_scanner_rounded, label: 'Payer'),
    (icon: Icons.storefront_rounded, label: 'Marché'),
    (icon: Icons.person_rounded, label: 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        items: _tabs
            .map(
              (tab) => BottomNavigationBarItem(
                icon: Icon(tab.icon),
                label: tab.label,
              ),
            )
            .toList(),
      ),
    );
  }
}
