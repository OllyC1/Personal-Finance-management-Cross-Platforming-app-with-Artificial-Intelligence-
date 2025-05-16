import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';  

// Import your screens with relative paths
import 'screens/login.dart';
import 'screens/register.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/dashboard.dart';
import 'wrappers/auth_wrapper.dart';
import 'app_activity_tracker.dart';
import 'cleanup_tool.dart';
import 'screens/email_verification_screen.dart';
import 'screens/connection_test_screen.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with the options from firebase_options.dart
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Personal Finance App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: AppActivityTracker(
        child: AuthWrapper(),
      ),
      routes: {
        '/login': (context) => LoginScreen(),
        '/register': (context) => RegisterScreen(),
        '/forgot-password': (context) => ForgotPasswordScreen(),
        '/email-verification': (context) => EmailVerificationScreen(),
        // Use a builder for dashboard to get the token from the auth wrapper
        '/dashboard': (context) => Builder(
          builder: (context) {
            // Get token from arguments if available
            final args = ModalRoute.of(context)?.settings.arguments;
            String token = '';
            if (args != null && args is Map<String, dynamic> && args.containsKey('token')) {
              token = args['token'] as String;
            }
            return DashboardScreen(token: token);
          },
        ),
        '/cleanup-tool': (context) => CleanupToolScreen(),
        '/connection-test': (context) => ConnectionTestScreen(),
      },
    );
  }
}

