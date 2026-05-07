import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/otp_screen.dart';
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

class AppRouter {
  static GoRouter router(AuthProvider authProvider) {
    return GoRouter(
      initialLocation: '/splash',
      refreshListenable: authProvider,
      redirect: (context, state) {
        final isLoggedIn = authProvider.isAuthenticated;
        final isOnAuthPage = state.matchedLocation.startsWith('/auth') ||
            state.matchedLocation == '/splash' ||
            state.matchedLocation == '/onboarding';

        if (!isLoggedIn && !isOnAuthPage) {
          return '/auth/login';
        }
        if (isLoggedIn && isOnAuthPage && state.matchedLocation != '/splash') {
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
      ],
    );
  }
}
