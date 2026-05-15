import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/supabase_config.dart';
import 'core/user_model.dart';
import 'services/supabase_service.dart';
import 'pages/welcome_page.dart';
import 'pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialise Supabase (same credentials as the Python desktop app)
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // Pre-load the known-faces list from Supabase Storage
  await SupabaseService.instance.init();

  runApp(const GuardianApp());
}

class GuardianApp extends StatefulWidget {
  const GuardianApp({super.key});

  @override
  State<GuardianApp> createState() => _GuardianAppState();
}

class _GuardianAppState extends State<GuardianApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // Listen for OAuth sign-in events (handles redirect after Google/Apple sign-in)
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        final user = data.session?.user;
        final name = user?.userMetadata?['full_name']?.toString() ??
            user?.userMetadata?['name']?.toString() ??
            user?.email?.split('@').first ??
            'User';
        final email = user?.email ?? '';

        // Navigate to home page after successful OAuth sign-in
        _navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => HomePage(
              user: UserModel(
                id: 1,
                fullName: name,
                email: email,
                password: '',
                createdAt: DateTime.now().toString().split(' ').first,
              ),
            ),
          ),
          (route) => false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Guardian',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: false),
      home: const WelcomePage(),
    );
  }
}