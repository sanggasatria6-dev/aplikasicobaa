import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Model untuk menyimpan status User
class UserState {
  final String? token;
  final String? username;
  final bool isLoggedIn;

  UserState({this.token, this.username, this.isLoggedIn = false});
}

class AuthNotifier extends StateNotifier<UserState> {
  AuthNotifier() : super(UserState());

 
  // 1. Fungsi Login (Simpan Token & Data User ke HP)
  Future<void> loginSuccess(String username, String token) async {
    final prefs = await SharedPreferences.getInstance();
    // Simpan data permanen
    await prefs.setString('api_token', token);
    await prefs.setString('username', username);
    
    // Update State Aplikasi biar halaman berubah
    state = UserState(token: token, username: username, isLoggedIn: true);
  }

  // 2. Cek Sesi Saat Aplikasi Dibuka (Auto Login)
  Future<void> checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('api_token');
    final username = prefs.getString('username');
    
    if (token != null && token.isNotEmpty) {
      state = UserState(token: token, username: username, isLoggedIn: true);
    }
  }

  // 3. Logout (Hapus Token)
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Hapus semua data sesi
    state = UserState(isLoggedIn: false);
  }
}

// Daftarkan Provider agar bisa dipanggil di mana saja
final authProvider = StateNotifierProvider<AuthNotifier, UserState>((ref) {
  return AuthNotifier();
});