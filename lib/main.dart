import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  // ✅ FIX: ensureInitialized مطلوب قبل أي async في main
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(const SmartAmbulanceApp());
}

class SmartAmbulanceApp extends StatelessWidget {
  const SmartAmbulanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'نظام الإسعاف الذكي',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFE53935),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          fontFamily: 'Tajawal',
        ),
        // ✅ FIX: استبدال initialRoute بـ home مع SplashRouter
        // لمعالجة auto-login قبل تحديد الشاشة الأولى
        home: const _SplashRouter(),
      ),
    );
  }
}

// ✅ FIX: SplashRouter — يحاول auto-login ويوجه للشاشة الصحيحة
// بدونه كان التطبيق يُعيد المستخدم لصفحة Login في كل مرة
class _SplashRouter extends StatefulWidget {
  const _SplashRouter();

  @override
  State<_SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<_SplashRouter> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final auth = context.read<AuthProvider>();
    final loggedIn = await auth.tryAutoLogin();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => loggedIn ? const HomeScreen() : const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // شاشة تحميل بسيطة أثناء التحقق من الجلسة
    return const Scaffold(
      backgroundColor: Color(0xFF0A0E1A),
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFFD32F2F)),
      ),
    );
  }
}