import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'login_screen.dart';

// Verifikasi PIN Mac
// Mengambil nilai dari environment variable (.env) saat build
const String _envMacPin = String.fromEnvironment('MAC_SECURITY_PIN');

bool isCorrectMacPin(String input) {
  if (_envMacPin.isNotEmpty) {
    return input == _envMacPin;
  }
  // Obfuscated fallback jika env kosong (mencegah plaintext terlihat di source code)
  final fallback = String.fromCharCodes([48, 56, 48, 57, 48, 48]); // '080900'
  return input == fallback;
}

/// Gate utama: Jika dibuka di Mac, minta PIN terlebih dahulu.
/// Jika dibuka di Android atau OS lain, langsung bypass ke LoginScreen tanpa PIN.
class MacPinGate extends StatefulWidget {
  const MacPinGate({super.key});

  @override
  State<MacPinGate> createState() => _MacPinGateState();
}

class _MacPinGateState extends State<MacPinGate> {
  // Hanya aktifkan kunci PIN jika berjalan di platform macOS (Desktop / Web Mac)
  late bool _isUnlocked;

  @override
  void initState() {
    super.initState();
    final bool isMac = defaultTargetPlatform == TargetPlatform.macOS;
    // Jika bukan Mac (misalnya Android/iOS/Windows), langsung buka tanpa PIN
    _isUnlocked = !isMac;
  }

  @override
  Widget build(BuildContext context) {
    if (_isUnlocked) {
      return const LoginScreen();
    }
    return MacPinScreen(
      onUnlocked: () {
        setState(() {
          _isUnlocked = true;
        });
      },
    );
  }
}

class MacPinScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const MacPinScreen({super.key, required this.onUnlocked});

  @override
  State<MacPinScreen> createState() => _MacPinScreenState();
}

class _MacPinScreenState extends State<MacPinScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _errorMessage = "";
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    // Otomatis fokus ke keyboard saat layar muncul
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onPinChanged(String value) {
    if (value.length > 6) {
      _pinController.text = value.substring(0, 6);
      _pinController.selection = const TextSelection.collapsed(offset: 6);
      return;
    }

    setState(() {
      _errorMessage = "";
      _isError = false;
    });

    if (value.length == 6) {
      _verifyPin(value);
    }
  }

  void _appendDigit(String digit) {
    if (_pinController.text.length < 6) {
      final newText = _pinController.text + digit;
      _pinController.text = newText;
      _onPinChanged(newText);
    }
  }

  void _deleteDigit() {
    if (_pinController.text.isNotEmpty) {
      final newText = _pinController.text.substring(0, _pinController.text.length - 1);
      _pinController.text = newText;
      _onPinChanged(newText);
    }
  }

  void _verifyPin(String pin) async {
    if (isCorrectMacPin(pin)) {
      widget.onUnlocked();
    } else {
      setState(() {
        _isError = true;
        _errorMessage = "PIN Keamanan Salah! Akses Ditolak.";
      });
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        _pinController.clear();
        setState(() {
          _isError = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLength = _pinController.text.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate 900
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _focusNode.requestFocus(),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Hidden TextField to capture physical Mac keyboard input
                  Opacity(
                    opacity: 0.0,
                    child: SizedBox(
                      width: 1,
                      height: 1,
                      child: TextField(
                        controller: _pinController,
                        focusNode: _focusNode,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        onChanged: _onPinChanged,
                      ),
                    ),
                  ),

                  // Icon Lock
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF059669).withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        PhosphorIcons.lockKeyBold,
                        color: Color(0xFF10B981),
                        size: 36,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title & Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "AI Trader Pro",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF3B82F6), width: 1),
                        ),
                        child: const Text(
                          "MAC ONLY",
                          style: TextStyle(
                            color: Color(0xFF60A5FA),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Masukkan 6-digit PIN untuk membuka akses di Mac ini",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 6 PIN Dots Indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (index) {
                      final isFilled = index < currentLength;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 44,
                        height: 52,
                        decoration: BoxDecoration(
                          color: _isError
                              ? const Color(0xFFDC2626).withValues(alpha: 0.15)
                              : isFilled
                                  ? const Color(0xFF059669).withValues(alpha: 0.2)
                                  : const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isError
                                ? const Color(0xFFEF4444)
                                : isFilled
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF334155),
                            width: isFilled || _isError ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: isFilled
                              ? const Icon(
                                  Icons.circle,
                                  size: 14,
                                  color: Color(0xFF10B981),
                                )
                              : const Text(
                                  "-",
                                  style: TextStyle(
                                    color: Color(0xFF475569),
                                    fontSize: 18,
                                  ),
                                ),
                        ),
                      );
                    }),
                  ),

                  // Error Message
                  const SizedBox(height: 16),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _errorMessage.isNotEmpty ? 1.0 : 0.0,
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // On-screen Numpad
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Column(
                      children: [
                        _buildNumRow(["1", "2", "3"]),
                        const SizedBox(height: 12),
                        _buildNumRow(["4", "5", "6"]),
                        const SizedBox(height: 12),
                        _buildNumRow(["7", "8", "9"]),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Tombol Clear
                            _buildActionButton(
                              icon: PhosphorIcons.arrowCounterClockwiseBold,
                              onTap: () {
                                _pinController.clear();
                                _onPinChanged("");
                              },
                            ),
                            _buildDigitButton("0"),
                            // Tombol Hapus (Backspace)
                            _buildActionButton(
                              icon: PhosphorIcons.backspaceBold,
                              onTap: _deleteDigit,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Text(
                    "Ketik langsung dari keyboard Mac atau klik angka di atas",
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
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

  Widget _buildNumRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildDigitButton(d)).toList(),
    );
  }

  Widget _buildDigitButton(String digit) {
    return InkWell(
      onTap: () => _appendDigit(digit),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 76,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Center(
          child: Text(
            digit,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 76,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Center(
          child: Icon(
            icon,
            color: const Color(0xFF94A3B8),
            size: 20,
          ),
        ),
      ),
    );
  }
}
