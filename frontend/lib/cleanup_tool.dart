import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CleanupToolScreen extends StatefulWidget {
  const CleanupToolScreen({super.key});

  @override
  _CleanupToolScreenState createState() => _CleanupToolScreenState();
}

class _CleanupToolScreenState extends State<CleanupToolScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  String _resultMessage = '';
  bool _isSuccess = false;

  Future<void> _cleanupUser() async {
    setState(() {
      _isLoading = true;
      _resultMessage = '';
      _isSuccess = false;
    });

    try {
      final response = await http.post(
        Uri.parse('http://localhost:5000/users/cleanup-user'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _emailController.text.trim()}),
      );

      final responseData = jsonDecode(response.body);
      
      setState(() {
        _isSuccess = response.statusCode == 200;
        _resultMessage = responseData['message'] ?? 'Unknown response';
      });
    } catch (e) {
      setState(() {
        _isSuccess = false;
        _resultMessage = 'Error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('User Cleanup Tool'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'This tool helps clean up user accounts that might be causing "email already in use" errors.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 24),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email to clean up',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _cleanupUser,
              child: _isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text('Clean Up User'),
            ),
            SizedBox(height: 24),
            if (_resultMessage.isNotEmpty)
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isSuccess ? Colors.green.shade100 : Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _resultMessage,
                  style: TextStyle(
                    color: _isSuccess ? Colors.green.shade800 : Colors.red.shade800,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}