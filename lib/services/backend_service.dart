// lib/services/backend_service.dart
// Centralised backend communication — HTTP + host resolution.
// Now falls back to Supabase when the Docker backend is unreachable,
// so the app works standalone on phones (Play Store / App Store).

import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'supabase_service.dart';

class BackendService {
  BackendService._();
  static final BackendService instance = BackendService._();

  static const String _envHost =
      String.fromEnvironment('BACKEND_HOST', defaultValue: '');
  static const String _envPort =
      String.fromEnvironment('BACKEND_PORT', defaultValue: '8000');

  bool _backendAvailable = true;
  DateTime? _lastHealthCheck;

  /// Resolve backend host.
  String get host {
    if (_envHost.isNotEmpty) return _envHost;
    if (kIsWeb) {
      final pageHost = Uri.base.host;
      return pageHost.isNotEmpty ? pageHost : 'localhost';
    }
    if (defaultTargetPlatform == TargetPlatform.android) return '10.0.2.2';
    return 'localhost';
  }

  String get port => _envPort;
  String get httpBase => 'http://$host:$port';
  Uri get wsUri => Uri.parse('ws://$host:$port/ws');

  /// Check if Docker backend is reachable.
  Future<bool> checkHealth() async {
    // Only check once every 30 seconds to avoid spamming
    if (_lastHealthCheck != null &&
        DateTime.now().difference(_lastHealthCheck!) < const Duration(seconds: 30)) {
      return _backendAvailable;
    }
    try {
      final resp = await http
          .get(Uri.parse('$httpBase/health'))
          .timeout(const Duration(seconds: 3));
      _backendAvailable = resp.statusCode == 200;
    } catch (_) {
      _backendAvailable = false;
    }
    _lastHealthCheck = DateTime.now();
    debugPrint('[BackendService] health: $_backendAvailable');
    return _backendAvailable;
  }

  /// Whether the Docker backend is currently considered reachable.
  bool get isBackendAvailable => _backendAvailable;

  /// Register a face — try Docker backend first, fall back to Supabase.
  Future<bool> addFace(String name, Uint8List imageBytes) async {
    // 1) Try Docker backend
    if (await _tryBackendAddFace(name, imageBytes)) return true;

    // 2) Fall back to Supabase Storage
    return _supabaseFallbackAddFace(name, imageBytes);
  }

  Future<bool> _tryBackendAddFace(String name, Uint8List imageBytes) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$httpBase/add_face'),
      );
      request.fields['name'] = name;
      request.files.add(
        http.MultipartFile.fromBytes('file', imageBytes, filename: 'face.jpg'),
      );
      final response =
          await request.send().timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        debugPrint('[BackendService] addFace via Docker OK');
        return true;
      }
    } catch (e) {
      debugPrint('[BackendService] Docker addFace failed: $e');
    }
    return false;
  }

  Future<bool> _supabaseFallbackAddFace(
      String name, Uint8List imageBytes) async {
    try {
      final url =
          await SupabaseService.instance.uploadFacePhoto(name, imageBytes);
      if (url != null) {
        debugPrint('[BackendService] addFace via Supabase OK');
        return true;
      }
    } catch (e) {
      debugPrint('[BackendService] Supabase addFace failed: $e');
    }
    return false;
  }
}
