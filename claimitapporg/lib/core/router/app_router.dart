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
import '../../features/location/screens/claimit_location_picker.dart';
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
import '../../features/search/screens/claimit_search_screen.dart';
import '../../features/deals/screens/deal_list_screen.dart';
import '../../features/reels/screens/reelz_screen.dart';
import '../../features/learn/screens/learn_list_screen.dart';
// ── Claimit Select ──────────────────────────────────────────────────────────
import '../../features/select/models/select_category.dart';
import '../../features/select/models/select_professional.dart';
import '../../features/select/models/select_chat.dart';
import '../../features/select/screens/select_home_screen.dart';
import '../../features/select/screens/select_list_screen.dart';
import '../../features/select/screens/select_coverage_screen.dart';
import '../../features/select/screens/select_profile_screen.dart';
import '../../features/select/screens/select_booking_screen.dart';
import '../../features/select/screens/select_bookings_screen.dart';
import '../../features/select/screens/select_register_flow.dart';
import '../../features/select/screens/select_messages_screen.dart';
import '../../features/select/screens/select_chat_screen.dart';
import '../../features/select/screens/select_profile_tab_screen.dart';
import '../../features/classifieds/screens/classified_home_screen.dart';
import '../../features/classifieds/screens/classified_ads_screen.dart';
import '../../features/classifieds/screens/local_finds_screen.dart';
import '../../features/classifieds/screens/local_finds_categories_screen.dart';
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
        // Choose the ONE location the whole app searches around: Near Me,
        // any typed area or PIN code, plus Recent and Saved. Everything here
        // works with GPS switched off.
        GoRoute(
          path: '/location/pick',
          builder: (context, state) => const ClaimitLocationPicker(),
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
          // `extra` is NOT restored when Android kills the app in the
          // background and the user returns — GoRouter restores the route but
          // the object is gone, so a bare cast crashed with a red screen at
          // exactly that moment. This is one of the most common ways a Flutter
          // app fails in the wild. Sending the user home is the safe answer.
          redirect: (context, state) =>
              state.extra is ShopItem ? null : '/home',
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
          // Same guard: no deal object (process death, deep link) -> go home
          // rather than crash.
          redirect: (context, state) =>
              state.extra is DealData ? null : '/home',
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

        // ── Learn Claimit ────────────────────────────────────────────────
        GoRoute(
          path: '/learn',
          builder: (context, state) => const LearnListScreen(),
        ),

        // ── Claimit Select ───────────────────────────────────────────────
        // Directory of local professionals. Every builder below reads
        // `state.extra` defensively so a deep link or a lost `extra` after a
        // hot restart falls back to a valid screen instead of crashing.
        GoRoute(
          path: '/select',
          builder: (context, state) => const SelectHomeScreen(),
        ),
        GoRoute(
          // "Who's here?" — professional counts for a city, category by
          // category, plus nearby cities. `extra` may be a plain city String
          // or a Map; anything else falls back to an empty field the user can
          // type into, so a lost `extra` after process death still works.
          path: '/select/coverage',
          builder: (context, state) {
            final extra = state.extra;
            String city = '';
            if (extra is String) {
              city = extra;
            } else if (extra is Map) {
              final c = extra['city'];
              if (c is String) city = c;
            }
            return SelectCoverageScreen(initialCity: city);
          },
        ),
        GoRoute(
          path: '/select/list',
          builder: (context, state) {
            final extra = state.extra;
            SelectCategory? category;
            String? search;
            if (extra is Map) {
              final c = extra['category'];
              if (c is SelectCategory) category = c;
              final s = extra['search'];
              if (s is String && s.trim().isNotEmpty) search = s.trim();
            } else if (extra is SelectCategory) {
              category = extra;
            }
            return SelectListScreen(category: category, searchTerm: search);
          },
        ),
        GoRoute(
          path: '/select/professional',
          builder: (context, state) {
            final id = state.extra is String ? state.extra as String : '';
            return SelectProfileScreen(professionalId: id);
          },
        ),
        GoRoute(
          path: '/select/book',
          builder: (context, state) {
            final extra = state.extra;
            // Without a professional there's nothing to book — fall back to
            // the Select home rather than rendering a broken screen.
            if (extra is! SelectProfessional) return const SelectHomeScreen();
            return SelectBookingScreen(professional: extra);
          },
        ),
        GoRoute(
          path: '/select/bookings',
          builder: (context, state) => const SelectBookingsScreen(),
        ),
        GoRoute(
          path: '/select/register',
          builder: (context, state) {
            // `extra` is the caller's existing listing when editing; null
            // (or anything else) means a fresh registration.
            final e = state.extra;
            return SelectRegisterFlow(
              existing: e is SelectProfessional ? e : null,
            );
          },
        ),
        GoRoute(
          path: '/select/messages',
          builder: (context, state) => const SelectMessagesScreen(),
        ),
        GoRoute(
          path: '/select/chat',
          builder: (context, state) {
            final extra = state.extra;
            // Without a conversation there's no thread to show — fall back to
            // the Messages list rather than rendering a broken screen.
            if (extra is! SelectConversation) return const SelectMessagesScreen();
            return SelectChatScreen(conversation: extra);
          },
        ),
        GoRoute(
          path: '/select/profile',
          builder: (context, state) => const SelectProfileTabScreen(),
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
          path: '/classified/ads',
          builder: (context, state) => const ClassifiedAdsScreen(),
        ),
        GoRoute(
          path: '/classified/zone',
          // No zone object after process death -> back to Local Finds.
          redirect: (context, state) =>
              state.extra is LocalFindZone ? null : '/classified',
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
        // Local Finds owners get their own My Listings, scoped to their
        // businesses — the Classifieds one above only shows classified posts,
        // so without this their listings would be unreachable.
        GoRoute(
          path: '/local-finds/mine',
          builder: (context, state) =>
              const MyListingsScreen(listingType: 'local_find'),
        ),
        GoRoute(
          path: '/local-finds/categories',
          builder: (context, state) => const LocalFindsCategoriesScreen(),
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
          // No post object after process death -> back to the ads list.
          redirect: (context, state) =>
              state.extra is ClassifiedPost ? null : '/classified/ads',
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
        // One search across all nine Claimit features, measured from the
        // selected location. `extra` may carry {'feature': …, 'query': …} to
        // open it already narrowed to one feature.
        GoRoute(
          path: '/search/all',
          builder: (context, state) {
            final e = state.extra;
            final m = e is Map<String, dynamic> ? e : const <String, dynamic>{};
            return ClaimitSearchScreen(
              initialFeature: m['feature'] as String?,
              initialQuery: m['query'] as String?,
            );
          },
        ),

        // ── Redeem flow ────────────────────────────────────────────────────
        // parentNavigatorKey: _rootNavKey → rendered in root navigator (no
        // bottom nav), matching /shop-detail. pageBuilder + unique ValueKey
        // per shop.id prevents _debugCheckDuplicatedPageKeys assertion in
        // go_router 17.x when multiple redeem routes exist in the stack.
        GoRoute(
          parentNavigatorKey: _rootNavKey,
          path: '/redeem-loading',
          // A redeem in progress cannot be resumed without its shop. Going
          // home is far better than a red screen mid-payment-flow.
          redirect: (context, state) =>
              state.extra is ShopItem ? null : '/home',
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
          // Needs both the map AND a shop inside it — checking only the map
          // would still crash on the inner cast.
          redirect: (context, state) {
            final e = state.extra;
            final ok = e is Map<String, dynamic> && e['shop'] is ShopItem;
            return ok ? null : '/home';
          },
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
