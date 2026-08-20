import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'api_service.dart';
import 'auth_provider.dart';
import 'main.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {

  final _ipCtrl = TextEditingController(text: "https://api.satriasangga.my.id");
  final _passCtrl = TextEditingController(); 
  final _userCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(authProvider.notifier).checkSession();
      if (ref.read(authProvider).isLoggedIn && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainNav()),
        );
      }
    });
  }

  void _doLogin() async {
    // 1. Set status loading untuk memunculkan indikator progress
    setState(() => _isLoading = true);

    // 2. Update alamat IP Server berdasarkan input user (bersihkan trailing slash)
    String cleanUrl = _ipCtrl.text.trim();
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }
    ref.read(baseUrlProvider.notifier).state = cleanUrl;

    final username = _userCtrl.text.trim();
    final password = _passCtrl.text.trim();

    // Validasi input kosong
    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Username & Password Wajib Diisi!")),
      );
      setState(() => _isLoading = false);
      return;
    }

    try {
      // 3. Panggil API Login ke Backend
      final result = await ref.read(apiProvider).loginUser(username, password);

      // 4. Cek apakah login sukses berdasarkan flag dari server
      if (result['success'] == true) {
        
        // PERBAIKAN KRITIS: 
        // Backend (FastAPI) mengembalikan data dalam format: { "data": { "api_token": "..." } }
        // Maka kita harus mengaksesnya lewat key ['data'] terlebih dahulu.
        final userData = result['data'];
        final token = userData['api_token'];

        if (token != null) {
          // 5. Simpan token ke SharedPreferences agar login persisten
          await ref.read(authProvider.notifier).loginSuccess(username, token);

          // 6. Opsional: Pastikan koneksi server stabil sebelum masuk ke dashboard
          await ref.read(apiProvider).getSystemStatus();

          // 7. Pindah ke halaman utama (Dashboard)
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const MainNav()),
            );
          }
        } else {
          throw "Token tidak ditemukan dalam respon server.";
        }
      } else {
        // Jika backend mengirim success: false
        throw result['message'] ?? "Login Gagal.";
      }
    } catch (e) {
      // Tampilkan pesan error jika terjadi kegagalan koneksi atau auth
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      // Pastikan loading dihentikan baik sukses maupun gagal
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo Container
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1FAE5), // Mint Green circle
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF059669).withOpacity(0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      PhosphorIcons.chartLineUpBold,
                      size: 40,
                      color: Color(0xFF059669),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "AI Trader Pro",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Autonomous Trading & Intelligence Platform",
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Login Form Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Masuk Akun",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Server URL
                        const Text(
                          "SERVER URL",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _ipCtrl,
                          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                          decoration: const InputDecoration(
                            hintText: "https://api.satriasangga.my.id",
                            prefixIcon: Icon(PhosphorIcons.globe, color: Color(0xFF64748B), size: 18),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Username
                        const Text(
                          "USERNAME",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _userCtrl,
                          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                          decoration: const InputDecoration(
                            hintText: "Masukkan username",
                            prefixIcon: Icon(PhosphorIcons.user, color: Color(0xFF64748B), size: 18),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Password
                        const Text(
                          "PASSWORD",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _passCtrl,
                          obscureText: true,
                          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                          decoration: const InputDecoration(
                            hintText: "••••••••",
                            prefixIcon: Icon(PhosphorIcons.lockKey, color: Color(0xFF64748B), size: 18),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Login Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _isLoading ? null : _doLogin,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    "LOGIN SEKARANG",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Secure Cloudflare Tunnel • End-to-End Encrypted",
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
