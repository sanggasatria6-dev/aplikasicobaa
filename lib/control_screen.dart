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
import 'sector_service.dart';

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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Control Room"),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIcons.signOutBold, color: Color(0xFFDC2626)),
            tooltip: "Logout / Ganti Akun",
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Container(
              color: Colors.white,
              child: const TabBar(
                indicatorColor: Color(0xFF059669),
                indicatorWeight: 3,
                labelColor: Color(0xFF059669),
                unselectedLabelColor: Color(0xFF64748B),
                labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                tabs: [
                  Tab(text: "PC CONTROL"),
                  Tab(text: "CONFIG SAHAM"),
                ],
              ),
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
    final progress = (_status['progress'] as num? ?? 0).toDouble() / 100.0;
    final message = _status['message'] ?? "";
    final step = _status['step'] ?? "IDLE";

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. STATUS MONITOR (JIKA SEDANG RUNNING)
        if (isRunning) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF93C5FD)),
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
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "STATUS: $step",
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1D4ED8),
                              fontSize: 13,
                            ),
                          ),
                          if (_status['queue_length'] != null && (_status['queue_length'] as int) > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                "Antrian: ${_status['queue_length']}",
                                style: const TextStyle(
                                  color: Color(0xFFB45309),
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    color: const Color(0xFF2563EB),
                    backgroundColor: const Color(0xFFDBEAFE),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "$message (${(progress * 100).toInt()}%)",
                  style: const TextStyle(fontSize: 12, color: Color(0xFF1E40AF), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // 2. ACTION BUTTONS
        _buildHeader("KONTROL OPERASIONAL"),
        IgnorePointer(
          ignoring: isRunning,
          child: Opacity(
            opacity: isRunning ? 0.5 : 1.0,
            child: Column(
              children: [
                _buildActionCard(
                  context,
                  "Update Market Data",
                  "Download harga & indikator teknikal terbaru",
                  PhosphorIcons.cloudArrowDownBold,
                  const Color(0xFF2563EB),
                  const Color(0xFFEFF6FF),
                  () => ref.read(apiProvider).triggerUpdate(),
                ),
                _buildActionCard(
                  context,
                  "Run Backtest Only",
                  "Uji performa model aktif pada data historis",
                  PhosphorIcons.chartLineUpBold,
                  const Color(0xFFD97706),
                  const Color(0xFFFFFBEB),
                  () async {
                    await ref.read(apiProvider).triggerBacktestOnly();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Backtest dimulai... Pantau progress di atas."),
                          backgroundColor: Color(0xFF0F172A),
                        ),
                      );
                    }
                  },
                ),
                _buildActionCard(
                  context,
                  "Full Retraining AI",
                  "Latih ulang model LightGBM & Policy Autonomous",
                  PhosphorIcons.brainBold,
                  const Color(0xFF7C3AED),
                  const Color(0xFFF5F3FF),
                  () => _confirmTraining(context),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildHeader("TRAINING HISTORY"),
            const Text(
              "Geser kanan untuk hapus",
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // 3. LOG LIST (LIGHT THEME)
        ref.watch(logsProvider).when(
          data: (logs) {
            if (logs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Center(
                  child: Text("Belum ada riwayat training model.", style: TextStyle(color: Color(0xFF64748B))),
                ),
              );
            }

            return Column(
              children: logs.map((log) {
                final isActive = log['is_active'] == 1;

                String winRateStr = "-";
                String profitStr = "-";
                Map<String, dynamic> fullMetrics = {};

                if (log['metrics'] != null) {
                  try {
                    if (log['metrics'] is String) {
                      fullMetrics = jsonDecode(log['metrics']);
                    } else {
                      fullMetrics = Map<String, dynamic>.from(log['metrics']);
                    }
                    if (fullMetrics.containsKey('bt_Win Rate (%)')) {
                      winRateStr = "${fullMetrics['bt_Win Rate (%)']}%";
                    }
                    if (fullMetrics.containsKey('bt_Total Return on Invested Capital (%)')) {
                      profitStr = "${fullMetrics['bt_Total Return on Invested Capital (%)']}%";
                    }
                  } catch (e) {
                    debugPrint("Error parsing metrics: $e");
                  }
                }

                return Slidable(
                  key: ValueKey(log['id']),
                  startActionPane: isActive
                      ? null
                      : ActionPane(
                          motion: const ScrollMotion(),
                          extentRatio: 0.25,
                          children: [
                            SlidableAction(
                              onPressed: (context) => _confirmDeleteLog(context, ref, log['id']),
                              backgroundColor: const Color(0xFFDC2626),
                              foregroundColor: Colors.white,
                              icon: PhosphorIcons.trashBold,
                              label: 'Hapus',
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ],
                        ),
                  endActionPane: null,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isActive ? const Color(0xFF059669) : const Color(0xFFE2E8F0),
                        width: isActive ? 1.5 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          title: Text(
                            "Versi: ${log['model_version'] ?? '-'}",
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: isActive ? const Color(0xFF059669) : const Color(0xFF0F172A),
                            ),
                          ),
                          subtitle: Text(
                            log['training_date'] ?? '-',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(PhosphorIcons.infoBold, color: Color(0xFF64748B), size: 20),
                                tooltip: "Lihat Rapor Lengkap",
                                onPressed: () => _showModelDetails(
                                  context,
                                  log['model_version'] ?? 'Model Detail',
                                  fullMetrics,
                                ),
                              ),
                              const SizedBox(width: 4),
                              if (isActive)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD1FAE5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    "ACTIVE",
                                    style: TextStyle(
                                      color: Color(0xFF059669),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                    ),
                                  ),
                                )
                              else
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFEFF6FF),
                                    foregroundColor: const Color(0xFF2563EB),
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(PhosphorIcons.arrowCounterClockwiseBold, size: 14),
                                  label: const Text(
                                    "RESTORE",
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: () async {
                                    await ref.read(apiProvider).activateModel(log['id']);
                                    ref.invalidate(logsProvider);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text("Model berhasil diaktifkan kembali!"),
                                          backgroundColor: Color(0xFF059669),
                                        ),
                                      );
                                    }
                                  },
                                ),
                            ],
                          ),
                        ),
                        if (winRateStr != "-")
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                            child: Row(
                              children: [
                                _buildMetricChip("Win Rate", winRateStr, const Color(0xFF2563EB), const Color(0xFFEFF6FF)),
                                const SizedBox(width: 8),
                                _buildMetricChip(
                                  "Return",
                                  profitStr,
                                  profitStr.contains("-") ? const Color(0xFFDC2626) : const Color(0xFF059669),
                                  profitStr.contains("-") ? const Color(0xFFFEE2E2) : const Color(0xFFD1FAE5),
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
          loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFF059669)),
          ),
          error: (e, _) => Text("Gagal load logs: $e", style: const TextStyle(color: Colors.red)),
        ),
        const SizedBox(height: 50),
      ],
    );
  }

  Widget _buildMetricChip(String label, String value, Color textCol, Color bgCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgCol,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "$label: ",
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: textCol,
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 2: CONFIG SAHAM ---
  Widget _buildStockConfig(BuildContext context, WidgetRef ref) {
    return ref.watch(configProvider).when(
      data: (data) {
        final stocks = (data['stocks'] as List?) ?? [];
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: const Color(0xFF059669),
            foregroundColor: Colors.white,
            icon: const Icon(PhosphorIcons.plusBold, size: 18),
            label: const Text("TAMBAH SAHAM", style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => _addStockDialog(context, ref),
          ),
          body: stocks.isEmpty
              ? const Center(
                  child: Text("Belum ada watchlist saham.", style: TextStyle(color: Color(0xFF64748B))),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: stocks.length,
                  itemBuilder: (ctx, i) {
                    final ticker = stocks[i].toString();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD1FAE5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(PhosphorIcons.chartLineUpBold, color: Color(0xFF059669), size: 18),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                ticker,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(PhosphorIcons.trashBold, color: Color(0xFFDC2626), size: 20),
                            tooltip: "Hapus dari Watchlist",
                            onPressed: () async {
                              await ref.read(apiProvider).removeStockConfig(ticker);
                              ref.invalidate(configProvider);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFF059669)),
      ),
      error: (e, _) => Center(child: Text("$e", style: const TextStyle(color: Colors.red))),
    );
  }

  // DIALOG: DETAIL MODEL (LIGHT THEME)
  void _showModelDetails(
    BuildContext context,
    String version,
    Map<String, dynamic> metrics,
  ) {
    final backtestData = metrics.entries
        .where((e) => e.key.startsWith('bt_') && e.key != 'bt_backtest_id')
        .toList();
    final backtestId = metrics['bt_backtest_id'];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Rapor Backtest",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 2),
            Text(
              version,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: backtestData.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text("Data backtest belum tersedia.", style: TextStyle(color: Color(0xFF64748B))),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: backtestData.length,
                        separatorBuilder: (_, __) => const Divider(color: Color(0xFFE2E8F0), height: 16),
                        itemBuilder: (ctx, i) {
                          final key = backtestData[i].key.replaceFirst('bt_', '');
                          final value = backtestData[i].value.toString();
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                key,
                                style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                              ),
                              Text(
                                value,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF059669),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
              const SizedBox(height: 18),
              if (backtestId != null)
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(PhosphorIcons.listBulletsBold, size: 18),
                    label: const Text("LIHAT LOG TRANSAKSI", style: TextStyle(fontWeight: FontWeight.bold)),
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
            child: const Text("TUTUP", style: TextStyle(color: Color(0xFF64748B))),
          ),
        ],
      ),
    );
  }

  // BOTTOM SHEET: LOG TRANSAKSI BACKTEST (LIGHT THEME)
  void _showTradeLogSheet(BuildContext context, int backtestId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Log Transaksi Backtest",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(PhosphorIcons.xBold, size: 20, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Color(0xFFE2E8F0), height: 1),

                Expanded(
                  child: FutureBuilder<List<dynamic>>(
                    future: ref.read(apiProvider).getBacktestTrades(backtestId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: Color(0xFF059669)));
                      }
                      if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(
                          child: Text(
                            "Tidak ada riwayat eksekusi transaksi pada run ini.",
                            style: TextStyle(color: Color(0xFF64748B)),
                          ),
                        );
                      }

                      final trades = snapshot.data!;
                      return ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: trades.length,
                        separatorBuilder: (_, __) => const Divider(color: Color(0xFFF1F5F9), height: 12),
                        itemBuilder: (ctx, i) {
                          final t = trades[i];
                          final isSell = t['action'] == 'SELL';
                          final num profitVal = (t['profit_loss'] ?? t['profit'] ?? 0) as num;
                          final isProfit = profitVal > 0;
                          final num returnVal = (t['return_pct'] ?? t['return_percent'] ?? 0) as num;
                          final date = (t['transaction_date'] ?? t['Date'] ?? '').toString().split(' ')[0];
                          final reason = t['reason']?.toString() ?? '';

                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: isSell
                                        ? (isProfit ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2))
                                        : const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    isSell
                                        ? (isProfit ? PhosphorIcons.trendUpBold : PhosphorIcons.trendDownBold)
                                        : PhosphorIcons.shoppingCartBold,
                                    color: isSell
                                        ? (isProfit ? const Color(0xFF059669) : const Color(0xFFDC2626))
                                        : const Color(0xFF2563EB),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            t['symbol'] ?? '-',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF0F172A),
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isSell
                                                  ? (isProfit ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2))
                                                  : const Color(0xFFEFF6FF),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              t['action'] ?? '',
                                              style: TextStyle(
                                                color: isSell
                                                    ? (isProfit ? const Color(0xFF059669) : const Color(0xFFDC2626))
                                                    : const Color(0xFF2563EB),
                                                fontWeight: FontWeight.w800,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "$date • ${t['shares'] ?? t['lot'] ?? 0} Lbr @ ${t['price'] ?? 0}",
                                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                      ),
                                      if (reason.isNotEmpty)
                                        Text(
                                          reason,
                                          style: TextStyle(
                                            color: isSell
                                                ? (isProfit ? const Color(0xFF059669) : const Color(0xFFDC2626))
                                                : const Color(0xFF2563EB),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (isSell)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        "${isProfit ? '+' : ''}${NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(profitVal)}",
                                        style: TextStyle(
                                          color: isProfit ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        "${returnVal >= 0 ? '+' : ''}${returnVal.toStringAsFixed(1)}%",
                                        style: TextStyle(
                                          color: isProfit ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
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

  // SECTOR MANAGER (LIGHT THEME)
  void _showSectorManager(BuildContext context, String username) {
    final idCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final SectorService sectorService = SectorService();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            "Atur Label Sektor",
            style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: TextField(
                        controller: idCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "ID", hintText: "99"),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: "Nama", hintText: "Crypto"),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(PhosphorIcons.plusCircleBold, color: Color(0xFF059669), size: 28),
                      onPressed: () async {
                        if (idCtrl.text.isNotEmpty && nameCtrl.text.isNotEmpty) {
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
                const SizedBox(height: 16),
                const Divider(color: Color(0xFFE2E8F0)),

                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: sectorService.getUserSectors(username),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF059669)));
                      final list = snapshot.data!;

                      if (list.isEmpty) {
                        return const Center(
                          child: Text("Belum ada data sektor.", style: TextStyle(color: Color(0xFF64748B))),
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
                              backgroundColor: const Color(0xFFE0F2FE),
                              radius: 12,
                              child: Text(
                                "${s['id']}",
                                style: const TextStyle(fontSize: 10, color: Color(0xFF0369A1), fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(
                              s['name'],
                              style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            ),
                            trailing: IconButton(
                              icon: const Icon(PhosphorIcons.trashBold, color: Color(0xFFDC2626), size: 16),
                              onPressed: () => sectorService.deleteSector(username, s['id']),
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
              child: const Text("TUTUP", style: TextStyle(color: Color(0xFF64748B))),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteLog(BuildContext context, WidgetRef ref, int logId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Hapus Model Ini?",
          style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
        ),
        content: const Text(
          "Data history dan file model akan dihapus secara permanen.",
          style: TextStyle(color: Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("BATAL", style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(apiProvider).deleteTrainingLog(logId);
              ref.invalidate(logsProvider);
            },
            child: const Text("HAPUS", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmTraining(BuildContext context) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Mulai Full Training?",
          style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
        ),
        content: const Text(
          "Proses ini akan melatih ulang model AI & Policy dari data offline dan mengevaluasi backtest.\n\nEstimasi: 3-5 Menit.",
          style: TextStyle(color: Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("BATAL", style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(apiProvider).triggerTraining();
            },
            child: const Text("GAS TRAINING!", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _addStockDialog(BuildContext context, WidgetRef ref) {
    final symbolCtrl = TextEditingController();
    final authState = ref.read(authProvider);
    final username = authState.username ?? "user_default";
    int? selectedSector;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Tambah Saham",
                  style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                IconButton(
                  icon: const Icon(PhosphorIcons.gearBold, size: 18, color: Color(0xFF64748B)),
                  tooltip: "Atur Sektor",
                  onPressed: () => _showSectorManager(context, username),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: symbolCtrl,
                  decoration: const InputDecoration(labelText: "Kode Saham (cth: BBCA)", hintText: "BBCA"),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 16),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: SectorService().getUserSectors(username),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const LinearProgressIndicator(color: Color(0xFF059669));
                    final sectors = snapshot.data!;

                    if (sectors.isEmpty) {
                      SectorService().initDefaultSectors(username);
                      return const Text("Inisialisasi data sektor...", style: TextStyle(color: Color(0xFF64748B)));
                    }

                    if (selectedSector == null || !sectors.any((s) => s['id'] == selectedSector)) {
                      selectedSector = sectors.first['id'];
                    }

                    return DropdownButtonFormField<int>(
                      value: selectedSector,
                      dropdownColor: Colors.white,
                      decoration: const InputDecoration(labelText: "Sektor"),
                      items: sectors.map((s) {
                        return DropdownMenuItem<int>(
                          value: s['id'],
                          child: Text("${s['id']} - ${s['name']}"),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => selectedSector = v),
                    );
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("BATAL", style: TextStyle(color: Color(0xFF64748B))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  if (symbolCtrl.text.isNotEmpty && selectedSector != null) {
                    await ref.read(apiProvider).addStockConfig(
                      symbolCtrl.text.toUpperCase(),
                      selectedSector!,
                    );
                    ref.invalidate(configProvider);
                    if (context.mounted) Navigator.pop(ctx);
                  }
                },
                child: const Text("SIMPAN", style: TextStyle(fontWeight: FontWeight.bold)),
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
        color: Color(0xFF64748B),
        fontWeight: FontWeight.w800,
        fontSize: 12,
        letterSpacing: 0.8,
      ),
    ),
  );

  Widget _buildActionCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color iconColor,
    Color iconBgColor,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconBgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A)),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
        ),
        trailing: const Icon(PhosphorIcons.caretRightBold, color: Color(0xFFCBD5E1), size: 16),
        onTap: onTap,
      ),
    );
  }

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Keluar dari Aplikasi?",
          style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
        ),
        content: const Text(
          "Sesi login dan token API akan dihapus dari perangkat ini.",
          style: TextStyle(color: Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("BATAL", style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authProvider.notifier).logout();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text("LOGOUT", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
