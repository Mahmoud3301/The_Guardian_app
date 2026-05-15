// lib/core/person_store.dart
// Shared singleton — holds known people and risk people across pages.
// Now syncs with Supabase Storage so photos show from cloud,
// and falls back to bundled assets when network is unavailable.
// Uses real photos for owners: Mahmoud, Mohab, Mina.

import 'dart:typed_data';
import '../services/supabase_service.dart';

class PersonRecord {
  final String name;
  final String role;       // 'Owner' or 'Visitor'
  final String imagePath;  // local asset OR Supabase public URL
  final Uint8List? imageBytes;  // for dynamically added people
  final String? networkUrl; // Supabase public photo URL

  const PersonRecord({
    required this.name,
    required this.role,
    required this.imagePath,
    this.imageBytes,
    this.networkUrl,
  });
}

class RiskRecord {
  final String imagePath;
  final Uint8List? imageBytes;
  final String action;     // 'Lock Door' or 'Call Emergency'
  final DateTime time;

  RiskRecord({
    required this.imagePath,
    this.imageBytes,
    required this.action,
    required this.time,
  });
}

class PersonStore {
  PersonStore._();
  static final PersonStore instance = PersonStore._();

  bool _supabaseSynced = false;

  // Pre-seeded known people with REAL photos for owners
  final List<PersonRecord> people = [
    const PersonRecord(name: 'Mahmoud', role: 'Owner',   imagePath: 'assets/images/mahmoud.jpeg'),
    const PersonRecord(name: 'Mohab',   role: 'Owner',   imagePath: 'assets/images/mohab.jpeg'),
    const PersonRecord(name: 'Mina',    role: 'Owner',   imagePath: 'assets/images/mina.jpeg'),
  ];

  final List<RiskRecord> riskPeople = [];

  /// Sync pre-seeded owners with Supabase photo URLs.
  /// Enhances existing records with network URLs where the person exists
  /// in Supabase Storage. Also adds any cloud-only persons.
  Future<void> syncWithSupabase() async {
    if (_supabaseSynced) return;
    try {
      final svc = SupabaseService.instance;
      if (!svc.isReady) await svc.init();

      // Update existing people with Supabase photo URLs
      for (int i = 0; i < people.length; i++) {
        final normalized = people[i].name.toLowerCase().trim();
        if (svc.hasPerson(normalized)) {
          final url = svc.getLatestPhotoUrl(normalized);
          people[i] = PersonRecord(
            name: people[i].name,
            role: people[i].role,
            imagePath: people[i].imagePath,
            imageBytes: people[i].imageBytes,
            networkUrl: url,
          );
        }
      }

      // Add cloud-only persons not in our pre-seeded list
      final existingNames = people.map((p) => p.name.toLowerCase().trim()).toSet();
      for (final cloudName in svc.knownNames) {
        if (!existingNames.contains(cloudName)) {
          final url = svc.getLatestPhotoUrl(cloudName);
          people.add(PersonRecord(
            name: cloudName[0].toUpperCase() + cloudName.substring(1),
            role: 'Visitor',
            imagePath: '',
            networkUrl: url,
          ));
        }
      }

      _supabaseSynced = true;
    } catch (e) {
      // Non-fatal: keep using local assets
    }
  }

  void addPerson(String name, String role, String imagePath,
      {Uint8List? imageBytes, String? networkUrl}) {
    people.add(PersonRecord(
      name: name,
      role: role,
      imagePath: imagePath,
      imageBytes: imageBytes,
      networkUrl: networkUrl,
    ));
  }

  void addRisk(String imagePath, String action, {Uint8List? imageBytes}) {
    riskPeople.add(RiskRecord(
      imagePath: imagePath,
      imageBytes: imageBytes,
      action: action,
      time: DateTime.now(),
    ));
  }

  /// Force a full resync from Supabase.
  Future<void> forceRefresh() async {
    _supabaseSynced = false;
    await SupabaseService.instance.refresh();
    await syncWithSupabase();
  }
}