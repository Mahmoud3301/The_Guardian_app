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


import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/user_model.dart';

class AuthResult {
  final bool success;
  final String message;
  final UserModel? user;

  AuthResult({required this.success, required this.message, this.user});
}

class AuthService {
  static const String _usersKey = 'guardian_users_v1';
  static const String _eventsKey = 'guardian_auth_events_csv_v1';

  static Future<List<Map<String, dynamic>>> _readUsersRaw() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_usersKey);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<void> _writeUsersRaw(List<Map<String, dynamic>> users) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usersKey, jsonEncode(users));
  }

  static String _today() {
    final now = DateTime.now();
    return '${now.day}/${now.month}/${now.year}';
  }

  static String _csvEsc(String v) => '"${v.replaceAll('"', '""')}"';

  static Future<void> _appendAudit({
    required String action,
    required String email,
    required bool success,
    String name = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_eventsKey) ?? <String>[];
    if (existing.isEmpty) {
      existing.add('timestamp,action,email,name,success');
    }
    existing.add(
      '${_csvEsc(DateTime.now().toIso8601String())},${_csvEsc(action)},${_csvEsc(email)},${_csvEsc(name)},${success ? 'true' : 'false'}',
    );
    await prefs.setStringList(_eventsKey, existing);
  }

  static Future<String> exportAuthEventsCsv() async {
    final prefs = await SharedPreferences.getInstance();
    final rows = prefs.getStringList(_eventsKey) ?? const ['timestamp,action,email,name,success'];
    return rows.join('\n');
  }

  static Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final normalizedEmail = email.trim().toLowerCase();
    final users = await _readUsersRaw();
    final idx = users.indexWhere(
      (u) =>
          (u['email']?.toString().trim().toLowerCase() ?? '') == normalizedEmail &&
          (u['password']?.toString() ?? '') == password,
    );

    if (idx == -1) {
      await _appendAudit(action: 'login', email: normalizedEmail, success: false);
      return AuthResult(success: false, message: 'Incorrect email or password.');
    }

    final user = users[idx];
    final loginCount = (user['loginCount'] as int? ?? 0) + 1;
    user['loginCount'] = loginCount;
    user['lastLoginAt'] = DateTime.now().toIso8601String();
    users[idx] = user;
    await _writeUsersRaw(users);
    await _appendAudit(
      action: 'login',
      email: normalizedEmail,
      name: user['fullName']?.toString() ?? '',
      success: true,
    );

    return AuthResult(
      success: true,
      message: 'Login successful!',
      user: UserModel(
        id: user['id'] as int? ?? 1,
        fullName: user['fullName']?.toString() ?? 'User',
        email: normalizedEmail,
        password: password,
        createdAt: user['createdAt']?.toString() ?? _today(),
      ),
    );
  }

  static Future<AuthResult> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedName = fullName.trim().isEmpty ? 'User' : fullName.trim();
    final users = await _readUsersRaw();
    final exists = users.any(
      (u) => (u['email']?.toString().trim().toLowerCase() ?? '') == normalizedEmail,
    );
    if (exists) {
      await _appendAudit(action: 'signup', email: normalizedEmail, name: normalizedName, success: false);
      return AuthResult(success: false, message: 'An account with this email already exists.');
    }

    final nextId = users.isEmpty
        ? 1
        : users.map((u) => (u['id'] as int? ?? 0)).reduce((a, b) => a > b ? a : b) + 1;
    final newUser = <String, dynamic>{
      'id': nextId,
      'fullName': normalizedName,
      'email': normalizedEmail,
      'password': password,
      'createdAt': _today(),
      'loginCount': 0,
      'lastLoginAt': '',
    };
    users.add(newUser);
    await _writeUsersRaw(users);
    await _appendAudit(action: 'signup', email: normalizedEmail, name: normalizedName, success: true);

    return AuthResult(
      success: true,
      message: 'Account created successfully!',
      user: UserModel(
        id: nextId,
        fullName: normalizedName,
        email: normalizedEmail,
        password: password,
        createdAt: _today(),
      ),
    );
  }

  static Future<AuthResult> resetPassword({
    required String email,
    required String oldPassword,
    required String newPassword,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final normalizedEmail = email.trim().toLowerCase();
    final users = await _readUsersRaw();
    final idx = users.indexWhere(
      (u) =>
          (u['email']?.toString().trim().toLowerCase() ?? '') == normalizedEmail &&
          (u['password']?.toString() ?? '') == oldPassword,
    );
    if (idx == -1) {
      return AuthResult(success: false, message: 'Old password is incorrect or email not found.');
    }
    final updated = Map<String, dynamic>.from(users[idx]);
    updated['password'] = newPassword;
    users[idx] = updated;
    await _writeUsersRaw(users);

    return AuthResult(
      success: true,
      message: 'Password updated successfully!',
    );
  }

  static Future<bool> emailExists(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    final users = await _readUsersRaw();
    return users.any(
      (u) => (u['email']?.toString().trim().toLowerCase() ?? '') == normalizedEmail,
    );
  }

  // ── GOOGLE SIGN IN (via Supabase OAuth) ──────────────────────────────────
  static Future<AuthResult> signInWithGoogle() async {
    try {
      final supabase = (await _getSupabase());
      if (supabase == null) {
        return AuthResult(
          success: false,
          message: 'Supabase not initialized. Please try again.',
        );
      }

      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.theguardian://login-callback/',
      );

      // Check if user is signed in after OAuth
      await Future.delayed(const Duration(seconds: 2));
      final session = supabase.auth.currentSession;
      if (session != null) {
        final authUser = supabase.auth.currentUser;
        final email = authUser?.email ?? 'google_user@gmail.com';
        final name = authUser?.userMetadata?['full_name']?.toString() ??
            authUser?.userMetadata?['name']?.toString() ??
            'Google User';

        // Save locally
        final users = await _readUsersRaw();
        final exists = users.any(
          (u) => (u['email']?.toString().trim().toLowerCase() ?? '') == email.toLowerCase(),
        );
        if (!exists) {
          final nextId = users.isEmpty
              ? 1
              : users.map((u) => (u['id'] as int? ?? 0)).reduce((a, b) => a > b ? a : b) + 1;
          users.add({
            'id': nextId,
            'fullName': name,
            'email': email.toLowerCase(),
            'password': '',
            'createdAt': _today(),
            'loginCount': 1,
            'lastLoginAt': DateTime.now().toIso8601String(),
            'provider': 'google',
          });
          await _writeUsersRaw(users);
        }

        await _appendAudit(action: 'google_signin', email: email, name: name, success: true);

        return AuthResult(
          success: true,
          message: 'Signed in with Google!',
          user: UserModel(
            id: 1,
            fullName: name,
            email: email,
            password: '',
            createdAt: _today(),
          ),
        );
      }

      // OAuth flow started but user hasn't completed yet
      return AuthResult(
        success: false,
        message: 'Google sign-in cancelled or pending. Please try again.',
      );
    } catch (e) {
      return AuthResult(success: false, message: 'Google sign-in failed: $e');
    }
  }

  // ── APPLE SIGN IN (via Supabase OAuth) ──────────────────────────────────
  static Future<AuthResult> signInWithApple() async {
    try {
      final supabase = (await _getSupabase());
      if (supabase == null) {
        return AuthResult(
          success: false,
          message: 'Supabase not initialized. Please try again.',
        );
      }

      await supabase.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: 'io.supabase.theguardian://login-callback/',
      );

      await Future.delayed(const Duration(seconds: 2));
      final session = supabase.auth.currentSession;
      if (session != null) {
        final authUser = supabase.auth.currentUser;
        final email = authUser?.email ?? 'apple_user@icloud.com';
        final name = authUser?.userMetadata?['full_name']?.toString() ?? 'Apple User';

        final users = await _readUsersRaw();
        final exists = users.any(
          (u) => (u['email']?.toString().trim().toLowerCase() ?? '') == email.toLowerCase(),
        );
        if (!exists) {
          final nextId = users.isEmpty
              ? 1
              : users.map((u) => (u['id'] as int? ?? 0)).reduce((a, b) => a > b ? a : b) + 1;
          users.add({
            'id': nextId,
            'fullName': name,
            'email': email.toLowerCase(),
            'password': '',
            'createdAt': _today(),
            'loginCount': 1,
            'lastLoginAt': DateTime.now().toIso8601String(),
            'provider': 'apple',
          });
          await _writeUsersRaw(users);
        }

        await _appendAudit(action: 'apple_signin', email: email, name: name, success: true);

        return AuthResult(
          success: true,
          message: 'Signed in with Apple!',
          user: UserModel(
            id: 1,
            fullName: name,
            email: email,
            password: '',
            createdAt: _today(),
          ),
        );
      }

      return AuthResult(
        success: false,
        message: 'Apple sign-in cancelled or pending. Please try again.',
      );
    } catch (e) {
      return AuthResult(success: false, message: 'Apple sign-in failed: $e');
    }
  }

  // Helper to get Supabase client
  static Future<dynamic> _getSupabase() async {
    try {
      final supabase = Supabase.instance.client;
      return supabase;
    } catch (_) {
      return null;
    }
  }
}