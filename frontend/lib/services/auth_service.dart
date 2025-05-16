import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  
  // API URL - Replace with your actual backend URL
  final String apiUrl = 'http://localhost:5000';
  
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();
  
  // Get current user
  User? get currentUser => _auth.currentUser;
  
  // Check if user is logged in
  bool get isLoggedIn => _auth.currentUser != null;
  
  // Check if email is verified
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  // Check if email is already in use
  Future<bool> isEmailInUse(String email) async {
    try {
      final List<String> methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
      return methods.isNotEmpty;
    } catch (e) {
      print('Error checking email: $e');
      return false;
    }
  }
  
  // Login with email and password
  Future<UserCredential> loginWithEmailAndPassword(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Get the ID token
      final idToken = await userCredential.user?.getIdToken();
      
      // Store the token securely
      if (idToken != null) {
        await _secureStorage.write(key: 'authToken', value: idToken);
        
        // Store token expiry time (1 hour from now)
        final expiryTime = DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch.toString();
        await _secureStorage.write(key: 'tokenExpiry', value: expiryTime);
      }
      
      return userCredential;
    } catch (e) {
      print('Login error: $e');
      rethrow;
    }
  }
  
  // Register with email and password
  Future<UserCredential> registerWithEmailAndPassword(String email, String password, {String? username}) async {
    try {
      // First check if email exists
      final bool emailInUse = await isEmailInUse(email);
      if (emailInUse) {
        print('Email $email is already in use with methods: ${await FirebaseAuth.instance.fetchSignInMethodsForEmail(email)}');
        throw FirebaseAuthException(
          code: 'email-already-in-use',
          message: 'The email address is already in use by another account.'
        );
      }
      
      print('Email $email is not in use, proceeding with registration');
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update display name if username is provided
      if (username != null && username.isNotEmpty) {
        await userCredential.user?.updateDisplayName(username);
      }
      
      // Register with backend
      await _registerWithBackend(userCredential.user!, username ?? '');
      
      return userCredential;
    } catch (e) {
      print('Registration error: $e');
      
      // If Firebase registration succeeded but backend failed, clean up Firebase user
      if (e is! FirebaseAuthException && _auth.currentUser != null) {
        try {
          await _auth.currentUser!.delete();
          print('Deleted Firebase user after backend registration failed');
        } catch (deleteError) {
          print('Error deleting Firebase user: $deleteError');
        }
      }
      
      rethrow;
    }
  }
  
  // Register with backend
  Future<void> _registerWithBackend(User user, String username) async {
    try {
      print('Registering user with backend: ${user.uid}');
      
      // Get the Firebase token
      final String? token = await user.getIdToken();
      
      // Make the API request to your backend
      final response = await http.post(
        Uri.parse('$apiUrl/users/register'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': token != null ? 'Bearer $token' : '',
        },
        body: jsonEncode({
          'email': user.email,
          'username': username.isNotEmpty ? username : user.displayName ?? 'User',
          'firebaseUid': user.uid,
        }),
      );
      
      print('Backend registration response: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      if (response.statusCode != 201) {
        throw Exception('Failed to register with backend: ${response.body}');
      }
      
      print('User successfully registered with backend');
    } catch (e) {
      print('Backend registration error: $e');
      rethrow;
    }
  }
  
  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _secureStorage.delete(key: 'authToken');
      await _secureStorage.delete(key: 'tokenExpiry');
    } catch (e) {
      print('Sign out error: $e');
      rethrow;
    }
  }
  
  // Get auth token with auto-refresh if needed
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    try {
      // Check if token exists and is not expired
      if (!forceRefresh) {
        final expiryTimeStr = await _secureStorage.read(key: 'tokenExpiry');
        final token = await _secureStorage.read(key: 'authToken');
        
        if (token != null && expiryTimeStr != null) {
          final expiryTime = int.parse(expiryTimeStr);
          final now = DateTime.now().millisecondsSinceEpoch;
          
          // If token is still valid (with 5 min buffer), return it
          if (now < expiryTime - (5 * 60 * 1000)) {
            return token;
          }
        }
      }
      
      // Token doesn't exist, is expired, or force refresh requested
      final user = _auth.currentUser;
      if (user == null) {
        return null;
      }
      
      // Get a fresh token
      final idToken = await user.getIdToken(true);
      print('Got fresh token: ${idToken?.substring(0, 10)}...');
      
      // Store the new token
      await _secureStorage.write(key: 'authToken', value: idToken);
      
      // Update expiry time (1 hour from now)
      final expiryTime = DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch.toString();
      await _secureStorage.write(key: 'tokenExpiry', value: expiryTime);
      
      return idToken;
    } catch (e) {
      print('Get token error: $e');
      return null;
    }
  }
  
  // Send email verification
  Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }
    } catch (e) {
      print('Email verification error: $e');
      rethrow;
    }
  }
  
  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      print('Password reset error: $e');
      rethrow;
    }
  }
  
  // Refresh user data
  Future<void> refreshUserData() async {
    try {
      await _auth.currentUser?.reload();
    } catch (e) {
      print('Refresh user data error: $e');
      rethrow;
    }
  }
  
  // Check if user exists in backend
  Future<bool> checkUserExistsInBackend() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return false;
      }
      
      final token = await getIdToken();
      if (token == null) {
        return false;
      }
      
      final response = await http.get(
        Uri.parse('$apiUrl/users/me'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Error checking user in backend: $e');
      return false;
    }
  }
}

