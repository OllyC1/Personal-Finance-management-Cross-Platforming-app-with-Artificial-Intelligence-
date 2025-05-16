// lib/services/session_service.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'auth_service.dart';

class SessionService {
  final AuthService _authService = AuthService();
  Timer? _sessionTimer;
  final int _sessionTimeoutMinutes = 30; // Adjust as needed
  
  // Singleton pattern
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();
  
  // Start session timer
  void startSessionTimer(BuildContext context) {
    // Cancel any existing timer
    _sessionTimer?.cancel();
    
    // Start a new timer
    _sessionTimer = Timer(Duration(minutes: _sessionTimeoutMinutes), () {
      // Session timeout, log out the user
      _handleSessionTimeout(context);
    });
  }
  
  // Reset session timer (call this on user activity)
  void resetSessionTimer(BuildContext context) {
    startSessionTimer(context);
  }
  
  // Handle session timeout
  void _handleSessionTimeout(BuildContext context) async {
    // Log out the user
    await _authService.signOut();
    
    // Show timeout dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Session Timeout'),
        content: Text('Your session has expired due to inactivity. Please log in again.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
  
  // Dispose session timer
  void disposeSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = null;
  }
}