import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/location_provider.dart';
import 'core/router/app_router.dart';
import 'core/services/fcm_service.dart';

import 'features/auth/providers/auth_provider.dart';
import 'features/claims/providers/claims_provider.dart';
import 'features/dashboard/providers/dashboard_provider.dart';
import 'features/notifications/providers/notification_provider.dart';
import 'features/policies/providers/policy_provider.dart';
import 'features/profile/providers/profile_provider.dart';
import 'features/bill_reader/providers/bill_reward_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Firebase Cloud Messaging (push / popup notifications) ─────────────────
  // Requires android/app/google-services.json (and ios/Runner/GoogleService-Info.plist)
  // to be in place — see FIREBASE_FCM_SETUP.md at the repo root for the full guide.
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await FcmService.instance.init();
  } catch (e) {
    // Don't crash the app if Firebase config files haven't been added yet —
    // just log so it's obvious push notifications are not active.
    debugPrint('⚠️ Firebase/FCM initialization skipped: $e');
  }

  // Lock orientation to portrait for the consumer-style insurance UI.
  SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const ClaimitApp());
}

class ClaimitApp extends StatefulWidget {
  const ClaimitApp({super.key});

  @override
  State<ClaimitApp> createState() => _ClaimitAppState();
}

class _ClaimitAppState extends State<ClaimitApp> {
  // Create AuthProvider and GoRouter ONCE — never inside a Consumer/builder.
  // Recreating GoRouter on every notifyListeners() call resets it to
  // initialLocation ('/splash'), which is why the app jumped back to the
  // splash screen whenever _isLoading changed.
  late final AuthProvider       _authProvider;
  late final BillRewardProvider _billProvider;
  late final LocationProvider   _locationProvider;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authProvider = AuthProvider();
    _billProvider = BillRewardProvider();
    _router = AppRouter.router(_authProvider);

    // The location every screen searches around. init() restores the last
    // chosen place from storage first, so the app opens where the user left
    // it, and only then tries GPS in the background. It never blocks start-up
    // and never asks for a permission the user has already declined.
    _locationProvider = LocationProvider();
    _locationProvider.init();

    // ── Auto-load bill wallet + history whenever the user authenticates ──────
    // authStateNotifier fires only when isAuthenticated flips true/false, so
    // this triggers once after login/app-restart and not on every rebuild.
    _authProvider.authStateNotifier.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    if (_authProvider.isAuthenticated) {
      // Fire-and-forget: cache is already showing from SharedPreferences,
      // this refreshes from the server in the background.
      _billProvider.loadAll();
    } else {
      // User logged out — clear stale wallet data
      _billProvider.clearCache();
    }
  }

  @override
  void dispose() {
    _authProvider.authStateNotifier.removeListener(_onAuthChanged);
    _authProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Use .value so the already-created instance is shared with the tree.
        ChangeNotifierProvider.value(value: _authProvider),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ClaimsProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => PolicyProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        // Use .value so the same instance pre-loaded in initState is shared
        ChangeNotifierProvider.value(value: _billProvider),
        ChangeNotifierProvider.value(value: _locationProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) => MaterialApp.router(
          title: 'Claimit',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          routerConfig: _router,
          // ── Responsive text-scale guard ───────────────────────────────
          // Prevents system "Display size / Font size" (Samsung, Xiaomi, etc.)
          // from scaling text beyond 1.1× so layouts never overflow.
          // The font sizes in AppTheme are already sized for comfortable reading;
          // extreme system scaling breaks fixed-height containers.
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            // Clamp system text scale: allow slight boosts but cap at 1.1×.
            final clampedScale =
                mq.textScaler.scale(1.0).clamp(0.9, 1.1);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: TextScaler.linear(clampedScale),
              ),
              child: child!,
            );
          },
        ),
      ),
    );
  }
}
