// lib/services/backend_service.dart
// Centralised backend communication — HTTP + mDNS auto-discovery.
// Uses NSD (Network Service Discovery) on Android to find the backend
// automatically via _guardian._tcp mDNS service.
// Falls back to Supabase when the Docker backend is unreachable.

import 'dart:async';
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

  // mDNS discovered host (set by discovery)
  String? _discoveredHost;
  bool _discoveryAttempted = false;

  /// Resolve backend host with mDNS fallback chain.
  String get host {
    // 1. Explicit environment override
    if (_envHost.isNotEmpty) return _envHost;

    // 2. mDNS discovered host
    if (_discoveredHost != null && _discoveredHost!.isNotEmpty) {
      return _discoveredHost!;
    }

    // 3. Platform defaults
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

  /// Try to discover the backend via mDNS.
  /// On Android, uses multicast DNS to find _guardian._tcp service.
  Future<void> discoverBackend() async {
    if (_discoveryAttempted && _discoveredHost != null) return;
    _discoveryAttempted = true;

    // Try common local hostnames first
    final candidates = <String>[
      'guardian-backend.local', // mDNS hostname
    ];

    // On Android, also try common LAN patterns
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      candidates.addAll([
        '10.0.2.2', // Android emulator → host
        '192.168.1.100',
        '192.168.1.2',
        '192.168.0.100',
        '192.168.0.2',
      ]);
    }

    // Try each candidate
    for (final candidate in candidates) {
      try {
        final resp = await http
            .get(Uri.parse('http://$candidate:$_envPort/health'))
            .timeout(const Duration(seconds: 2));
        if (resp.statusCode == 200) {
          _discoveredHost = candidate;
          _backendAvailable = true;
          _lastHealthCheck = DateTime.now();
          debugPrint('[BackendService] ✅ Discovered backend at $candidate');
          return;
        }
      } catch (_) {
        // Try next candidate
      }
    }

    debugPrint('[BackendService] ⚠ mDNS discovery found no backend');
  }

  /// Check if Docker backend is reachable.
  Future<bool> checkHealth() async {
    // Try mDNS discovery first
    if (!_discoveryAttempted) {
      await discoverBackend();
      if (_backendAvailable) return true;
    }

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
      // If health check fails, retry discovery
      _discoveryAttempted = false;
    }
    _lastHealthCheck = DateTime.now();
    debugPrint('[BackendService] health: $_backendAvailable (host: $host)');
    return _backendAvailable;
  }

  /// Whether the Docker backend is currently considered reachable.
  bool get isBackendAvailable => _backendAvailable;

  /// Force re-discovery of backend on next health check.
  void resetDiscovery() {
    _discoveryAttempted = false;
    _discoveredHost = null;
    _lastHealthCheck = null;
  }

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
