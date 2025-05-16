// lib/screens/email_verification_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../services/auth_service.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  _EmailVerificationScreenState createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final AuthService _authService = AuthService();
  bool _isResending = false;
  bool _isChecking = false;
  Timer? _timer;
  int _countdown = 60;
  bool _canResend = true;
  int _verificationAttempts = 0;
  final int _maxVerificationAttempts = 3;
  DateTime? _lastVerificationAttempt;
  bool _initialEmailSent = false;

  @override
  void initState() {
    super.initState();
    // Don't automatically send verification email on screen load
    // We'll only send it if it hasn't been sent already
    _checkAndSendVerificationEmail();
  }

  // Check if verification email has been sent and send if needed
  Future<void> _checkAndSendVerificationEmail() async {
    // Check if we've already sent an email in this session
    if (_initialEmailSent) return;

    // Set flag to prevent duplicate emails
    setState(() {
      _initialEmailSent = true;
    });

    try {
      // Send verification email
      await _authService.sendEmailVerification();
      _showSnackBar('Verification email sent!', success: true);
      _startResendTimer();
    } catch (e) {
      // If we get a too-many-requests error, don't show an error
      // The user might have already received an email
      if (e.toString().contains('too-many-requests')) {
        _showSnackBar('A verification email was already sent. Please check your inbox.', success: true);
      } else {
        _showSnackBar('Failed to send verification email: ${e.toString()}');
      }
      _startResendTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() {
      _canResend = false;
      _countdown = 60;
    });

    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          _canResend = true;
          _timer?.cancel();
        }
      });
    });
  }

  Future<void> _sendVerificationEmail() async {
    if (!_canResend) return;

    setState(() {
      _isResending = true;
    });

    try {
      await _authService.sendEmailVerification();
      _showSnackBar('Verification email sent!', success: true);
      _startResendTimer();
    } catch (e) {
      if (e.toString().contains('too-many-requests')) {
        _showSnackBar('Please wait before requesting another email', success: false);
      } else {
        _showSnackBar('Failed to send verification email: ${e.toString()}');
      }
      _startResendTimer();
    } finally {
      setState(() {
        _isResending = false;
      });
    }
  }

  Future<void> _checkEmailVerification() async {
    // Check if we've exceeded the rate limit
    final now = DateTime.now();
    if (_lastVerificationAttempt != null) {
      final timeSinceLastAttempt = now.difference(_lastVerificationAttempt!);
      if (timeSinceLastAttempt.inSeconds < 30) {
        _showSnackBar('Please wait at least 30 seconds between verification attempts');
        return;
      }
    }
    
    // Check if we've exceeded the maximum number of attempts
    if (_verificationAttempts >= _maxVerificationAttempts) {
      _showDialog(
        'Verification Limit Reached',
        'You\'ve reached the maximum number of verification attempts. Please try again later or contact support.',
        [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('OK'),
          ),
        ]
      );
      return;
    }

    setState(() {
      _isChecking = true;
      _verificationAttempts++;
      _lastVerificationAttempt = now;
    });

    try {
      // Reload user to get latest verification status
      await _authService.refreshUserData();
      
      if (_authService.isEmailVerified) {
        _timer?.cancel();
        
        // Get a fresh token before navigating to dashboard
        await _authService.getIdToken(forceRefresh: true);
        
        _showDialog(
          'Email Verified',
          'Your email has been successfully verified. You will now be redirected to the dashboard.',
          [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                
                // Get a fresh token again just before navigation
                final token = await _authService.getIdToken(forceRefresh: true);
                
                // Navigate to dashboard with the fresh token
                Navigator.pushReplacementNamed(
                  context, 
                  '/dashboard',
                  arguments: {'token': token}
                );
              },
              child: Text('Continue'),
            ),
          ]
        );
      } else {
        _showDialog(
          'Email Not Verified',
          'Your email has not been verified yet. Please check your inbox and click the verification link in the email we sent you.',
          [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _sendVerificationEmail();
              },
              child: Text('Resend Email'),
            ),
          ]
        );
      }
    } catch (e) {
      _showSnackBar('Error checking verification status: ${e.toString()}');
    } finally {
      setState(() {
        _isChecking = false;
      });
    }
  }

  void _showDialog(String title, String message, List<Widget> actions) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: actions,
      ),
    );
  }

  Future<void> _logout() async {
    try {
      await _authService.signOut();
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      _showSnackBar('Error logging out: ${e.toString()}');
    }
  }

  void _showSnackBar(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error_outline,
              color: Colors.white,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(),
              ),
            ),
          ],
        ),
        backgroundColor: success ? Colors.green.shade600 : Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(10),
        duration: Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = _authService.currentUser?.email ?? 'your email';

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF1E3A8A), // Dark blue
              Color(0xFF3B82F6), // Medium blue
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Email icon
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.email_outlined,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 32),
                  
                  // Title
                  Text(
                    'Verify Your Email',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  // Description
                  Text(
                    'We\'ve sent a verification email to:',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  SizedBox(height: 8),
                  
                  // Email address
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      email,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  
                  // Instructions
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '1. Open your email app',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '2. Check for an email from us',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '3. Click the verification link',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '4. Return here and click the button below',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'If you don\'t see the email, check your spam folder.',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 32),
                  
                  // Check verification button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isChecking ? null : () => _checkEmailVerification(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blue.shade800,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isChecking
                          ? SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.blue.shade800,
                                ),
                              ),
                            )
                          : Text(
                              'I\'ve Verified My Email',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  // Resend button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: _canResend ? (_isResending ? null : _sendVerificationEmail) : null,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isResending
                          ? SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              _canResend
                                  ? 'Resend Verification Email'
                                  : 'Resend in $_countdown seconds',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                    ),
                  ),
                  SizedBox(height: 24),
                  
                  // Logout button
                  TextButton(
                    onPressed: _logout,
                    child: Text(
                      'Logout',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.8),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}