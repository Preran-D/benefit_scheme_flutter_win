import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:window_manager/window_manager.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/dashboard/main_screen.dart';
import 'features/dashboard/home_screen.dart';
import 'features/customers/customers_screen.dart';
import 'features/customers/customer_details_screen.dart';
import 'features/schemes/scheme_details_screen.dart';
import 'features/payments/payments_screen.dart';
import 'features/payments/payment_details_screen.dart';
import 'features/dashboard/quick_scan_screen.dart';
import 'features/dashboard/reports_screen.dart';
import 'features/dashboard/settings_screen.dart';
import 'data/model/customer.dart';
import 'data/model/scheme.dart';
import 'data/model/payment.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1200, 800),
      minimumSize: Size(1100, 750),
      center: true,
      title: 'Benefit Scheme',
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  await dotenv.load(fileName: ".env");
  
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(
    const ProviderScope(
      child: BenefitSchemeApp(),
    ),
  );
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final _router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/customers',
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final isLoggingIn = state.matchedLocation == '/login';
    
    if (session == null && !isLoggingIn) {
      return '/login';
    }
    if (session != null && isLoggingIn) {
      return '/customers';
    }
    return null;
  },
  routes: [
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return MainScreen(child: child);
      },
      routes: [
        GoRoute(
          path: '/dashboard',
          pageBuilder: (context, state) => const NoTransitionPage(child: HomeScreen()),
        ),
        GoRoute(
          path: '/customers',
          pageBuilder: (context, state) => const NoTransitionPage(child: CustomersScreen()),
        ),
        GoRoute(
          path: '/printers',
          pageBuilder: (context, state) => const NoTransitionPage(child: SettingsScreen()),
        ),
        GoRoute(
          path: '/payments',
          pageBuilder: (context, state) => const NoTransitionPage(child: PaymentsScreen()),
        ),
      ],
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/customer_details',
      builder: (context, state) => CustomerDetailsScreen(customer: state.extra as Customer),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/scheme_details',
      builder: (context, state) => SchemeDetailsScreen(scheme: state.extra as Scheme),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/payment_details',
      builder: (context, state) => PaymentDetailsScreen(payment: state.extra as Payment),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/quick_scan',
      builder: (context, state) => const QuickScanScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/reports',
      builder: (context, state) => const ReportsScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);

class BenefitSchemeApp extends StatelessWidget {
  const BenefitSchemeApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Benefit Scheme Windows',
      themeMode: ThemeMode.light,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: _router,
    );
  }
}
