// lib/services/supabase_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Direct Supabase Storage operations for face photos.
// Mirrors the Python SupabaseFaceDatabase class so both the desktop
// app and the Flutter mobile app share the same bucket layout:
//
//   DataBase/
//     faces/{person_name_lower}/latest.jpg
//     faces/{person_name_lower}/face_{ts}.jpg
//     embeddings/{person_name_lower}/{ts}.json
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';

/// Lightweight data class returned when listing known persons.
class SupabasePersonInfo {
  final String name;
  final String normalizedName;
  final int photoCount;
  final String? latestPhotoUrl;
  final List<String> allPhotoUrls;

  const SupabasePersonInfo({
    required this.name,
    required this.normalizedName,
    required this.photoCount,
    this.latestPhotoUrl,
    this.allPhotoUrls = const [],
  });
}

class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  SupabaseClient get _client => Supabase.instance.client;
  SupabaseStorageClient get _storage => _client.storage;

  String get _bucket => SupabaseConfig.bucketName;
  String get _photos => SupabaseConfig.photosPath;
  String get _embeddings => SupabaseConfig.embeddingsPath;

  // ── In-memory cache ──────────────────────────────────────────────────────
  final List<String> _knownNames = [];
  List<String> get knownNames => List.unmodifiable(_knownNames);
  int get nameCount => _knownNames.length;

  bool _initialised = false;
  bool get isReady => _initialised;

  // ── Initialise: load list of known persons from Storage ──────────────────
  Future<void> init() async {
    if (_initialised) return;
    await refresh();
    _initialised = true;
  }

  /// Reload known person list from Supabase Storage.
  Future<void> refresh() async {
    try {
      final folders = await _storage.from(_bucket).list(path: _photos);
      final names = <String>[];
      for (final item in folders) {
        if (item.name.isNotEmpty) {
          names.add(item.name);
        }
      }
      _knownNames
        ..clear()
        ..addAll(names);
      debugPrint('[SupabaseService] Loaded ${_knownNames.length} known persons');
    } catch (e) {
      debugPrint('[SupabaseService] refresh error: $e');
    }
  }

  // ── Upload a face photo ──────────────────────────────────────────────────
  /// Upload [imageBytes] as a JPEG for [name].
  /// Also uploads as `latest.jpg` for quick avatar lookup.
  Future<String?> uploadFacePhoto(
    String name,
    Uint8List imageBytes, {
    String? customFilename,
  }) async {
    final normalized = name.toLowerCase().trim();
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    final filename = customFilename ?? 'face_$ts.jpg';
    final path = '$_photos/$normalized/$filename';

    try {
      await _storage.from(_bucket).uploadBinary(
            path,
            imageBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      // Also save as latest.jpg
      final latestPath = '$_photos/$normalized/latest.jpg';
      await _storage.from(_bucket).uploadBinary(
            latestPath,
            imageBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      // Update cache
      if (!_knownNames.contains(normalized)) {
        _knownNames.add(normalized);
      }

      final publicUrl = _storage.from(_bucket).getPublicUrl(path);
      debugPrint('[SupabaseService] Uploaded photo for $normalized');
      return publicUrl;
    } catch (e) {
      debugPrint('[SupabaseService] uploadFacePhoto error: $e');
      return null;
    }
  }

  // ── Upload face encoding (JSON) ─────────────────────────────────────────
  /// Upload the face-encoding JSON for [name].  
  /// The Python side expects: { "encodings": [[128 floats]] }
  Future<bool> uploadEncoding(String name, List<double> encoding) async {
    final normalized = name.toLowerCase().trim();
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    final filename = '$ts.json';
    final path = '$_embeddings/$normalized/$filename';
    final data = jsonEncode({
      'encodings': [encoding]
    });

    try {
      await _storage.from(_bucket).uploadBinary(
            path,
            Uint8List.fromList(utf8.encode(data)),
            fileOptions: const FileOptions(
              contentType: 'application/json',
              upsert: true,
            ),
          );
      debugPrint('[SupabaseService] Uploaded encoding for $normalized');
      return true;
    } catch (e) {
      debugPrint('[SupabaseService] uploadEncoding error: $e');
      return false;
    }
  }

  // ── Get person photos ────────────────────────────────────────────────────
  Future<List<String>> getPersonPhotos(String name) async {
    final normalized = name.toLowerCase().trim();
    final prefix = '$_photos/$normalized';
    try {
      final files = await _storage.from(_bucket).list(path: prefix);
      final urls = <String>[];
      for (final file in files) {
        final fname = file.name;
        if (fname.toLowerCase().endsWith('.jpg') ||
            fname.toLowerCase().endsWith('.jpeg') ||
            fname.toLowerCase().endsWith('.png')) {
          urls.add(_storage.from(_bucket).getPublicUrl('$prefix/$fname'));
        }
      }
      return urls;
    } catch (e) {
      debugPrint('[SupabaseService] getPersonPhotos error: $e');
      return [];
    }
  }

  /// Get info about a person including photo URLs.
  Future<SupabasePersonInfo> getPersonInfo(String name) async {
    final normalized = name.toLowerCase().trim();
    final photos = await getPersonPhotos(normalized);
    String? latest;
    for (final p in photos) {
      if (p.contains('latest.jpg')) {
        latest = p;
        break;
      }
    }
    if (latest == null && photos.isNotEmpty) {
      latest = photos.first;
    }

    return SupabasePersonInfo(
      name: name,
      normalizedName: normalized,
      photoCount: photos.length,
      latestPhotoUrl: latest,
      allPhotoUrls: photos,
    );
  }

  /// Get the latest photo URL for quick avatar display.
  String getLatestPhotoUrl(String name) {
    final normalized = name.toLowerCase().trim();
    return _storage
        .from(_bucket)
        .getPublicUrl('$_photos/$normalized/latest.jpg');
  }

  /// Convenience: check if a person exists in our cache.
  bool hasPerson(String name) {
    return _knownNames.contains(name.toLowerCase().trim());
  }

  // ── List all known persons with info ──────────────────────────────────────
  Future<List<SupabasePersonInfo>> listAllPersons() async {
    await refresh();
    final result = <SupabasePersonInfo>[];
    for (final name in _knownNames) {
      try {
        final info = await getPersonInfo(name);
        result.add(info);
      } catch (_) {
        result.add(SupabasePersonInfo(
          name: name,
          normalizedName: name,
          photoCount: 0,
        ));
      }
    }
    return result;
  }
}
