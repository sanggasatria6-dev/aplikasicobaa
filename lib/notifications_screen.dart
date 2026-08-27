import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import 'api_service.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String _selectedFilter = 'ALL'; // ALL, BUY, SELL, HOLD

  @override
  Widget build(BuildContext context) {
    final notifsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "Notifikasi Sinyal AI",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIcons.paperPlaneTiltBold, color: Color(0xFF0284C7)),
            tooltip: "Pengaturan Telegram",
            onPressed: () => _showTelegramConfigDialog(context, ref),
          ),
          IconButton(
            icon: const Icon(PhosphorIcons.checkCircleBold, color: Color(0xFF059669)),
            tooltip: "Tandai Semua Dibaca",
            onPressed: () async {
              await ref.read(apiProvider).markAllNotificationsRead();
              ref.invalidate(notificationsProvider);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Semua notifikasi ditandai telah dibaca"),
                    backgroundColor: Color(0xFF059669),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(PhosphorIcons.arrowsClockwiseBold),
            tooltip: "Segarkan",
            onPressed: () => ref.invalidate(notificationsProvider),
          ),
        ],
      ),
      body: notifsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF059669)),
        ),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(PhosphorIcons.warningCircleBold, size: 48, color: Color(0xFFDC2626)),
              const SizedBox(height: 12),
              Text("Gagal memuat notifikasi: $err", style: const TextStyle(color: Color(0xFF64748B))),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(PhosphorIcons.arrowsClockwiseBold, size: 16),
                label: const Text("Coba Lagi"),
                onPressed: () => ref.invalidate(notificationsProvider),
              )
            ],
          ),
        ),
        data: (res) {
          final List<dynamic> allNotifs = res['data'] ?? [];
          final int unreadCount = res['unread_count'] ?? 0;

          final filteredNotifs = allNotifs.where((n) {
            final type = (n['type'] ?? '').toString().toUpperCase();
            if (_selectedFilter == 'BUY') return type == 'BUY';
            if (_selectedFilter == 'SELL') return type == 'SELL' || type == 'STOP_LOSS' || type == 'TAKE_PROFIT';
            if (_selectedFilter == 'HOLD') return type == 'HOLD' || type == 'INFO';
            return true;
          }).toList();

          return RefreshIndicator(
            color: const Color(0xFF059669),
            onRefresh: () async => ref.invalidate(notificationsProvider),
            child: Column(
              children: [
                // Top Bar: Unread Count + Quick Filter Chips
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.white,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: unreadCount > 0 ? const Color(0xFFFEE2E2) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      PhosphorIcons.bellBold,
                                      size: 14,
                                      color: unreadCount > 0 ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      "$unreadCount Belum Dibaca",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: unreadCount > 0 ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF0284C7),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(PhosphorIcons.flaskBold, size: 14),
                            label: const Text("Kirim Tes Alert", style: TextStyle(fontSize: 12)),
                            onPressed: () async {
                              final ok = await ref.read(apiProvider).sendTestNotification();
                              ref.invalidate(notificationsProvider);
                              if (mounted && ok) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Notifikasi uji coba berhasil dikirim!"),
                                    backgroundColor: Color(0xFF059669),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('ALL', 'Semua (${allNotifs.length})'),
                            const SizedBox(width: 8),
                            _buildFilterChip('BUY', 'Sinyal Beli 🟢'),
                            const SizedBox(width: 8),
                            _buildFilterChip('SELL', 'Sinyal Jual 🔴'),
                            const SizedBox(width: 8),
                            _buildFilterChip('HOLD', 'Sinyal Hold 🔵'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // List Notifikasi
                Expanded(
                  child: filteredNotifs.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 100),
                            Center(
                              child: Column(
                                children: [
                                  Icon(PhosphorIcons.bellSlashBold, size: 54, color: Color(0xFFCBD5E1)),
                                  SizedBox(height: 12),
                                  Text(
                                    "Belum ada notifikasi sinyal.",
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    "Notifikasi akan otomatis muncul saat AI mendeteksi momentum pasar.",
                                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredNotifs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (ctx, i) {
                            final notif = filteredNotifs[i];
                            return _buildNotificationCard(context, ref, notif);
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : const Color(0xFF475569),
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF0F172A),
      backgroundColor: const Color(0xFFF1F5F9),
      showCheckmark: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (val) {
        if (val) setState(() => _selectedFilter = key);
      },
    );
  }

  Widget _buildNotificationCard(BuildContext context, WidgetRef ref, dynamic notif) {
    final int id = notif['id'] ?? 0;
    final String type = (notif['type'] ?? 'INFO').toString().toUpperCase();
    final String title = notif['title'] ?? 'Pemberitahuan';
    final String message = notif['message'] ?? '';
    final String? symbol = notif['symbol'];
    final num? price = notif['price'];
    final num? targetPrice = notif['target_price'];
    final num? stopLoss = notif['stop_loss'];
    final num? prob = notif['probability'];
    final bool isRead = (notif['is_read'] ?? 0) == 1;
    final String createdAt = notif['created_at'] ?? '';

    // Color theme based on type
    Color cardBorder;
    Color badgeColor;
    Color badgeText;
    IconData icon;
    String badgeLabel;

    if (type == 'BUY') {
      cardBorder = const Color(0xFF10B981);
      badgeColor = const Color(0xFFD1FAE5);
      badgeText = const Color(0xFF065F46);
      icon = PhosphorIcons.arrowCircleUpRightBold;
      badgeLabel = "BELI";
    } else if (type == 'SELL' || type == 'STOP_LOSS') {
      cardBorder = const Color(0xFFEF4444);
      badgeColor = const Color(0xFFFEE2E2);
      badgeText = const Color(0xFF991B1B);
      icon = PhosphorIcons.arrowCircleDownRightBold;
      badgeLabel = type == 'STOP_LOSS' ? "STOP LOSS" : "JUAL";
    } else if (type == 'TAKE_PROFIT') {
      cardBorder = const Color(0xFFF59E0B);
      badgeColor = const Color(0xFFFEF3C7);
      badgeText = const Color(0xFF92400E);
      icon = PhosphorIcons.trendUpBold;
      badgeLabel = "TAKE PROFIT";
    } else {
      cardBorder = const Color(0xFF3B82F6);
      badgeColor = const Color(0xFFDBEAFE);
      badgeText = const Color(0xFF1E40AF);
      icon = PhosphorIcons.infoBold;
      badgeLabel = "HOLD / INFO";
    }

    return Dismissible(
      key: Key('notif_$id'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(PhosphorIcons.trashBold, color: Colors.white),
      ),
      onDismissed: (_) async {
        await ref.read(apiProvider).deleteNotification(id);
        ref.invalidate(notificationsProvider);
      },
      child: GestureDetector(
        onTap: () async {
          if (!isRead) {
            await ref.read(apiProvider).markNotificationRead(id);
            ref.invalidate(notificationsProvider);
          }
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isRead ? Colors.white : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isRead ? const Color(0xFFE2E8F0) : cardBorder.withOpacity(0.8),
              width: isRead ? 1.0 : 1.8,
            ),
            boxShadow: [
              BoxShadow(
                color: isRead ? Colors.black.withOpacity(0.02) : cardBorder.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 3),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Badge Type + Symbol + Time
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(icon, size: 14, color: badgeText),
                            const SizedBox(width: 4),
                            Text(
                              badgeLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: badgeText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (symbol != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          symbol,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Row(
                    children: [
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: cardBorder,
                            shape: BoxShape.circle,
                          ),
                        ),
                      Text(
                        _formatTimestamp(createdAt),
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Title
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 6),

              // Message Body
              Text(
                message,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF475569),
                  height: 1.4,
                ),
              ),

              // Price targets snippet if available
              if (price != null || targetPrice != null || stopLoss != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      if (price != null && price > 0)
                        _buildMetricCol("Harga Masuk", "Rp ${NumberFormat('#,###').format(price)}"),
                      if (targetPrice != null && targetPrice > 0)
                        _buildMetricCol("Target TP", "Rp ${NumberFormat('#,###').format(targetPrice)}", const Color(0xFF059669)),
                      if (stopLoss != null && stopLoss > 0)
                        _buildMetricCol("Stop Loss", "Rp ${NumberFormat('#,###').format(stopLoss)}", const Color(0xFFDC2626)),
                      if (prob != null && prob > 0)
                        _buildMetricCol("Peluang", "${prob.toStringAsFixed(1)}%", const Color(0xFF7C3AED)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCol(String label, String value, [Color? valColor]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: valColor ?? const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(String dtStr) {
    if (dtStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dtStr);
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return 'Baru saja';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m lalu';
      if (diff.inHours < 24) return '${diff.inHours}j lalu';
      return DateFormat('dd MMM, HH:mm').format(dt);
    } catch (_) {
      return dtStr;
    }
  }

  // DIALOG: PENGATURAN TELEGRAM BOT
  void _showTelegramConfigDialog(BuildContext context, WidgetRef ref) {
    final configAsync = ref.read(telegramConfigProvider);
    final botTokenCtrl = TextEditingController();
    final chatIdCtrl = TextEditingController();

    configAsync.whenData((data) {
      botTokenCtrl.text = data['bot_token'] ?? '';
      chatIdCtrl.text = data['chat_id'] ?? '';
    });

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(PhosphorIcons.paperPlaneTiltBold, color: Color(0xFF0284C7), size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                "Notifikasi Telegram Instan",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Hubungkan Bot Telegram agar Anda menerima notifikasi sinyal BELI & JUAL secara instan langsung ke HP Anda setiap saat!",
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: botTokenCtrl,
                decoration: InputDecoration(
                  labelText: "Telegram Bot Token",
                  hintText: "Contoh: 123456789:ABCdefGhI...",
                  labelStyle: const TextStyle(fontSize: 12),
                  prefixIcon: const Icon(PhosphorIcons.robotBold, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: chatIdCtrl,
                decoration: InputDecoration(
                  labelText: "Telegram Chat ID / User ID",
                  hintText: "Contoh: 987654321",
                  labelStyle: const TextStyle(fontSize: 12),
                  prefixIcon: const Icon(PhosphorIcons.userBold, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(PhosphorIcons.infoBold, size: 16, color: Color(0xFF0284C7)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Tips: Buat bot via @BotFather di Telegram untuk dapat Token, lalu chat @userinfobot untuk dapatkan Chat ID Anda.",
                        style: TextStyle(fontSize: 11, color: Color(0xFF475569)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Batal", style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(PhosphorIcons.floppyDiskBold, size: 16),
            label: const Text("Simpan & Hubungkan"),
            onPressed: () async {
              final ok = await ref.read(apiProvider).saveTelegramConfig(
                    botTokenCtrl.text.trim(),
                    chatIdCtrl.text.trim(),
                  );
              ref.invalidate(telegramConfigProvider);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? "Pengaturan Telegram berhasil disimpan!" : "Gagal menyimpan"),
                    backgroundColor: ok ? const Color(0xFF059669) : const Color(0xFFDC2626),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
