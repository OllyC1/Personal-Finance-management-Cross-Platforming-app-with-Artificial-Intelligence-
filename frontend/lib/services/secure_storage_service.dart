// lib/services/secure_storage_service.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage = FlutterSecureStorage();
  
  // Singleton pattern
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();
  
  // Save data securely
  Future<void> saveSecureData(String key, String value) async {
    await _storage.write(key: key, value: value);
  }
  
  // Read secure data
  Future<String?> getSecureData(String key) async {
    return await _storage.read(key: key);
  }
  
  // Delete secure data
  Future<void> deleteSecureData(String key) async {
    await _storage.delete(key: key);
  }
  
  // Delete all secure data
  Future<void> deleteAllSecureData() async {
    await _storage.deleteAll();
  }
}