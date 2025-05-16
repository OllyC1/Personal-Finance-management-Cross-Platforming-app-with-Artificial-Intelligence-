import 'package:flutter/material.dart';
import '../utils/connection_diagnostics.dart';
import '../services/api_service.dart';

class ConnectionTestScreen extends StatefulWidget {
  @override
  _ConnectionTestScreenState createState() => _ConnectionTestScreenState();
}

class _ConnectionTestScreenState extends State<ConnectionTestScreen> {
  Map<String, dynamic> _diagnosticResults = {};
  bool _isLoading = false;
  final ApiService _apiService = ApiService();
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Connection Diagnostics'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'API Connection Diagnostics',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 16),
            Text('Current API URL: ${_apiService.baseUrl}'),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _runDiagnostics,
              child: Text('Run Diagnostics'),
            ),
            SizedBox(height: 24),
            _isLoading 
              ? Center(child: CircularProgressIndicator())
              : Expanded(
                  child: _diagnosticResults.isEmpty
                    ? Text('Press "Run Diagnostics" to start')
                    : SingleChildScrollView(
                        child: _buildDiagnosticResults(),
                      ),
                ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDiagnosticResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildResultCard('Platform', _diagnosticResults['platform']?.toString() ?? 'Unknown'),
        _buildResultCard('Server URL', _diagnosticResults['serverUrl']?.toString() ?? 'Unknown'),
        _buildResultCard(
          'Internet Connectivity', 
          _diagnosticResults['internetConnectivity'] == true ? 'Connected ✅' : 'Not Connected ❌'
        ),
        _buildResultCard(
          'Server Connectivity', 
          _buildServerConnectivityInfo(),
        ),
        if (_diagnosticResults.containsKey('localIPs'))
          _buildResultCard('Local IP Addresses', _formatLocalIPs()),
      ],
    );
  }
  
  Widget _buildResultCard(String title, String content) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(content),
          ],
        ),
      ),
    );
  }
  
  String _buildServerConnectivityInfo() {
    var serverInfo = _diagnosticResults['serverConnectivity'];
    if (serverInfo == null) return 'Unknown';
    
    if (serverInfo['success'] == true) {
      return 'Connected ✅\nStatus: ${serverInfo['status']}\nResponse Size: ${serverInfo['responseSize']} bytes';
    } else {
      return 'Failed to Connect ❌\nError: ${serverInfo['error']}';
    }
  }
  
  String _formatLocalIPs() {
    var ips = _diagnosticResults['localIPs'];
    if (ips is List) {
      return ips.join('\n');
    }
    return ips.toString();
  }
  
  Future<void> _runDiagnostics() async {
    setState(() {
      _isLoading = true;
      _diagnosticResults = {};
    });
    
    try {
      final results = await ConnectionDiagnostics.runDiagnostics(_apiService.baseUrl);
      setState(() {
        _diagnosticResults = results;
      });
    } catch (e) {
      setState(() {
        _diagnosticResults = {
          'error': 'Failed to run diagnostics: $e',
        };
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
