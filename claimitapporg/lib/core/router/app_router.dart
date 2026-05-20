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

class AppRouter {
  static GoRouter router(AuthProvider authProvider) {
    return GoRouter(
      initialLocation: '/splash',
      // Use the isolated ValueNotifier — only fires when _isAuthenticated
      // actually changes (login / logout).  The old approach used the whole
      // AuthProvider as refreshListenable, so the router re-ran its redirect
      // on every notifyListeners() call, including _isLoading toggles, which
      // on Flutter web caused the router to reset to /splash mid-request.
      refreshListenable: authProvider.authStateNotifier,
      redirect: (context, state) {
        final isLoggedIn = authProvider.isAuthenticated;
        // Pages that are part of the pre-login / onboarding flow
        final isPreLoginPage =
            state.matchedLocation == '/splash' ||
            state.matchedLocation == '/onboarding' ||
            state.matchedLocation == '/auth/login' ||
            state.matchedLocation == '/auth/register' ||
            state.matchedLocation == '/auth/otp';

        // Pages allowed for authenticated users that are still "outside" main app
        final isPostLoginFlow =
            state.matchedLocation == '/auth/success' ||
            state.matchedLocation == '/location';

        if (!isLoggedIn && !isPreLoginPage && !isPostLoginFlow) {
          return '/auth/login';
        }
        // Redirect logged-in user away from pre-login pages only
        if (isLoggedIn && isPreLoginPage) {
          return '/home';
        }
        return null;
      },
      routes: [
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
        GoRoute(
          path: '/reelz',
          builder: (context, state) => const ReelzScreen(),
        ),
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
        ShellRoute(
          builder: (context, state, child) => HomeScreen(child: child),
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const DashboardScreen(),
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
            // Keep /policies accessible but not in main nav
            GoRoute(
              path: '/policies',
              builder: (context, state) => const PoliciesScreen(),
            ),
          ],
        ),
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
          path: '/policies/:id',
          builder: (context, state) {
            final policyId = state.pathParameters['id']!;
            return PolicyDetailScreen(policyId: policyId);
          },
        ),
        GoRoute(
          path: '/national-ads',
          builder: (context, state) => const NationalAdsScreen(),
        ),
        GoRoute(
          path: '/search',
          builder: (context, state) => const SearchScreen(),
        ),
      ],
    );
  }
}
