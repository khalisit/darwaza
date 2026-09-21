import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/broker_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/payment_provider.dart';
import 'providers/activity_log_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/brokers/broker_detail_screen.dart';
import 'screens/transactions/add_transaction_screen.dart';
import 'screens/transactions/transaction_detail_screen.dart';
import 'screens/statements/account_statement_screen.dart';
import 'screens/statements/general_statement_screen.dart';
import 'screens/labels/labels_screen.dart';
import 'services/pb_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  PBService().initSync(prefs);
  runApp(const MarketDarwazaApp());
}

class MarketDarwazaApp extends StatelessWidget {
  const MarketDarwazaApp({super.key});

  /// Global navigator key — used by AuthProvider for remote deactivation.
  static final navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..backgroundRefresh()),
        ChangeNotifierProvider(create: (_) => BrokerProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider(create: (_) => PaymentProvider()),
        ChangeNotifierProvider(create: (_) => ActivityLogProvider()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Market Darwaza',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        builder: (context, child) {
          return GestureDetector(
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: child,
          );
        },
        home: const _AuthGate(),
        onGenerateRoute: (settings) {
          if (!PBService().isLoggedIn) {
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          }

          switch (settings.name) {
            case '/':
              return _buildRoute(const DashboardScreen(), settings);
            case '/broker-detail':
              final brokerId = settings.arguments as String;
              return _buildRoute(
                BrokerDetailScreen(brokerId: brokerId),
                settings,
              );
            case '/add-transaction':
              final brokerId = settings.arguments as String?;
              return _buildRoute(
                AddTransactionScreen(brokerId: brokerId),
                settings,
              );
            case '/edit-transaction':
              final args = settings.arguments as Map<String, String>;
              return _buildRoute(
                AddTransactionScreen(
                  brokerId: args['brokerId'],
                  editTransactionId: args['transactionId'],
                ),
                settings,
              );
            case '/transaction-detail':
              final args = settings.arguments as Map<String, String>;
              return _buildRoute(
                TransactionDetailScreen(
                  transactionId: args['transactionId']!,
                  brokerId: args['brokerId']!,
                ),
                settings,
              );
            case '/account-statement':
              final brokerId = settings.arguments as String;
              return _buildRoute(
                AccountStatementScreen(brokerId: brokerId),
                settings,
              );
            case '/general-statement':
              return _buildRoute(
                const GeneralStatementScreen(),
                settings,
              );
            case '/labels':
              return _buildRoute(
                const LabelsScreen(),
                settings,
              );
            default:
              return _buildRoute(const DashboardScreen(), settings);
          }
        },
      ),
    );
  }

  static PageRouteBuilder _buildRoute(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOut,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.05, 0),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(
            opacity: curved,
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 250),
    );
  }
}

/// Auth gate — sits as the home route of [MaterialApp].
/// Watches [AuthProvider] and swaps between Dashboard / Login.
/// Because MaterialApp itself never rebuilds, the Navigator stays stable.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = context.watch<AuthProvider>().isLoggedIn;
    return isLoggedIn ? const DashboardScreen() : const LoginScreen();
  }
}
