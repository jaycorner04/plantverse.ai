import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../screens/splash_screen.dart';
import '../../screens/onboarding_screen.dart';
import '../../screens/login_screen.dart';
import '../../screens/main_layout_screen.dart';
import '../../screens/home_screen.dart';
import '../../screens/scanner_screen.dart';
import '../../screens/plant_details_screen.dart';
import '../../screens/ai_doctor_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),

      // Full screen routes
      GoRoute(
        path: '/scanner',
        name: 'scanner',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ScannerScreen(),
      ),
      GoRoute(
        path: '/plant_details',
        name: 'plant_details',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const PlantDetailsScreen(),
      ),

      // Shell Route for persistent bottom navigation
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return MainLayoutScreen(child: child);
        },
        routes: [
          GoRoute(
            path: '/home',
            name: 'home',
            parentNavigatorKey: _shellNavigatorKey,
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/ai_doctor',
            name: 'ai_doctor',
            parentNavigatorKey: _shellNavigatorKey,
            builder: (context, state) => const AiDoctorScreen(),
          ),
        ],
      ),
    ],
  );
});
