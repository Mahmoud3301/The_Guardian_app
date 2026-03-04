import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'pages/welcome_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const GuardianApp());
}

class GuardianApp extends StatelessWidget {
  const GuardianApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Guardian',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: false),
      home: const WelcomePage(),
    );
  }
}