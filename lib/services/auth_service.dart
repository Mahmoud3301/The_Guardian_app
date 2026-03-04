// import 'dart:io';
// import 'package:csv/csv.dart';
// import 'package:flutter/services.dart';
// import 'package:path_provider/path_provider.dart';
// import '../core/user_model.dart';

// class AuthResult {
//   final bool success;
//   final String message;
//   final UserModel? user;

//   AuthResult({required this.success, required this.message, this.user});
// }

// class AuthService {
//   static const String _csvAssetPath = 'assets/data/users.csv';
//   static const String _csvFileName  = 'guardian_users.csv';

//   // ── Get writable CSV file path ───────────────────────────────────────────
//   static Future<File> _getCsvFile() async {
//     final dir  = await getApplicationDocumentsDirectory();
//     final file = File('${dir.path}/$_csvFileName');

//     // First run: copy seed from assets to documents directory
//     if (!await file.exists()) {
//       final seed = await rootBundle.loadString(_csvAssetPath);
//       await file.writeAsString(seed);
//     }
//     return file;
//   }

//   // ── Read all users from CSV ───────────────────────────────────────────────
//   static Future<List<UserModel>> _readUsers() async {
//     final file    = await _getCsvFile();
//     final content = await file.readAsString();
//     final rows    = const CsvToListConverter().convert(content, eol: '\n');

//     if (rows.length <= 1) return []; // only header or empty
//     // skip header row (index 0)
//     return rows.skip(1).where((r) => r.length >= 5).map(UserModel.fromCsv).toList();
//   }

//   // ── Write all users to CSV ────────────────────────────────────────────────
//   static Future<void> _writeUsers(List<UserModel> users) async {
//     final file = await _getCsvFile();
//     final rows = <List<dynamic>>[
//       ['id', 'fullName', 'email', 'password', 'createdAt'], // header
//       ...users.map((u) => u.toCsv()),
//     ];
//     final csv = const ListToCsvConverter().convert(rows);
//     await file.writeAsString(csv);
//   }

//   // ── Next available ID ─────────────────────────────────────────────────────
//   static Future<int> _nextId() async {
//     final users = await _readUsers();
//     if (users.isEmpty) return 1;
//     return users.map((u) => u.id).reduce((a, b) => a > b ? a : b) + 1;
//   }

//   // ── REGISTER ─────────────────────────────────────────────────────────────
//   static Future<AuthResult> register({
//     required String fullName,
//     required String email,
//     required String password,
//   }) async {
//     try {
//       final users = await _readUsers();

//       // Check duplicate email
//       final exists = users.any(
//         (u) => u.email.toLowerCase() == email.trim().toLowerCase(),
//       );
//       if (exists) {
//         return AuthResult(
//           success: false,
//           message: 'An account with this email already exists.',
//         );
//       }

//       final newUser = UserModel(
//         id: await _nextId(),
//         fullName: fullName.trim(),
//         email: email.trim().toLowerCase(),
//         password: password,
//         createdAt: DateTime.now().toIso8601String().split('T').first,
//       );

//       users.add(newUser);
//       await _writeUsers(users);

//       return AuthResult(
//         success: true,
//         message: 'Account created successfully!',
//         user: newUser,
//       );
//     } catch (e) {
//       return AuthResult(success: false, message: 'Registration failed: $e');
//     }
//   }

//   // ── LOGIN ─────────────────────────────────────────────────────────────────
//   static Future<AuthResult> login({
//     required String email,
//     required String password,
//   }) async {
//     try {
//       final users = await _readUsers();

//       final user = users.firstWhere(
//         (u) =>
//             u.email.toLowerCase() == email.trim().toLowerCase() &&
//             u.password == password,
//         orElse: () => UserModel(id: -1, fullName: '', email: '', password: '', createdAt: ''),
//       );

//       if (user.id == -1) {
//         return AuthResult(
//           success: false,
//           message: 'Incorrect email or password.',
//         );
//       }

//       return AuthResult(
//         success: true,
//         message: 'Login successful!',
//         user: user,
//       );
//     } catch (e) {
//       return AuthResult(success: false, message: 'Login failed: $e');
//     }
//   }

//   // ── RESET PASSWORD ────────────────────────────────────────────────────────
//   static Future<AuthResult> resetPassword({
//     required String email,
//     required String oldPassword,
//     required String newPassword,
//   }) async {
//     try {
//       final users = await _readUsers();

//       final index = users.indexWhere(
//         (u) =>
//             u.email.toLowerCase() == email.trim().toLowerCase() &&
//             u.password == oldPassword,
//       );

//       if (index == -1) {
//         return AuthResult(
//           success: false,
//           message: 'Old password is incorrect or email not found.',
//         );
//       }

//       // Replace with updated user
//       final old = users[index];
//       users[index] = UserModel(
//         id: old.id,
//         fullName: old.fullName,
//         email: old.email,
//         password: newPassword,
//         createdAt: old.createdAt,
//       );

//       await _writeUsers(users);

//       return AuthResult(
//         success: true,
//         message: 'Password updated successfully!',
//       );
//     } catch (e) {
//       return AuthResult(success: false, message: 'Reset failed: $e');
//     }
//   }

//   // ── CHECK EMAIL EXISTS (for forgot password flow) ─────────────────────────
//   static Future<bool> emailExists(String email) async {
//     final users = await _readUsers();
//     return users.any(
//       (u) => u.email.toLowerCase() == email.trim().toLowerCase(),
//     );
//   }
// }


import '../core/user_model.dart';

class AuthResult {
  final bool success;
  final String message;
  final UserModel? user;

  AuthResult({required this.success, required this.message, this.user});
}

class AuthService {
  // ── LOGIN — always succeeds, no checks ───────────────────────────────────
  static Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));

    final raw  = email.trim();
    final name = raw.contains('@') ? raw.split('@').first : raw;
    final displayName = name.isNotEmpty
        ? name[0].toUpperCase() + name.substring(1)
        : 'User';

    return AuthResult(
      success: true,
      message: 'Login successful!',
      user: UserModel(
        id: 1,
        fullName: displayName,
        email: raw.isNotEmpty ? raw : 'user@guardian.app',
        password: password,
        createdAt: _today(),
      ),
    );
  }

  // ── REGISTER — always succeeds, no checks ────────────────────────────────
  static Future<AuthResult> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));

    return AuthResult(
      success: true,
      message: 'Account created successfully!',
      user: UserModel(
        id: 1,
        fullName: fullName.trim().isNotEmpty ? fullName.trim() : 'User',
        email: email.trim().isNotEmpty ? email.trim() : 'user@guardian.app',
        password: password,
        createdAt: _today(),
      ),
    );
  }

  // ── RESET PASSWORD — always succeeds, no checks ───────────────────────────
  static Future<AuthResult> resetPassword({
    required String email,
    required String oldPassword,
    required String newPassword,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));

    return AuthResult(
      success: true,
      message: 'Password updated successfully!',
    );
  }

  // ── EMAIL EXISTS — always returns false (no real DB) ──────────────────────
  static Future<bool> emailExists(String email) async {
    return false;
  }

  // ── Helper ────────────────────────────────────────────────────────────────
  static String _today() {
    final now = DateTime.now();
    return '${now.day}/${now.month}/${now.year}';
  }
}