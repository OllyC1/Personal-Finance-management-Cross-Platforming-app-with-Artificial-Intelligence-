// lib/wrappers/auth_wrapper.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../screens/login.dart';
import '../screens/email_verification_screen.dart';
import '../screens/dashboard.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  _AuthWrapperState createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    // Add a small delay to ensure Firebase Auth is fully initialized
    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while initializing
    if (_isInitializing) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          final user = snapshot.data;
          
          if (user == null) {
            // User is not logged in
            return LoginScreen();
          }
          
          // User is logged in, check if email is verified
          // IMPORTANT: We don't automatically refresh user data here to avoid too many requests
          if (!user.emailVerified) {
            return EmailVerificationScreen();
          }
          
          // User is logged in and email is verified
          return FutureBuilder<String?>(
            future: _authService.getIdToken(), // Don't force refresh to avoid too many requests
            builder: (context, tokenSnapshot) {
              if (tokenSnapshot.connectionState == ConnectionState.done) {
                final token = tokenSnapshot.data;
                if (token != null) {
                  // Pass the token to the dashboard
                  return DashboardScreen(token: token);
                } else {
                  // Token is null, show error
                  return Scaffold(
                    body: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Failed to get authentication token'),
                          SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () async {
                              await _authService.signOut();
                              Navigator.pushReplacementNamed(context, '/login');
                            },
                            child: Text('Return to Login'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              }
              
              // Show loading while getting token
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Preparing your dashboard...'),
                    ],
                  ),
                ),
              );
            },
          );
        }
        
        // Show loading while checking auth state
        return Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}

