import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/otp_screen.dart';
import '../../features/auth/screens/success_screen.dart';
import '../../features/location/screens/location_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/claims/screens/claims_list_screen.dart';
import '../../features/claims/screens/claim_detail_screen.dart';
import '../../features/claims/screens/new_claim_screen.dart';
import '../../features/claims/screens/upload_documents_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/edit_profile_screen.dart';
import '../../features/profile/screens/settings_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/policies/screens/policies_screen.dart';
import '../../features/policies/screens/policy_detail_screen.dart';
import '../../features/ads/screens/national_ads_screen.dart';
import '../../features/categories/screens/categories_screen.dart';
import '../../features/deals/screens/deal_detail_screen.dart';
import '../../features/deals/models/deal_model.dart';
import '../../features/shops/models/shop_category.dart';
import '../../features/shops/screens/shop_list_screen.dart';
import '../../features/shops/screens/shop_detail_screen.dart';
import '../../features/search/screens/search_screen.dart';
import '../../features/deals/screens/deal_list_screen.dart';
import '../../features/reels/screens/reelz_screen.dart';
import '../../features/classifieds/screens/classified_home_screen.dart';
import '../../features/classifieds/screens/classified_list_screen.dart';
import '../../features/classifieds/screens/add_post_flow.dart';
import '../../features/classifieds/screens/classified_detail_screen.dart';
import '../../features/classifieds/models/classified_post.dart';
// Bill Reader flow
import '../../features/bill_reader/screens/bill_reader_intro_screen.dart';
import '../../features/bill_reader/screens/bill_confirm_screen.dart';
// Redeem flow
import '../../features/shops/screens/shop_list_screen.dart' show ShopItem;
import '../../features/shops/screens/redeem_loading_screen.dart';
import '../../features/shops/screens/redeem_eligibility_screen.dart';
import '../../features/bill_reader/screens/bill_scanner_screen.dart';
import '../../features/bill_reader/screens/bill_scanning_progress_screen.dart';
import '../../features/bill_reader/screens/bill_reward_success_screen.dart';
import '../../features/bill_reader/screens/bill_reward_wallet_screen.dart';

// ── Navigator keys ─────────────────────────────────────────────────────────────
// Must be module-level finals so they are never recreated on rebuild.
// Passing them explicitly to GoRouter + ShellRoute prevents the
// "GlobalKey used multiple times" / HeroControllerScope crash.
final _rootNavKey  = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellNavKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

class AppRouter {
  static GoRouter router(AuthProvider authProvider) {
    return GoRouter(
      navigatorKey: _rootNavKey,
      initialLocation: '/splash',
      refreshListenable: authProvider.authStateNotifier,
      redirect: (context, state) {
        final isLoggedIn = authProvider.isAuthenticated;
        final isPreLoginPage =
            state.matchedLocation == '/splash' ||
            state.matchedLocation == '/onboarding' ||
            state.matchedLocation == '/auth/login' ||
            state.matchedLocation == '/auth/register' ||
            state.matchedLocation == '/auth/otp';

        final isPostLoginFlow =
            state.matchedLocation == '/auth/success' ||
            state.matchedLocation == '/location';

        if (!isLoggedIn && !isPreLoginPage && !isPostLoginFlow) {
          return '/auth/login';
        }
        if (isLoggedIn && isPreLoginPage) {
          return '/home';
        }
        return null;
      },
      routes: [
        // ── Auth / onboarding ──────────────────────────────────────────────
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/auth/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/auth/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/auth/otp',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            return OtpScreen(
              phone: extra?['phone'] ?? '',
              isRegistration: extra?['isRegistration'] ?? false,
            );
          },
        ),
        GoRoute(
          path: '/auth/success',
          builder: (context, state) => const SuccessScreen(),
        ),
        GoRoute(
          path: '/location',
          builder: (context, state) => const LocationScreen(),
        ),

        // ── Categories / shops / deals ─────────────────────────────────────
        GoRoute(
          path: '/categories',
          builder: (context, state) => const CategoriesScreen(),
        ),
        GoRoute(
          path: '/shops',
          builder: (context, state) {
            final cat = state.extra as ShopCategory;
            return ShopListScreen(category: cat);
          },
        ),
        GoRoute(
          // parentNavigatorKey ensures this route renders in the ROOT navigator
          // (full-screen, no bottom nav), not inside the ShellRoute's navigator.
          parentNavigatorKey: _rootNavKey,
          path: '/shop-detail',
          pageBuilder: (context, state) {
            final shop = state.extra as ShopItem;
            // CustomTransitionPage does NOT add a HeroControllerScope, so it
            // never conflicts with the one MaterialApp.router already provides.
            // The unique ValueKey per shop.id lets multiple detail pages coexist
            // in the navigator stack without _debugCheckDuplicatedPageKeys firing.
            return CustomTransitionPage(
              key: ValueKey('shop-detail-${shop.id}'),
              child: ShopDetailScreen(shop: shop),
              transitionsBuilder: (context, animation, secondary, child) =>
                  FadeTransition(opacity: animation, child: child),
            );
          },
        ),
        GoRoute(
          path: '/deal-detail',
          builder: (context, state) {
            final deal = state.extra as DealData;
            return DealDetailScreen(deal: deal);
          },
        ),
        GoRoute(
          path: '/brands',
          builder: (context, state) => const DealListScreen(
            title: 'Brand Deals',
            dealGroup: 'brand',
          ),
        ),
        GoRoute(
          path: '/nearby-deals',
          builder: (context, state) => const DealListScreen(
            title: 'Nearby Deals',
            dealGroup: 'nearby',
          ),
        ),

        // ── Reelz ─────────────────────────────────────────────────────────
        GoRoute(
          path: '/reelz',
          builder: (context, state) => const ReelzScreen(),
        ),

        // ── Classifieds ────────────────────────────────────────────────────
        GoRoute(
          path: '/classified',
          builder: (context, state) => const ClassifiedHomeScreen(),
        ),
        GoRoute(
          path: '/classified/list',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>? ?? {};
            return ClassifiedListScreen(
              category: extra['category'] as String? ?? '',
              subcategory: extra['subcategory'] as String? ?? '',
              title: extra['title'] as String? ?? '',
            );
          },
        ),
        GoRoute(
          path: '/classified/add',
          builder: (context, state) => const AddPostFlowScreen(),
        ),
        GoRoute(
          path: '/classified/detail',
          builder: (context, state) {
            final post = state.extra as ClassifiedPost;
            return ClassifiedDetailScreen(post: post);
          },
        ),

        // ── Bill Reader flow ───────────────────────────────────────────────
        // parentNavigatorKey + explicit ValueKey on every screen ensures the
        // root navigator's pages list is 100% explicitly-keyed.  go_router
        // 17.2.3 throws _debugCheckDuplicatedPageKeys when auto-keyed pages
        // are mixed with CustomTransitionPage pages in the same navigator.
        GoRoute(
          parentNavigatorKey: _rootNavKey,
          path: '/bill-reader',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: const ValueKey('bill-reader-intro'),
            child: const BillReaderIntroScreen(),
            transitionsBuilder: (context, animation, secondary, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          parentNavigatorKey: _rootNavKey,
          path: '/bill-reader/scanner',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: const ValueKey('bill-reader-scanner'),
            child: const BillScannerScreen(),
            transitionsBuilder: (context, animation, secondary, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          parentNavigatorKey: _rootNavKey,
          path: '/bill-reader/scanning',
          pageBuilder: (context, state) {
            final extra = state.extra as Map<String, dynamic>? ?? {};
            final imagePath = extra['imagePath'] as String? ?? '';
            return CustomTransitionPage(
              key: const ValueKey('bill-reader-scanning'),
              child: BillScanningProgressScreen(imagePath: imagePath),
              transitionsBuilder: (context, animation, secondary, child) =>
                  FadeTransition(opacity: animation, child: child),
            );
          },
        ),
        GoRoute(
          parentNavigatorKey: _rootNavKey,
          path: '/bill-reader/confirm',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: const ValueKey('bill-reader-confirm'),
            child: const BillConfirmScreen(),
            transitionsBuilder: (context, animation, secondary, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          parentNavigatorKey: _rootNavKey,
          path: '/bill-reader/success',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: const ValueKey('bill-reader-success'),
            child: const BillRewardSuccessScreen(),
            transitionsBuilder: (context, animation, secondary, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          parentNavigatorKey: _rootNavKey,
          path: '/bill-reader/wallet',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: const ValueKey('bill-reader-wallet'),
            child: const BillRewardWalletScreen(),
            transitionsBuilder: (context, animation, secondary, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        ),

        // ── Other standalone pages ─────────────────────────────────────────
        GoRoute(
          path: '/national-ads',
          builder: (context, state) => const NationalAdsScreen(),
        ),
        GoRoute(
          path: '/search',
          builder: (context, state) => const SearchScreen(),
        ),

        // ── Redeem flow ────────────────────────────────────────────────────
        // parentNavigatorKey: _rootNavKey → rendered in root navigator (no
        // bottom nav), matching /shop-detail. pageBuilder + unique ValueKey
        // per shop.id prevents _debugCheckDuplicatedPageKeys assertion in
        // go_router 17.x when multiple redeem routes exist in the stack.
        GoRoute(
          parentNavigatorKey: _rootNavKey,
          path: '/redeem-loading',
          pageBuilder: (context, state) {
            final shop = state.extra as ShopItem;
            return CustomTransitionPage(
              key: ValueKey('redeem-loading-${shop.id}'),
              child: RedeemLoadingScreen(shop: shop),
              transitionsBuilder: (context, animation, secondary, child) =>
                  FadeTransition(opacity: animation, child: child),
            );
          },
        ),
        GoRoute(
          parentNavigatorKey: _rootNavKey,
          path: '/redeem-eligibility',
          pageBuilder: (context, state) {
            final extra = state.extra as Map<String, dynamic>;
            final shop  = extra['shop'] as ShopItem;
            return CustomTransitionPage(
              key: ValueKey('redeem-eligibility-${shop.id}'),
              child: RedeemEligibilityScreen(
                shop:     shop,
                eligible: extra['eligible'] as bool?   ?? false,
                discount: extra['discount'] as int?    ?? 0,
                message:  extra['message']  as String? ?? '',
              ),
              transitionsBuilder: (context, animation, secondary, child) =>
                  FadeTransition(opacity: animation, child: child),
            );
          },
        ),

        // ── Shell (bottom nav) ─────────────────────────────────────────────
        // pageBuilder with a fixed ValueKey prevents go_router 17.x from
        // auto-generating a key that could conflict with pushed route pages.
        ShellRoute(
          navigatorKey: _shellNavKey,
          pageBuilder: (context, state, child) => NoTransitionPage<void>(
            key: const ValueKey('app-shell'),
            child: HomeScreen(child: child),
          ),
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const DashboardScreen(),
            ),
            GoRoute(
              path: '/redeem-zone',
              builder: (context, state) => const ShopListScreen(
                isTab: true,
                category: ShopCategory(
                  id: -1,
                  name: 'Redeem+ Zone',
                  icon: Icons.redeem_rounded,
                  color: Color(0xFF059669),
                ),
              ),
            ),
            GoRoute(
              path: '/claims',
              builder: (context, state) => const ClaimsListScreen(),
            ),
            GoRoute(
              path: '/notifications',
              builder: (context, state) => const NotificationsScreen(),
            ),
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
            GoRoute(
              path: '/policies',
              builder: (context, state) => const PoliciesScreen(),
            ),
          ],
        ),

        // ── Deep routes (outside shell) ────────────────────────────────────
        GoRoute(
          path: '/claims/new',
          builder: (context, state) => const NewClaimScreen(),
        ),
        GoRoute(
          path: '/claims/:id',
          builder: (context, state) {
            final claimId = state.pathParameters['id']!;
            return ClaimDetailScreen(claimId: claimId);
          },
        ),
        GoRoute(
          path: '/claims/:id/documents',
          builder: (context, state) {
            final claimId = state.pathParameters['id']!;
            return UploadDocumentsScreen(claimId: claimId);
          },
        ),
        GoRoute(
          path: '/profile/edit',
          builder: (context, state) => const EditProfileScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/policies/:id',
          builder: (context, state) {
            final policyId = state.pathParameters['id']!;
            return PolicyDetailScreen(policyId: policyId);
          },
        ),
      ],
    );
  }
}
