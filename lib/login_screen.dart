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

  final _ipCtrl = TextEditingController(text: "http://202.155.94.249:6969");
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

    // 2. Update alamat IP Server berdasarkan input user
    ref.read(baseUrlProvider.notifier).state = _ipCtrl.text;

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
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Icon(
                PhosphorIcons.brain,
                size: 80,
                color: Color(0xFF00E676),
              ),
              const SizedBox(height: 16),
              const Text(
                "AI TRADER PRO V2",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _ipCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Server URL",
                  prefixIcon: Icon(PhosphorIcons.globe),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _userCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Username (Opsional)",
                  prefixIcon: Icon(PhosphorIcons.user),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passCtrl,
                obscureText: true, // Password disensor bintang-bintang
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Password",
                  prefixIcon: Icon(PhosphorIcons.lockKey),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E676),
                  ),
                  onPressed: _isLoading ? null : _doLogin,
                  child:
                      _isLoading
                          ? const CircularProgressIndicator()
                          : const Text(
                            "LOGIN",
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
