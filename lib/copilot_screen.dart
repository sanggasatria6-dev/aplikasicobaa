import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'api_service.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class CopilotScreen extends ConsumerStatefulWidget {
  const CopilotScreen({super.key});

  @override
  ConsumerState<CopilotScreen> createState() => _CopilotScreenState();
}

class _CopilotScreenState extends ConsumerState<CopilotScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  final List<String> _suggestions = [
    "📊 Status porto sore ini?",
    "🧠 Kenapa bot beli MEDC?",
    "🧮 Hitung cuan BUMI di 212",
    "📰 Berita saham BUMI hari ini",
    "🎯 Sinyal AI terbaik hari ini",
  ];

  @override
  void initState() {
    super.initState();
    // Pesan sambutan awal dari Copilot
    _messages.add(ChatMessage(
      text: "Halo kak Sangga! 👋 Saya **Trader Copilot** AI pribadi kamu.\n\n"
          "Saya siap bantu:\n"
          "• 📊 **Cek Portofolio:** Tanyakan posisi & kas RDN terkini\n"
          "• 🧠 **Alasan AI:** Tanya kenapa bot beli MEDC/PGAS/BUMI\n"
          "• 🧮 **Kalkulator Cuan:** Hitung laba bersih setelah dipotong fee\n"
          "• 📰 **Berita Terkini:** Ambil sentimen pasar real-time\n"
          "• ✏️ **Koreksi DB:** Perbaiki catatan harga jual jika ada selisih.\n\n"
          "Ada yang mau ditanyakan atau dihitung?",
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    final query = text.trim();
    if (query.isEmpty || _isLoading) return;

    _controller.clear();
    setState(() {
      _messages.add(ChatMessage(
        text: query,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final api = ref.read(apiProvider);
      final reply = await api.sendCopilotMessage(query);

      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            text: reply,
            isUser: false,
            timestamp: DateTime.now(),
          ));
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            text: "⚠️ Terjadi kesalahan: $e",
            isUser: false,
            timestamp: DateTime.now(),
          ));
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                PhosphorIcons.robot,
                color: Color(0xFF059669),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "AI Trader Copilot",
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      "Online • Analis & Kalkulator",
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIcons.trash, color: Color(0xFF94A3B8), size: 20),
            tooltip: "Bersihkan Chat",
            onPressed: () {
              setState(() {
                _messages.clear();
                _messages.add(ChatMessage(
                  text: "Chat telah dibersihkan. Ada yang bisa saya bantu terkait portofolio kak Sangga?",
                  isUser: false,
                  timestamp: DateTime.now(),
                ));
              });
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: Column(
        children: [
          // Daftar Pesan Chat
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessageBubble(msg);
              },
            ),
          ),

          // Typing Indicator
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF059669),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Copilot sedang berpikir...",
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Suggestion Chips (Rekomendasi Cepat)
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                return ActionChip(
                  label: Text(
                    _suggestions[i],
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF334155),
                    ),
                  ),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  onPressed: () => _sendMessage(_suggestions[i]),
                );
              },
            ),
          ),

          // Input Box Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: TextField(
                        controller: _controller,
                        textInputAction: TextInputAction.send,
                        onSubmitted: _sendMessage,
                        style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: "Tanya porto, hitung cuan, atau berita...",
                          hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Material(
                    color: const Color(0xFF059669),
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => _sendMessage(_controller.text),
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        child: const Icon(
                          PhosphorIcons.paperPlaneRightFill,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.isUser;
    final timeStr = "${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}";

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFFD1FAE5),
              child: const Icon(PhosphorIcons.robot, color: Color(0xFF059669), size: 18),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF059669) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                border: isUser ? null : Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  _formatMessageContent(msg.text, isUser),
                  const SizedBox(height: 4),
                  Text(
                    timeStr,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: isUser ? Colors.white.withOpacity(0.7) : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _formatMessageContent(String text, bool isUser) {
    final textColor = isUser ? Colors.white : const Color(0xFF1E293B);
    final lines = text.split('\n');
    final widgets = <Widget>[];

    for (var rawLine in lines) {
      final trimmed = rawLine.trim();

      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 4));
        continue;
      }

      // Divider horizontal line
      if (trimmed.startsWith('---') || trimmed.startsWith('───') || trimmed.startsWith('***')) {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Divider(
            color: isUser ? Colors.white24 : const Color(0xFFE2E8F0),
            thickness: 1,
            height: 8,
          ),
        ));
        continue;
      }

      // Markdown Table divider row (| :--- | :---: |)
      if (trimmed.startsWith('|') && trimmed.contains('---')) {
        continue;
      }

      // Markdown Table data row
      if (trimmed.startsWith('|') && trimmed.endsWith('|')) {
        final cells = trimmed.split('|').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
        if (cells.isNotEmpty) {
          final joined = cells.join(' • ');
          widgets.add(Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: _renderFormattedLine("• $joined", textColor, isUser),
          ));
          continue;
        }
      }

      // Markdown Headers (###, ##, #)
      if (trimmed.startsWith('### ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 4),
          child: _renderFormattedLine(trimmed.substring(4), textColor, isUser, baseFontSize: 14.5, isHeader: true),
        ));
        continue;
      }
      if (trimmed.startsWith('## ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: _renderFormattedLine(trimmed.substring(3), textColor, isUser, baseFontSize: 15.5, isHeader: true),
        ));
        continue;
      }
      if (trimmed.startsWith('# ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: _renderFormattedLine(trimmed.substring(2), textColor, isUser, baseFontSize: 16.5, isHeader: true),
        ));
        continue;
      }

      // Standard / Bullet lines
      String displayLine = rawLine;
      if (trimmed.startsWith('* ') || trimmed.startsWith('- ')) {
        displayLine = '• ${trimmed.substring(2)}';
      }

      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: _renderFormattedLine(displayLine, textColor, isUser),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _renderFormattedLine(
    String line,
    Color defaultColor,
    bool isUser, {
    double baseFontSize = 13.5,
    bool isHeader = false,
  }) {
    final spans = <TextSpan>[];
    final boldParts = line.split('**');

    for (int i = 0; i < boldParts.length; i++) {
      final isBold = isHeader || (i % 2 == 1);
      final chunk = boldParts[i];

      // Periksa inline code `code`
      if (chunk.contains('`')) {
        final codeParts = chunk.split('`');
        for (int j = 0; j < codeParts.length; j++) {
          final isCode = j % 2 == 1;
          if (codeParts[j].isEmpty) continue;
          spans.add(TextSpan(
            text: codeParts[j],
            style: GoogleFonts.inter(
              fontSize: isCode ? baseFontSize * 0.92 : baseFontSize,
              height: 1.45,
              color: isCode
                  ? (isUser ? const Color(0xFFBBF7D0) : const Color(0xFF0F766E))
                  : defaultColor,
              fontWeight: isBold ? FontWeight.w700 : (isCode ? FontWeight.w600 : FontWeight.w400),
              backgroundColor: isCode ? (isUser ? Colors.black26 : const Color(0xFFF1F5F9)) : null,
            ),
          ));
        }
      } else {
        if (chunk.isEmpty) continue;
        spans.add(TextSpan(
          text: chunk,
          style: GoogleFonts.inter(
            fontSize: baseFontSize,
            height: 1.45,
            color: defaultColor,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
          ),
        ));
      }
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }
}
