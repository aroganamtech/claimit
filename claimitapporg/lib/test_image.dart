import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class TestImageScreen extends StatefulWidget {
  const TestImageScreen({super.key});
  @override
  State<TestImageScreen> createState() => _TestImageScreenState();
}

class _TestImageScreenState extends State<TestImageScreen> {
  String _status = 'Loading...';
  String _imageUrl = '';
  String _rawResponse = '';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const String _baseUrl = 'https://claimitorgbackend.vercel.app';

  @override
  void initState() {
    super.initState();
    _fetchFirstShop();
  }

  Future<void> _fetchFirstShop() async {
    setState(() { _status = 'Reading token...'; _imageUrl = ''; _rawResponse = ''; });

    final token = await _storage.read(key: 'access_token');

    if (token == null || token.isEmpty) {
      setState(() { _status = 'NOT LOGGED IN\nNo token in secure storage.\nLogin to the app first.'; });
      return;
    }

    setState(() { _status = 'Token found (${token.length} chars)\nCalling /shops...'; });

    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/shops'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));

      final body = resp.body;
      setState(() {
        _rawResponse = 'HTTP ${resp.statusCode}\n'
            '${body.length > 500 ? body.substring(0, 500) + '...' : body}';
      });

      if (resp.statusCode == 200) {
        final data = jsonDecode(body);
        final shops = (data['shops'] as List?) ?? [];
        if (shops.isNotEmpty) {
          // Find first shop with a non-empty image_url (presigned URL)
          Map<String, dynamic>? picked;
          for (final s in shops) {
            final shop = s as Map<String, dynamic>;
            final url = (shop['image_url'] as String?) ?? '';
            if (url.isNotEmpty) { picked = shop; break; }
          }
          final summary = shops.map((s) {
            final shop = s as Map<String, dynamic>;
            final name = shop['name'] ?? shop['shop_name'] ?? '?';
            final url = (shop['image_url'] as String?) ?? '';
            return '$name → url(${url.length}c)';
          }).join('\n');

          if (picked != null) {
            final url = (picked['image_url'] as String?) ?? '';
            setState(() {
              _imageUrl = url;
              _status = 'Found shop with URL: ${picked!['name']}\n'
                  'URL (${url.length} chars):\n$url\n\n'
                  'All shops:\n$summary';
            });
          } else {
            setState(() {
              _status = 'NO SHOPS HAVE image_url!\nAll shops:\n$summary';
            });
          }
        } else {
          setState(() { _status = 'No shops returned'; });
        }
      } else {
        setState(() { _status = 'API error: HTTP ${resp.statusCode}'; });
      }
    } catch (e) {
      setState(() { _status = 'Exception: $e'; });
    }
  }

  Future<void> _testDirectHttp() async {
    if (_imageUrl.isEmpty) return;
    setState(() { _status = 'Testing URL with http.get...'; });
    try {
      final resp = await http.get(Uri.parse(_imageUrl))
          .timeout(const Duration(seconds: 15));
      setState(() {
        _status = 'Direct HTTP GET:\n'
            'Status: ${resp.statusCode}\n'
            'Content-Type: ${resp.headers['content-type']}\n'
            'Bytes: ${resp.bodyBytes.length} bytes\n'
            '${resp.statusCode != 200 ? resp.body.substring(0, resp.body.length.clamp(0, 200)) : "SUCCESS - image loaded!"}';
      });
    } catch (e) {
      setState(() { _status = 'Direct HTTP error: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('S3 Image Test'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchFirstShop)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Status
          Container(
            width: double.infinity, padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: SelectableText(_status,
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
          ),
          const SizedBox(height: 16),

          // Image.network
          const Text('Image.network result:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity, height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _imageUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      _imageUrl, fit: BoxFit.cover,
                      loadingBuilder: (_, child, prog) => prog == null
                          ? child
                          : const Center(child: CircularProgressIndicator()),
                      errorBuilder: (_, error, __) => Container(
                        color: Colors.red[50],
                        child: Center(child: Text(
                          'Image.network FAILED:\n$error',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red, fontSize: 11),
                        )),
                      ),
                    ))
                : const Center(child: Text('No URL yet', style: TextStyle(color: Colors.grey))),
          ),
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _imageUrl.isNotEmpty ? _testDirectHttp : null,
              child: const Text('Test URL with http.get directly'),
            ),
          ),
          const SizedBox(height: 16),

          const Text('Raw API response:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black87, borderRadius: BorderRadius.circular(8)),
            child: SelectableText(_rawResponse,
                style: const TextStyle(
                  color: Colors.greenAccent, fontSize: 10, fontFamily: 'monospace')),
          ),
        ]),
      ),
    );
  }
}
