class UserModel {
  final int id;
  final String fullName;
  final String email;
  final String password;
  final String createdAt;

  UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.password,
    required this.createdAt,
  });

  // From CSV row list
  factory UserModel.fromCsv(List<dynamic> row) {
    return UserModel(
      id: int.tryParse(row[0].toString()) ?? 0,
      fullName: row[1].toString().trim(),
      email: row[2].toString().trim().toLowerCase(),
      password: row[3].toString().trim(),
      createdAt: row[4].toString().trim(),
    );
  }

  // To CSV row list
  List<dynamic> toCsv() {
    return [id, fullName, email, password, createdAt];
  }
}