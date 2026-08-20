import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:mytrading/auth_provider.dart';
import 'package:mytrading/login_screen.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'api_service.dart';

import 'sector_service.dart'; // File service yg baru dibuat

final configProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(apiProvider).getStockConfig(),
);
final logsProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(apiProvider).getTrainingLogs(),
);

class ControlScreen extends ConsumerStatefulWidget {
  const ControlScreen({super.key});

  @override
  ConsumerState<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends ConsumerState<ControlScreen> {
  Timer? _timer;
  Map<String, dynamic> _status = {
    "is_running": false,
    "progress": 0,
    "message": "Idle",
    "step": "IDLE",
  };

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!mounted) return;
      try {
        final newStatus = await ref.read(apiProvider).getSystemStatus();
        setState(() => _status = newStatus);

        if (_status['is_running'] == true && newStatus['is_running'] == false) {
          ref.invalidate(logsProvider);
        }
      } catch (e) {
        debugPrint("Polling error: $e");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("CONTROL ROOM"),
        actions: [
          // TOMBOL LOGOUT MERAH
          IconButton(
            icon: const Icon(PhosphorIcons.signOut, color: Colors.red),
            tooltip: "Logout / Ganti Akun",
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              indicatorColor: Color(0xFF00E676),
              tabs: [Tab(text: "PC CONTROL"), Tab(text: "CONFIG SAHAM")],
            ),
            Expanded(
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildPcControl(context),
                  _buildStockConfig(context, ref),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 1: PC CONTROL ---
  Widget _buildPcControl(BuildContext context) {
    final isRunning = _status['is_running'] == true;
    final progress = (_status['progress'] as num).toDouble() / 100.0;
    final message = _status['message'] ?? "";
    final step = _status['step'] ?? "IDLE";

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. STATUS MONITOR
        if (isRunning) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2979FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2979FF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF2979FF),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // [BARU] Gunakan Expanded agar teks antrian bisa mojok ke kanan
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "STATUS: $step",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2979FF),
                            ),
                          ),

                          // Cek apakah ada antrian > 0 dari backend
                          if (_status['queue_length'] != null &&
                              (_status['queue_length'] as int) > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "Antrian: ${_status['queue_length']}",
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: progress,
                  color: const Color(0xFF2979FF),
                  backgroundColor: Colors.black12,
                ),
                const SizedBox(height: 8),
                Text(
                  "$message (${(progress * 100).toInt()}%)",
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // 2. ACTION BUTTONS
        _buildHeader("ACTIONS"),
        IgnorePointer(
          ignoring: isRunning,
          child: Opacity(
            opacity: isRunning ? 0.5 : 1.0,
            child: Column(
              children: [
                _buildActionCard(
                  context,
                  "Update Market Data",
                  PhosphorIcons.cloudArrowDown,
                  Colors.blue,
                  () => ref.read(apiProvider).triggerUpdate(),
                ),

                _buildActionCard(
                  context,
                  "Run Backtest Only",
                  PhosphorIcons.chartLineUp,
                  Colors.orange,
                  () async {
                    await ref.read(apiProvider).triggerBacktestOnly();
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Backtest dimulai...")),
                      );
                  },
                ),

                _buildActionCard(
                  context,
                  "Full Training AI",
                  PhosphorIcons.brain,
                  Colors.purple,
                  () => _confirmTraining(context),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),
        _buildHeader("TRAINING HISTORY"),
        const Padding(
          padding: EdgeInsets.only(bottom: 8.0),
          child: Text(
            "Slide Kanan (-->) untuk Hapus Permanen",
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),

        // 3. LOG LIST (UPDATED UI/UX)
        ref
            .watch(logsProvider)
            .when(
              data: (logs) {
                if (logs.isEmpty)
                  return const Text("Belum ada history training.");
                return Column(
                  children:
                      logs.map((log) {
                        final isActive = log['is_active'] == 1;

                        String winRateStr = "-";
                        String profitStr = "-";
                        Map<String, dynamic> fullMetrics = {};

                        if (log['metrics'] != null) {
                          try {
                            if (log['metrics'] is String) {
                              fullMetrics = jsonDecode(log['metrics']);
                            } else {
                              fullMetrics = Map<String, dynamic>.from(
                                log['metrics'],
                              );
                            }
                            if (fullMetrics.containsKey('bt_Win Rate (%)'))
                              winRateStr =
                                  fullMetrics['bt_Win Rate (%)'].toString();
                            if (fullMetrics.containsKey(
                              'bt_Total Return on Invested Capital (%)',
                            ))
                              profitStr =
                                  fullMetrics['bt_Total Return on Invested Capital (%)']
                                      .toString();
                          } catch (e) {
                            debugPrint("Error parsing metrics: $e");
                          }
                        }

                        return Slidable(
                          key: ValueKey(log['id']),

                          // [UX BARU] Slide Kanan (StartPane) -> DELETE
                          // Geser dari kiri ke kanan untuk menghapus
                          startActionPane:
                              isActive
                                  ? null
                                  : ActionPane(
                                    motion: const ScrollMotion(),
                                    extentRatio: 0.25, // Tidak terlalu lebar
                                    children: [
                                      SlidableAction(
                                        onPressed:
                                            (context) => _confirmDeleteLog(
                                              context,
                                              ref,
                                              log['id'],
                                            ),
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                        icon: PhosphorIcons.trash,
                                        label: 'Hapus',
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ],
                                  ),

                          // [UX BARU] Slide Kiri -> KOSONG (Disable)
                          // Karena restore sudah jadi button
                          endActionPane: null,

                          child: Card(
                            // Warna Active: Sedikit kehijauan agar standout
                            // Warna Inactive: Gelap standard
                            color:
                                isActive
                                    ? const Color(0xFF00E676).withOpacity(0.08)
                                    : const Color(0xFF1E1E1E),
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              side:
                                  isActive
                                      ? const BorderSide(
                                        color: Color(0xFF00E676),
                                        width: 1.5,
                                      )
                                      : BorderSide.none,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                ListTile(
                                  contentPadding: const EdgeInsets.fromLTRB(
                                    16,
                                    8,
                                    8,
                                    0,
                                  ),

                                  // Judul & Tanggal
                                  title: Text(
                                    "Versi: ${log['model_version']}",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color:
                                          isActive
                                              ? const Color(0xFF00E676)
                                              : Colors.white,
                                    ),
                                  ),
                                  subtitle: Text(
                                    log['training_date'],
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),

                                  // [UX BARU] Trailing Actions
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // 1. INFO BUTTON (Selalu Muncul)
                                      IconButton(
                                        icon: const Icon(
                                          PhosphorIcons.info,
                                          color: Colors.grey,
                                        ),
                                        tooltip: "Lihat Detail Rapor",
                                        onPressed:
                                            () => _showModelDetails(
                                              context,
                                              log['model_version'],
                                              fullMetrics,
                                            ),
                                      ),

                                      const SizedBox(width: 4),

                                      // 2. STATUS INDICATOR
                                      if (isActive)
                                        // Jika ACTIVE -> Tampilkan Chip Hijau
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF00E676),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(
                                                  0xFF00E676,
                                                ).withOpacity(0.4),
                                                blurRadius: 6,
                                              ),
                                            ],
                                          ),
                                          child: const Text(
                                            "ACTIVE",
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 10,
                                            ),
                                          ),
                                        )
                                      else
                                        // Jika INACTIVE -> Tampilkan Tombol RESTORE (Biru)
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF2979FF,
                                            ).withOpacity(0.2),
                                            foregroundColor: const Color(
                                              0xFF2979FF,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          icon: const Icon(
                                            PhosphorIcons.arrowCounterClockwise,
                                            size: 16,
                                          ),
                                          label: const Text(
                                            "RESTORE",
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          onPressed: () async {
                                            await ref
                                                .read(apiProvider)
                                                .activateModel(log['id']);
                                            ref.invalidate(logsProvider);
                                            if (context.mounted)
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    "Model berhasil diaktifkan kembali!",
                                                  ),
                                                ),
                                              );
                                          },
                                        ),
                                    ],
                                  ),
                                ),

                                // Rapor Singkat di Bawah
                                if (winRateStr != "-")
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      0,
                                      16,
                                      16,
                                    ),
                                    child: Row(
                                      children: [
                                        _buildMetricChip(
                                          "Win Rate",
                                          winRateStr,
                                          Colors.blue,
                                        ),
                                        const SizedBox(width: 10),
                                        _buildMetricChip(
                                          "Profit",
                                          profitStr,
                                          profitStr.contains("-")
                                              ? Colors.red
                                              : const Color(0xFF00E676),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text("Gagal load logs: $e"),
            ),
        const SizedBox(height: 50),
      ],
    );
  }

  Widget _buildMetricChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Text(
            "$label: ",
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockConfig(BuildContext context, WidgetRef ref) {
    return ref
        .watch(configProvider)
        .when(
          data: (data) {
            final stocks = data['stocks'] as List;
            return Scaffold(
              floatingActionButton: FloatingActionButton(
                backgroundColor: const Color(0xFF00E676),
                child: const Icon(Icons.add, color: Colors.black),
                onPressed: () => _addStockDialog(context, ref),
              ),
              body: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: stocks.length,
                itemBuilder: (ctx, i) {
                  return Card(
                    color: const Color(0xFF1E1E1E),
                    child: ListTile(
                      title: Text(
                        stocks[i],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          await ref
                              .read(apiProvider)
                              .removeStockConfig(stocks[i]);
                          ref.invalidate(configProvider);
                        },
                      ),
                    ),
                  );
                },
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text("$e")),
        );
  }

  void _showModelDetails(
    BuildContext context,
    String version,
    Map<String, dynamic> metrics,
  ) {
    // Filter data metrics
    final backtestData =
        metrics.entries
            .where((e) => e.key.startsWith('bt_') && e.key != 'bt_backtest_id')
            .toList();
    final backtestId = metrics['bt_backtest_id'];

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Rapor Backtest",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  version,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. LIST METRICS
                  Flexible(
                    child:
                        backtestData.isEmpty
                            ? const Text(
                              "Data backtest belum tersedia.",
                              style: TextStyle(color: Colors.grey),
                            )
                            : ListView.separated(
                              shrinkWrap: true,
                              itemCount: backtestData.length,
                              separatorBuilder:
                                  (_, __) =>
                                      const Divider(color: Colors.white10),
                              itemBuilder: (ctx, i) {
                                final key = backtestData[i].key.replaceFirst(
                                  'bt_',
                                  '',
                                );
                                final value = backtestData[i].value.toString();
                                return Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      key,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      value,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF00E676),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                  ),

                  const SizedBox(height: 20),

                  // 2. TOMBOL LIHAT TRANSAKSI (FITUR BARU ANDA)
                  if (backtestId != null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(
                            0xFF2979FF,
                          ).withOpacity(0.2),
                          foregroundColor: const Color(0xFF2979FF),
                        ),
                        icon: const Icon(PhosphorIcons.listBullets),
                        label: const Text("LIHAT LOG TRANSAKSI"),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showTradeLogSheet(
                            context,
                            int.parse(backtestId.toString()),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("TUTUP"),
              ),
            ],
          ),
    );
  }

  // [FITUR BARU] SHEET LOG TRANSAKSI (Sesuai request anda)
  void _showTradeLogSheet(BuildContext context, int backtestId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                // Header Sheet
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Log Transaksi Backtest",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white24, height: 1),

                // List Transaksi
                Expanded(
                  child: FutureBuilder<List<dynamic>>(
                    future: ref.read(apiProvider).getBacktestTrades(backtestId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError ||
                          !snapshot.hasData ||
                          snapshot.data!.isEmpty) {
                        return const Center(
                          child: Text(
                            "Tidak ada data transaksi.",
                            style: TextStyle(color: Colors.grey),
                          ),
                        );
                      }

                      final trades = snapshot.data!;
                      return ListView.builder(
                        controller: scrollController,
                        itemCount: trades.length,
                        itemBuilder: (ctx, i) {
                          final t = trades[i];
                          final isSell = t['action'] == 'SELL';
                          final isProfit = (t['profit'] ?? 0) > 0;
                          final date =
                              t['transaction_date'].toString().split(
                                ' ',
                              )[0]; // Ambil tanggal saja

                          return Container(
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Colors.white10),
                              ),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    isSell
                                        ? (isProfit
                                            ? const Color(
                                              0xFF00E676,
                                            ).withOpacity(0.2)
                                            : Colors.red.withOpacity(0.2))
                                        : Colors.blue.withOpacity(0.2),
                                child: Icon(
                                  isSell
                                      ? (isProfit
                                          ? PhosphorIcons.trendUp
                                          : PhosphorIcons.trendDown)
                                      : PhosphorIcons.shoppingCart,
                                  color:
                                      isSell
                                          ? (isProfit
                                              ? const Color(0xFF00E676)
                                              : Colors.red)
                                          : Colors.blue,
                                  size: 20,
                                ),
                              ),
                              title: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    t['symbol'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    t['action'],
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          isSell
                                              ? (isProfit
                                                  ? const Color(0xFF00E676)
                                                  : Colors.red)
                                              : Colors.blue,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                "$date • ${t['shares']} Lembar @ ${t['price']}",
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              trailing:
                                  isSell
                                      ? Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            "${isProfit ? '+' : ''}${NumberFormat.currency(locale: 'id', symbol: '', decimalDigits: 0).format(t['profit'])}",
                                            style: TextStyle(
                                              color:
                                                  isProfit
                                                      ? const Color(0xFF00E676)
                                                      : Colors.red,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            "${t['return_percent']?.toStringAsFixed(1)}%",
                                            style: TextStyle(
                                              color:
                                                  isProfit
                                                      ? const Color(0xFF00E676)
                                                      : Colors.red,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      )
                                      : const Text(
                                        "-",
                                        style: TextStyle(color: Colors.grey),
                                      ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- TAMBAHAN BARU: MANAGER SEKTOR FIREBASE ---
  void _showSectorManager(BuildContext context, String username) {
    final idCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final SectorService sectorService = SectorService(); // Panggil service

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text("Atur Label Sektor"),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. INPUT SEKTOR BARU
                Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: TextField(
                        controller: idCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "ID",
                          hintText: "99",
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: "Nama (cth: Crypto)",
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.add_circle,
                        color: Color(0xFF00E676),
                      ),
                      onPressed: () async {
                        if (idCtrl.text.isNotEmpty &&
                            nameCtrl.text.isNotEmpty) {
                          await sectorService.addOrUpdateSector(
                            username,
                            int.parse(idCtrl.text),
                            nameCtrl.text,
                          );
                          idCtrl.clear();
                          nameCtrl.clear();
                        }
                      },
                    ),
                  ],
                ),
                const Divider(height: 20, color: Colors.white24),

                // 2. LIST SEKTOR YANG ADA (REALTIME DARI FIREBASE)
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: sectorService.getUserSectors(username),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData)
                        return const Center(child: CircularProgressIndicator());
                      final list = snapshot.data!;

                      if (list.isEmpty) {
                        return const Center(
                          child: Text(
                            "Belum ada data sektor.",
                            style: TextStyle(color: Colors.grey),
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: list.length,
                        itemBuilder: (ctx, i) {
                          final s = list[i];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            leading: CircleAvatar(
                              backgroundColor: Colors.blueGrey,
                              radius: 12,
                              child: Text(
                                "${s['id']}",
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            title: Text(s['name']),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.red,
                                size: 16,
                              ),
                              onPressed:
                                  () => sectorService.deleteSector(
                                    username,
                                    s['id'],
                                  ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("TUTUP"),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteLog(BuildContext context, WidgetRef ref, int logId) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text(
              "Hapus Model Ini?",
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              "Data history dan file model akan dihapus permanen.",
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("BATAL"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await ref.read(apiProvider).deleteTrainingLog(logId);
                  ref.invalidate(logsProvider);
                },
                child: const Text(
                  "HAPUS",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _confirmTraining(BuildContext context) async {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text("Mulai Full Training?"),
            content: const Text(
              "Proses ini akan melatih ulang AI dari nol dan melakukan backtest.\n\nEstimasi: 5-10 Menit.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("BATAL"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await ref.read(apiProvider).triggerTraining();
                },
                child: const Text(
                  "GAS TRAINING!",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  void _addStockDialog(BuildContext context, WidgetRef ref) {
  final symbolCtrl = TextEditingController();
  final authState = ref.read(authProvider);
  final username = authState.username ?? "user_default"; // Ambil username login
  
  // Default sementara (akan ditimpa data firebase)
  int? selectedSector; 

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Tambah Saham"),
              // Tombol pintas untuk edit sektor
              IconButton(
                icon: const Icon(PhosphorIcons.gear, size: 18, color: Colors.grey),
                tooltip: "Atur Sektor",
                onPressed: () => _showSectorManager(context, username),
              )
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: symbolCtrl,
                decoration: const InputDecoration(
                  labelText: "Kode (BBCA)",
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 16),
              
              // --- DROPDOWN YANG TERHUBUNG KE FIREBASE ---
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: SectorService().getUserSectors(username),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const LinearProgressIndicator(); // Loading
                  
                  final sectors = snapshot.data!;
                  
                  // Jika kosong, buat default dulu biar gak error
                  if (sectors.isEmpty) {
                    SectorService().initDefaultSectors(username);
                    return const Text("Inisialisasi data sektor...");
                  }

                  // Pastikan value selectedSector valid (ada di list)
                  if (selectedSector == null || !sectors.any((s) => s['id'] == selectedSector)) {
                    selectedSector = sectors.first['id'];
                  }

                  return DropdownButtonFormField<int>(
                    value: selectedSector,
                    dropdownColor: const Color(0xFF2C2C2C),
                    decoration: const InputDecoration(
                      labelText: "Sektor",
                      border: OutlineInputBorder(),
                    ),
                    items: sectors.map((s) {
                      return DropdownMenuItem<int>(
                        value: s['id'],
                        child: Text("${s['id']} - ${s['name']}"), // Tampil: "0 - Finance"
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => selectedSector = v),
                  );
                }
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("BATAL"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
              ),
              onPressed: () async {
                if (symbolCtrl.text.isNotEmpty && selectedSector != null) {
                  // Kirim ke API Python (Simbol + ID Sektor)
                  await ref.read(apiProvider).addStockConfig(
                    symbolCtrl.text.toUpperCase(),
                    selectedSector!,
                  );
                  ref.invalidate(configProvider);
                  if (context.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text("SIMPAN", style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    ),
  );
}

  Widget _buildHeader(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      title,
      style: const TextStyle(
        color: Color(0xFF00E676),
        fontWeight: FontWeight.bold,
      ),
    ),
  );
  Widget _buildActionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      color: const Color(0xFF1E1E1E),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        onTap: onTap,
      ),
    );
  }

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text("Logout System?"),
            content: const Text("Sesi Anda akan dihapus dari perangkat ini."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("BATAL"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  Navigator.pop(ctx); // Tutup dialog

                  // 1. Hapus Token dari Memori HP
                  await ref.read(authProvider.notifier).logout();

                  // 2. Kembali ke Login Screen (Hapus semua history halaman sebelumnya)
                  if (mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                },
                child: const Text(
                  "LOGOUT",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }
}
