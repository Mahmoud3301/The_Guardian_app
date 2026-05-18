import 'dart:typed_data';

enum SecurityEventStatus { pending, risk, dismissed }

class SecurityEvent {
  final String id;
  final Uint8List? imageBytes;
  final Uint8List? faceCropBytes;   // clean face crop for registration
  final String imagePathFallback;
  final DateTime createdAt;
  String label;
  SecurityEventStatus status;

  SecurityEvent({
    required this.id,
    required this.imageBytes,
    this.faceCropBytes,
    required this.imagePathFallback,
    required this.createdAt,
    this.label = 'Unknown',
    this.status = SecurityEventStatus.pending,
  });
}

class SecurityEventStore {
  SecurityEventStore._();
  static final SecurityEventStore instance = SecurityEventStore._();

  final List<SecurityEvent> _events = [];

  List<SecurityEvent> get events => List.unmodifiable(_events);

  void addUnknownEvent({
    required Uint8List? imageBytes,
    Uint8List? faceCropBytes,
    String imagePathFallback = 'assets/images/unknown1.jpeg',
  }) {
    _events.insert(
      0,
      SecurityEvent(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        imageBytes: imageBytes,
        faceCropBytes: faceCropBytes,
        imagePathFallback: imagePathFallback,
        createdAt: DateTime.now(),
      ),
    );
  }

  void markRisk(String id) {
    final idx = _events.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    _events[idx].status = SecurityEventStatus.risk;
  }

  void dismiss(String id) {
    final idx = _events.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    _events[idx].status = SecurityEventStatus.dismissed;
  }

  void renameAndDismiss(String id, String name) {
    final idx = _events.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    _events[idx].label = name.trim().isEmpty ? 'Unknown' : name.trim();
    _events[idx].status = SecurityEventStatus.dismissed;
  }

  /// Permanently remove a single event.
  void deleteEvent(String id) {
    _events.removeWhere((e) => e.id == id);
  }

  /// Permanently remove all events.
  void clearAll() {
    _events.clear();
  }

  /// Neglect = dismiss without any label change (ignore it).
  void neglect(String id) {
    final idx = _events.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    _events[idx].status = SecurityEventStatus.dismissed;
  }
}