// lib/services/backend_service.dart
// Centralised backend communication — HTTP + automatic network discovery.
// Automatically scans the local WiFi subnet to find the Guardian backend.
// No manual IP configuration needed — just be on the same network!

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'supabase_service.dart';

class BackendService {
  BackendService._();
  static final BackendService instance = BackendService._();

  static const String _envHost = String.fromEnvironment(
    'BACKEND_HOST',
    defaultValue: '',
  );
  static const String _envPort = String.fromEnvironment(
    'BACKEND_PORT',
    defaultValue: '8000',
  );

  bool _backendAvailable = false;
  DateTime? _lastHealthCheck;

  // Auto-discovered host
  String? _discoveredHost;
  bool _discovering = false;

  /// Resolve backend host — uses discovered IP from network scan.
  String get host {
    if (_envHost.isNotEmpty) return _envHost;
    if (_discoveredHost != null && _discoveredHost!.isNotEmpty) {
      return _discoveredHost!;
    }
    if (kIsWeb) {
      final pageHost = Uri.base.host;
      return pageHost.isNotEmpty ? pageHost : 'localhost';
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return '10.0.2.2';
    }
    return 'localhost';
  }

  String get port => _envPort;
  String get httpBase => 'http://$host:$port';
  Uri get wsUri => Uri.parse('ws://$host:$port/ws');

  /// Get the device's local IP to determine the subnet.
  Future<String?> _getLocalIp() async {
    if (kIsWeb) return null;
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          if (ip.startsWith('192.168.') ||
              ip.startsWith('10.') ||
              ip.startsWith('172.')) {
            return ip;
          }
        }
      }
    } catch (e) {
      debugPrint('[BackendService] Could not get local IP: $e');
    }
    return null;
  }

  /// Scan the local subnet to find the Guardian backend automatically.
  Future<void> discoverBackend() async {
    if (_discovering) return;
    _discovering = true;
    debugPrint('[BackendService] 🔍 Starting network discovery...');

    // Priority 1: Try explicit env host
    if (_envHost.isNotEmpty) {
      if (await _tryHost(_envHost)) {
        _discovering = false;
        return;
      }
    }

    // Priority 2: Try mDNS hostname
    if (await _tryHost('guardian-backend.local')) {
      _discovering = false;
      return;
    }

    // Priority 3: Try localhost / emulator host
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      if (await _tryHost('10.0.2.2')) {
        _discovering = false;
        return;
      }
    }
    if (await _tryHost('localhost')) {
      _discovering = false;
      return;
    }

    // Priority 4: Scan the local subnet
    final localIp = await _getLocalIp();
    if (localIp != null) {
      final parts = localIp.split('.');
      if (parts.length == 4) {
        final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';
        debugPrint('[BackendService] 🔍 Scanning subnet $subnet.0/24...');

        // Scan in parallel batches for speed
        final futures = <Future<bool>>[];
        for (int i = 1; i <= 254; i++) {
          final candidateIp = '$subnet.$i';
          if (candidateIp == localIp) continue; // Skip self
          futures.add(_tryHost(candidateIp, timeout: 1));
        }

        // Wait for first success or all failures
        final completer = Completer<void>();
        int completed = 0;
        for (final future in futures) {
          future.then((found) {
            completed++;
            if (found && !completer.isCompleted) {
              completer.complete();
            } else if (completed >= futures.length && !completer.isCompleted) {
              completer.complete();
            }
          });
        }

        // Wait max 5 seconds for subnet scan
        await completer.future.timeout(
          const Duration(seconds: 5),
          onTimeout: () {},
        );
      }
    }

    _discovering = false;
    if (_discoveredHost != null) {
      debugPrint('[BackendService] ✅ Found backend at $_discoveredHost');
    } else {
      debugPrint('[BackendService] ⚠ No backend found on network');
    }
  }

  /// Try to reach a specific host.
  Future<bool> _tryHost(String candidate, {int timeout = 2}) async {
    if (_discoveredHost != null) return false; // Already found
    try {
      final resp = await http
          .get(Uri.parse('http://$candidate:$_envPort/health'))
          .timeout(Duration(seconds: timeout));
      if (resp.statusCode == 200) {
        _discoveredHost = candidate;
        _backendAvailable = true;
        _lastHealthCheck = DateTime.now();
        debugPrint('[BackendService] ✅ Backend found at $candidate');
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Check if Docker backend is reachable.
  Future<bool> checkHealth() async {
    // Auto-discover on first check
    if (_discoveredHost == null) {
      await discoverBackend();
      if (_backendAvailable) return true;
    }

    // Cache health checks for 30 seconds
    if (_lastHealthCheck != null &&
        DateTime.now().difference(_lastHealthCheck!) <
            const Duration(seconds: 30)) {
      return _backendAvailable;
    }

    try {
      final resp = await http
          .get(Uri.parse('$httpBase/health'))
          .timeout(const Duration(seconds: 3));
      _backendAvailable = resp.statusCode == 200;
    } catch (_) {
      _backendAvailable = false;
      // Reset discovery to try again
      _discoveredHost = null;
    }
    _lastHealthCheck = DateTime.now();
    debugPrint('[BackendService] health: $_backendAvailable (host: $host)');
    return _backendAvailable;
  }

  bool get isBackendAvailable => _backendAvailable;

  /// Force re-discovery.
  void resetDiscovery() {
    _discoveredHost = null;
    _backendAvailable = false;
    _lastHealthCheck = null;
    _discovering = false;
  }

  /// Register a face — Docker first, Supabase fallback.
  Future<bool> addFace(String name, Uint8List imageBytes) async {
    if (await _tryBackendAddFace(name, imageBytes)) return true;
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
      final response = await request.send().timeout(
        const Duration(seconds: 15),
      );
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
    String name,
    Uint8List imageBytes,
  ) async {
    try {
      final url = await SupabaseService.instance.uploadFacePhoto(
        name,
        imageBytes,
      );
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
