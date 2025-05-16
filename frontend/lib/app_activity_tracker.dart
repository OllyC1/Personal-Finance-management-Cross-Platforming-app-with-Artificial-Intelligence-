// lib/app_activity_tracker.dart
import 'package:flutter/material.dart';
import 'services/session_service.dart';

class AppActivityTracker extends StatelessWidget {
  final Widget child;
  
  const AppActivityTracker({super.key, required this.child});
  
  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _onUserActivity(context),
      onPointerMove: (_) => _onUserActivity(context),
      onPointerUp: (_) => _onUserActivity(context),
      child: child,
    );
  }
  
  void _onUserActivity(BuildContext context) {
    SessionService().resetSessionTimer(context);
  }
}