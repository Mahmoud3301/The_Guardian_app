// lib/core/person_store.dart
// Shared singleton — holds known people and risk people across pages

class PersonRecord {
  final String name;
  final String role;       // 'Owner' or 'Visitor'
  final String imagePath;

  const PersonRecord({
    required this.name,
    required this.role,
    required this.imagePath,
  });
}

class RiskRecord {
  final String imagePath;
  final String action;     // 'Lock Door' or 'Call Emergency'
  final DateTime time;

  RiskRecord({
    required this.imagePath,
    required this.action,
    required this.time,
  });
}

class PersonStore {
  PersonStore._();
  static final PersonStore instance = PersonStore._();

  // Pre-seeded known people
  final List<PersonRecord> people = [
    const PersonRecord(name: 'Mahmoud', role: 'Owner',   imagePath: 'assets/images/person1.jpeg'),
    const PersonRecord(name: 'Mohab',   role: 'Owner',   imagePath: 'assets/images/person2.jpeg'),
    const PersonRecord(name: 'Mina',    role: 'Owner',   imagePath: 'assets/images/person3.jpeg'),
    const PersonRecord(name: 'Ali',     role: 'Owner',   imagePath: 'assets/images/person4.jpeg'),
    const PersonRecord(name: 'Amr',     role: 'Visitor', imagePath: 'assets/images/person5.jpeg'),
    const PersonRecord(name: 'Nabil',   role: 'Visitor', imagePath: 'assets/images/person7.jpeg'),
  ];

  final List<RiskRecord> riskPeople = [];

  void addPerson(String name, String role, String imagePath) {
    people.add(PersonRecord(name: name, role: role, imagePath: imagePath));
  }

  void addRisk(String imagePath, String action) {
    riskPeople.add(RiskRecord(
      imagePath: imagePath,
      action: action,
      time: DateTime.now(),
    ));
  }
}