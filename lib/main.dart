import 'package:beszel_pro/providers/app_provider.dart';
import 'package:beszel_pro/screens/dashboard_screen.dart';
import 'package:beszel_pro/screens/login_screen.dart';
import 'package:beszel_pro/screens/setup_screen.dart';
import 'package:beszel_pro/screens/language_screen.dart';
import 'package:beszel_pro/services/pocketbase_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beszel_pro/services/pin_service.dart';
import 'package:beszel_pro/screens/pin_screen.dart';
import 'package:beszel_pro/services/alert_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ru'), Locale('zh', 'CN')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppProvider(prefs)),
          ChangeNotifierProvider(create: (_) => AlertManager()),
        ],
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, appProvider, child) {
        return MaterialApp(
          title: 'Beszel Pro',
          debugShowCheckedModeBanner: false,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale, // Uses EasyLocalization's locale
          themeMode: appProvider.themeMode,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorSchemeSeed: Colors.blueAccent,
            fontFamily: 'Inter', // Will resolve via GoogleFonts later or system
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorSchemeSeed: Colors.blueAccent,
            fontFamily: 'Inter',
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    // Artificial delay for splash effect
    await Future.delayed(const Duration(seconds: 1));
    debugPrint('Splash: Checking session...');

    try {
      final prefs = await SharedPreferences.getInstance();

      // Check for first run
      final isFirstRun = prefs.getBool('is_first_run') ?? true;
      if (isFirstRun) {
        _navigate(const LanguageScreen());
        return;
      }

      final url = prefs.getString('pb_url');
      debugPrint('Splash: URL from prefs: $url');

      if (url == null || url.isEmpty) {
        _navigate(const SetupScreen());
        return;
      }

      // Initialize PocketBase
      debugPrint('Splash: Connecting to PocketBase...');
      await PocketBaseService().connect(url);

      // Check Auth Status
      if (PocketBaseService().pb.authStore.isValid) {
        final isPinSet = await PinService().isPinSet();
        if (isPinSet) {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => PinScreen(
                  isSetup: false,
                  onSuccess: (ctx) {
                    Navigator.of(ctx).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const DashboardScreen(),
                      ),
                    );
                  },
                ),
              ),
            );
          }
        } else {
          _navigate(const DashboardScreen());
        }
      } else {
        _navigate(const LoginScreen());
      }
    } catch (e) {
      debugPrint('Splash: Error: $e');
      // If error (e.g. malformed URL in prefs), go to Setup
      _navigate(const SetupScreen());
    }
  }

  void _navigate(Widget screen) {
    if (mounted) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => screen));
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
