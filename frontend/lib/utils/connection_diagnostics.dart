import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ConnectionDiagnostics {
  static Future<Map<String, dynamic>> runDiagnostics(String serverUrl) async {
    Map<String, dynamic> results = {};
    
    // Get device info
    results['platform'] = kIsWeb ? 'Web' : Platform.operatingSystem;
    results['serverUrl'] = serverUrl;
    
    // Test if we can reach common internet sites
    results['internetConnectivity'] = await _testInternetConnectivity();
    
    // Test if we can reach the server
    results['serverConnectivity'] = await _testServerConnectivity(serverUrl);
    
    // Get local IP (not available on web)
    if (!kIsWeb) {
      try {
        results['localIPs'] = await _getLocalIPs();
      } catch (e) {
        results['localIPs'] = 'Error: $e';
      }
    }
    
    return results;
  }
  
  static Future<bool> _testInternetConnectivity() async {
    try {
      final response = await http.get(
        Uri.parse('https://www.google.com'),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      print('Internet connectivity test failed: $e');
      return false;
    }
  }
  
  static Future<Map<String, dynamic>> _testServerConnectivity(String serverUrl) async {
    Map<String, dynamic> results = {};
    
    try {
      final response = await http.get(
        Uri.parse(serverUrl),
      ).timeout(const Duration(seconds: 5));
      
      results['status'] = response.statusCode;
      results['success'] = response.statusCode >= 200 && response.statusCode < 300;
      results['responseSize'] = response.body.length;
      
      return results;
    } catch (e) {
      results['error'] = e.toString();
      results['success'] = false;
      return results;
    }
  }
  
  static Future<List<String>> _getLocalIPs() async {
    List<String> addresses = [];
    
    try {
      List<NetworkInterface> interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          addresses.add('${addr.address} (${interface.name})');
        }
      }
      
      return addresses;
    } catch (e) {
      print('Error getting local IPs: $e');
      return ['Error: $e'];
    }
  }
}
