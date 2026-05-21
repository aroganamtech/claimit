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
// Redeem flow
import '../../features/shops/screens/shop_list_screen.dart' show ShopItem;
import '../../features/shops/screens/redeem_loading_screen.dart';
import '../../features/shops/screens/redeem_eligibility_screen.dart';
import '../../features/bill_reader/screens/bill_scanner_screen.dart';
import '../../features/bill_reader/screens/bill_scanning_progress_screen.dart';
import '../../features/bill_reader/screens/bill_reward_success_screen.dart';
import '../../features/bill_reader/screens/bill_reward_wallet_screen.dart';

class AppRouter {
  static GoRouter router(AuthProvider authProvider) {
    return GoRouter(
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
          path: '/shop-detail',
          builder: (context, state) {
            final shop = state.extra as ShopItem;
            return ShopDetailScreen(shop: shop);
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
        GoRoute(
          path: '/bill-reader',
          builder: (context, state) => const BillReaderIntroScreen(),
        ),
        GoRoute(
          path: '/bill-reader/scanner',
          builder: (context, state) => const BillScannerScreen(),
        ),
        GoRoute(
          path: '/bill-reader/scanning',
          builder: (context, state) => const BillScanningProgressScreen(),
        ),
        GoRoute(
          path: '/bill-reader/success',
          builder: (context, state) => const BillRewardSuccessScreen(),
        ),
        GoRoute(
          path: '/bill-reader/wallet',
          builder: (context, state) => const BillRewardWalletScreen(),
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
        GoRoute(
          path: '/redeem-loading',
          builder: (context, state) {
            final shop = state.extra as ShopItem;
            return RedeemLoadingScreen(shop: shop);
          },
        ),
        GoRoute(
          path: '/redeem-eligibility',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>;
            return RedeemEligibilityScreen(
              shop: extra['shop'],
              eligible: extra['eligible'] as bool? ?? false,
              discount: extra['discount'] as int? ?? 0,
              message: extra['message'] as String? ?? '',
            );
          },
        ),

        // ── Shell (bottom nav) ─────────────────────────────────────────────
        ShellRoute(
          builder: (context, state, child) => HomeScreen(child: child),
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
