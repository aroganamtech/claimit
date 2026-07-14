import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/otp_screen.dart';
import '../../features/auth/screens/success_screen.dart';
import '../../features/auth/screens/social_complete_profile_screen.dart';
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
import '../../features/profile/screens/legal_screens.dart';
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
import '../../features/classifieds/screens/local_finds_screen.dart';
import '../../features/classifieds/screens/local_find_zone_screen.dart';
import '../../features/classifieds/data/classified_categories.dart' show LocalFindZone;
import '../../features/classifieds/screens/classified_list_screen.dart';
import '../../features/classifieds/screens/add_post_flow.dart';
import '../../features/classifieds/screens/local_find_add_listing_flow.dart';
import '../../features/classifieds/screens/my_listings_screen.dart';
import '../../features/classifieds/screens/classified_detail_screen.dart';
import '../../features/classifieds/models/classified_post.dart';
// Bill Reader flow
import '../../features/bill_reader/screens/bill_reader_landing_screen.dart';
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
import '../../features/bill_reader/screens/bill_review_pending_screen.dart';
// Feedback / Complaints
import '../../features/feedback/screens/feedback_screen.dart';

// ── Navigator keys ─────────────────────────────────────────────────────────────
// Must be module-level finals so they are never recreated on rebuild.
// Passing them explicitly to GoRouter + ShellRoute prevents the
// "GlobalKey used multiple times" / HeroControllerScope crash.
final _rootNavKey  = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellNavKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

// Public alias so other parts of the app (e.g. FcmService, which has no
// BuildContext of its own) can navigate using the root navigator —
// e.g. `rootNavigatorKey.currentContext?.push('/notifications')`.
final GlobalKey<NavigatorState> rootNavigatorKey = _rootNavKey;

// Lets any screen with background media (autoplaying video/audio — e.g.
// Promo Reelz) know the instant another screen is pushed on top of it, so it
// can pause/mute immediately instead of playing on unseen underneath, and
// resume only if it's still the page actually in view when the user comes
// back. Subscribe with a `RouteAware` mixin:
//   ModalRoute.of(context) → appRouteObserver.subscribe(...) in
//   didChangeDependencies, unsubscribe in dispose, and override
//   didPushNext() / didPopNext().
//
// NOTE: this only works correctly for widgets whose context resolves the
// route on the SAME Navigator the observer cares about. Home/Dashboard sits
// inside the bottom-nav ShellRoute's NESTED shell navigator, so a widget deep
// inside it (e.g. the banner) would resolve the wrong (inner) route. For
// anything nested inside Home, use `homeShellCovered` below instead.
final RouteObserver<PageRoute> appRouteObserver = RouteObserver<PageRoute>();

// `_HomeScreenState` subscribes to `appRouteObserver` on the OUTER root route
// (it sits correctly between that outer route and the inner shell navigator)
// and flips this flag from didPushNext()/didPopNext(). Anything nested inside
// Home (e.g. the banner video) listens to this instead of subscribing to the
// observer directly, since its own context would resolve the wrong route.
final ValueNotifier<bool> homeShellCovered = ValueNotifier<bool>(false);

// Observer for the INNER shell navigator — catches pushes that happen inside
// the bottom-nav shell (e.g. the Notifications screen opened from the home
// bell icon). The outer appRouteObserver can't see those, which used to
// leave the home banner video playing (with sound) underneath.
final RouteObserver<PageRoute> shellRouteObserver = RouteObserver<PageRoute>();

class AppRouter {
  static GoRouter router(AuthProvider authProvider) {
    return GoRouter(
      navigatorKey: _rootNavKey,
      initialLocation: '/splash',
      observers: [appRouteObserver],
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
            state.matchedLocation == '/auth/complete-profile' ||
            state.matchedLocation == '/location';

        if (!isLoggedIn && !isPreLoginPage && !isPostLoginFlow) {
          return '/auth/login';
        }
        if (isLoggedIn && isPreLoginPage) {
          // Facebook login: force profile completion before entering the app
          if (authProvider.needsProfileCompletion) {
            return '/auth/complete-profile';
          }
          return '/home';
        }
        // Prevent Facebook users from bypassing the complete-profile screen
        if (isLoggedIn &&
            authProvider.needsProfileCompletion &&
            !isPostLoginFlow) {
          return '/auth/complete-profile';
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
              name: extra?['name'] as String? ?? '',
            );
          },
        ),
        GoRoute(
          path: '/auth/success',
          builder: (context, state) => const SuccessScreen(),
        ),
        GoRoute(
          path: '/auth/complete-profile',
          builder: (context, state) => const SocialCompleteProfileScreen(),
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
            final extra = state.extra;
            // Most callers pass a plain ShopCategory (isTab defaults false).
            // Callers that specifically need Redeem-only filtering (e.g. the
            // "Select Redeem Shop" pickers) pass {'category': ..., 'isTab': true}
            // instead — isTab is what actually turns on the hasRedeem+discount>0
            // filter in ShopListScreen; id==-1 alone means "no filter" (Nearby/See-All).
            if (extra is Map) {
              final cat = extra['category'] as ShopCategory;
              final isTab = extra['isTab'] as bool? ?? false;
              return ShopListScreen(category: cat, isTab: isTab);
            }
            final cat = extra as ShopCategory;
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
        // '/classified' now opens the "Local Finds" zone-grid landing screen;
        // its "LOCAL CLASSIFIEDS" heading pushes on to the original
        // toggle+grid screen at '/classified/home'.
        GoRoute(
          path: '/classified',
          builder: (context, state) => const LocalFindsScreen(),
        ),
        GoRoute(
          path: '/classified/home',
          builder: (context, state) => const ClassifiedHomeScreen(),
        ),
        GoRoute(
          path: '/classified/zone',
          builder: (context, state) {
            final zone = state.extra as LocalFindZone;
            return LocalFindZoneScreen(zone: zone);
          },
        ),
        GoRoute(
          path: '/classified/list',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>? ?? {};
            return ClassifiedListScreen(
              category: extra['category'] as String? ?? '',
              subcategory: extra['subcategory'] as String? ?? '',
              title: extra['title'] as String? ?? '',
              listingType: extra['listingType'] as String? ?? 'classified',
            );
          },
        ),
        GoRoute(
          path: '/classified/add',
          builder: (context, state) => const AddPostFlowScreen(),
        ),
        GoRoute(
          path: '/classified/mine',
          builder: (context, state) => const MyListingsScreen(),
        ),
        GoRoute(
          path: '/local-finds/add',
          builder: (context, state) {
            // Accepts either a raw LocalFindZone (REGISTER banner on the
            // zone screen — no subcategory picked yet) or a Map with both
            // 'zone' and 'subcategory' (the "+" button while already
            // browsing a specific subcategory list, e.g. Shop -> Grocery —
            // pre-fills it so the user isn't asked to pick it again).
            final extra = state.extra;
            if (extra is Map) {
              return LocalFindAddListingFlow(
                initialZone: extra['zone'] as LocalFindZone?,
                initialSubcategoryName: extra['subcategory'] as String?,
              );
            }
            final zone = extra as LocalFindZone?;
            return LocalFindAddListingFlow(initialZone: zone);
          },
        ),
        GoRoute(
          path: '/classified/detail',
          builder: (context, state) {
            final post = state.extra as ClassifiedPost;
            return ClassifiedDetailScreen(post: post);
          },
        ),

        // ── Bill Reader flow ───────────────────────────────────────────────
        // parentNavigatorKey + explicit page key on every screen ensures the
        // root navigator's pages list is 100% explicitly-keyed.  go_router
        // 17.2.3 throws _debugCheckDuplicatedPageKeys when auto-keyed pages
        // are mixed with CustomTransitionPage pages in the same navigator.
        // IMPORTANT: use state.pageKey (unique per pushed instance), NOT a
        // const ValueKey — several screens (shop list, deals, reels) have a
        // "Scan Bill" button that can push this flow while it's already in
        // the stack, and duplicate const keys crash the Navigator.
        GoRoute(
          parentNavigatorKey: _rootNavKey,
          path: '/bill-reader',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const BillReaderLandingScreen(),
            transitionsBuilder: (context, animation, secondary, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          parentNavigatorKey: _rootNavKey,
          path: '/bill-reader/choose-type',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const BillReaderIntroScreen(),
            transitionsBuilder: (context, animation, secondary, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          parentNavigatorKey: _rootNavKey,
          path: '/bill-reader/scanner',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
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
              key: state.pageKey,
              child: BillScanningProgressScreen(imagePath: imagePath),
              transitionsBuilder: (context, animation, secondary, child) =>
                  FadeTransition(opacity: animation, child: child),
            );
          },
        ),
        GoRoute(
          parentNavigatorKey: _rootNavKey,
          path: '/bill-reader/confirm',
          pageBuilder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            return CustomTransitionPage(
              key: state.pageKey,
              child: BillConfirmScreen(
                validationIssue: extra?['issueCode'] as String?,
              ),
              transitionsBuilder: (context, animation, secondary, child) =>
                  FadeTransition(opacity: animation, child: child),
            );
          },
        ),
        GoRoute(
          parentNavigatorKey: _rootNavKey,
          path: '/bill-reader/success',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const BillRewardSuccessScreen(),
            transitionsBuilder: (context, animation, secondary, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          parentNavigatorKey: _rootNavKey,
          path: '/bill-reader/review-pending',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const BillReviewPendingScreen(),
            transitionsBuilder: (context, animation, secondary, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          parentNavigatorKey: _rootNavKey,
          path: '/bill-reader/wallet',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
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
          observers: [shellRouteObserver],
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
          path: '/privacy-policy',
          builder: (context, state) => const PrivacyPolicyScreen(),
        ),
        GoRoute(
          path: '/terms',
          builder: (context, state) => const TermsScreen(),
        ),
        GoRoute(
          path: '/refund-policy',
          builder: (context, state) => const RefundPolicyScreen(),
        ),
        GoRoute(
          path: '/support',
          builder: (context, state) => const SupportScreen(),
        ),
        GoRoute(
          path: '/feedback',
          builder: (context, state) => const FeedbackScreen(),
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
