import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'api_service.dart';

// Providers
final capitalProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(apiProvider).getCapital(),
);
final portfolioProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(apiProvider).getPortfolio(),
);
final analysisProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(apiProvider).getAnalysis(),
);
final performanceProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(apiProvider).getPerformanceSummary(),
);

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat.currency(
      locale: 'id',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIcons.arrowsClockwiseBold, color: Color(0xFF0F172A)),
            tooltip: "Refresh Data",
            onPressed: () {
              ref.invalidate(capitalProvider);
              ref.invalidate(portfolioProvider);
              ref.invalidate(analysisProvider);
              ref.invalidate(performanceProvider);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF059669),
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(PhosphorIcons.plusBold, size: 18),
        label: const Text(
          "BELI MANUAL",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
        ),
        onPressed: () => _showManualBuyDialog(context, ref),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF059669),
        onRefresh: () async {
          ref.invalidate(capitalProvider);
          ref.invalidate(portfolioProvider);
          ref.invalidate(analysisProvider);
          ref.invalidate(performanceProvider);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. KARTU RAPOR KINERJA AI (AI PERFORMANCE SCORECARD)
              _buildPerformanceScorecard(ref, fmt),

              const SizedBox(height: 16),

              // 2. KARTU SALDO (CAPITAL / WALLET)
              _buildWalletCard(ref, fmt, context),

              const SizedBox(height: 24),

              // 3. AI OPPORTUNITIES (SARAN BELI)
              _buildAiRecommendations(ref, context, fmt),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "LIVE HOLDINGS",
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 0.8,
                    ),
                  ),
                  ref.watch(portfolioProvider).maybeWhen(
                    data: (list) => Text(
                      "${list.length} Saham",
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    orElse: () => const SizedBox(),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 4. LIST SAHAM AKTIF
              ref.watch(portfolioProvider).when(
                data: (list) {
                  if (list.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(32),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: const [
                          Icon(PhosphorIcons.walletBold, size: 40, color: Color(0xFF94A3B8)),
                          SizedBox(height: 8),
                          Text(
                            "Portofolio Masih Kosong",
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Beli saham manual atau pilih dari AI Opportunities di atas.",
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }


                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: list.length,
                    itemBuilder: (ctx, i) {
                      final item = list[i];
                      final advice = item['advice'] as String? ?? "Menunggu analisis AI...";

                      // Warna badge status
                      Color statusBg = const Color(0xFFEFF6FF);
                      Color statusFg = const Color(0xFF2563EB);
                      IconData statusIcon = PhosphorIcons.robot;

                      if (advice.contains("TAKE PROFIT") || advice.contains("Untung") || advice.contains("PROFIT")) {
                        statusBg = const Color(0xFFD1FAE5);
                        statusFg = const Color(0xFF059669);
                        statusIcon = PhosphorIcons.trendUpBold;
                      } else if (advice.contains("CUT LOSS") || advice.contains("JUAL") || advice.contains("RUGI")) {
                        statusBg = const Color(0xFFFEE2E2);
                        statusFg = const Color(0xFFDC2626);
                        statusIcon = PhosphorIcons.trendDownBold;
                      } else if (advice.contains("HOLD") || advice.contains("TAHAN")) {
                        statusBg = const Color(0xFFFEF3C7);
                        statusFg = const Color(0xFFD97706);
                        statusIcon = PhosphorIcons.pauseBold;
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Text(
                                        item['symbol'] ?? '-',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "${item['lot']} Lot (${(item['shares'] ?? item['lot'] * 100)} Lbr)",
                                          style: const TextStyle(
                                            color: Color(0xFF0F172A),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          "Avg: ${fmt.format(item['avg_price'] ?? 0)}",
                                          style: const TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFDC2626),
                                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                                    backgroundColor: const Color(0xFFFEF2F2),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  ),
                                  onPressed: () => _showSellDialog(context, ref, item),
                                  child: const Text(
                                    "JUAL",
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: statusBg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(statusIcon, size: 16, color: statusFg),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      advice,
                                      style: TextStyle(
                                        color: statusFg,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: Color(0xFF059669)),
                  ),
                ),
                error: (e, _) => Center(
                  child: Text("Error: $e", style: const TextStyle(color: Colors.red)),
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  // WIDGET: KARTU RAPOR KINERJA AI (AI PERFORMANCE SCORECARD)
  Widget _buildPerformanceScorecard(WidgetRef ref, NumberFormat fmt) {
    return ref.watch(performanceProvider).when(
      data: (data) {
        if (data.isEmpty) return const SizedBox();

        final num netPnl = data['realized_profit_rp'] ?? 0;
        final isProfit = netPnl >= 0;
        final num winRate = data['realized_win_rate'] ?? 0;
        final num profitFactor = data['profit_factor'] ?? 1.0;
        final String regimeLabel = data['market_regime_label'] ?? "SIDEWAYS";
        final String regimeDesc = data['market_regime_desc'] ?? "Analisis pasar aktif";
        final int regime = data['market_regime'] ?? 1;
        final String modelVersion = data['active_model_version'] ?? "v7-Active";
        final dynamic btWinRate = data['active_model_win_rate'];

        Color regimeBg = const Color(0xFFFEF3C7);
        Color regimeFg = const Color(0xFFD97706);
        IconData regimeIcon = PhosphorIcons.scalesBold;

        if (regime == 2) {
          regimeBg = const Color(0xFFD1FAE5);
          regimeFg = const Color(0xFF059669);
          regimeIcon = PhosphorIcons.rocketLaunchBold;
        } else if (regime == 0) {
          regimeBg = const Color(0xFFFEE2E2);
          regimeFg = const Color(0xFFDC2626);
          regimeIcon = PhosphorIcons.warningCircleBold;
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Judul & Market Regime Pill
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(PhosphorIcons.chartLineUpBold, size: 16, color: Color(0xFF2563EB)),
                      SizedBox(width: 6),
                      Text(
                        "AI PERFORMANCE SCORECARD",
                        style: TextStyle(
                          color: Color(0xFF2563EB),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: regimeBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(regimeIcon, size: 12, color: regimeFg),
                        const SizedBox(width: 4),
                        Text(
                          regimeLabel,
                          style: TextStyle(
                            color: regimeFg,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Grid 4 Metrik
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      "Realized PnL",
                      "${isProfit ? '+' : ''}${fmt.format(netPnl)}",
                      isProfit ? const Color(0xFF059669) : const Color(0xFFDC2626),
                      isProfit ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricTile(
                      "Live Win Rate",
                      "${winRate.toStringAsFixed(1)}%",
                      const Color(0xFF2563EB),
                      const Color(0xFFEFF6FF),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      "Profit Factor",
                      "${profitFactor.toStringAsFixed(2)}x",
                      const Color(0xFF059669),
                      const Color(0xFFECFDF5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricTile(
                      "Model AI Aktif",
                      modelVersion,
                      const Color(0xFF7C3AED),
                      const Color(0xFFF5F3FF),
                      subtitle: btWinRate != null ? "BT WR: $btWinRate%" : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Tactical Stance Bar
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Row(
                  children: [
                    const Icon(PhosphorIcons.infoBold, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        regimeDesc,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
    );
  }

  Widget _buildMetricTile(String label, String value, Color textColor, Color bgColor, {String? subtitle}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 1),
            Text(
              subtitle,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: textColor.withOpacity(0.8)),
            ),
          ],
        ],
      ),
    );
  }

  // WIDGET: KARTU SALDO BERSIH (LIGHT THEME)
  Widget _buildWalletCard(
    WidgetRef ref,
    NumberFormat fmt,
    BuildContext context,
  ) {
    return ref.watch(capitalProvider).when(
      data: (data) {
        final cash = (data['current_capital'] as num).toDouble();
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF059669).withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(PhosphorIcons.walletFill, color: Color(0xFF059669), size: 18),
                      SizedBox(width: 6),
                      Text(
                        "AVAILABLE CASH",
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      "LIVE PORTFOLIO",
                      style: TextStyle(
                        color: Color(0xFF059669),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                fmt.format(cash),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(PhosphorIcons.arrowDownLeftBold, size: 16),
                      label: const Text(
                        "TOP UP",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      onPressed: () => _adjustMoney(context, ref, true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1E293B),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        backgroundColor: const Color(0xFFF8FAFC),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(PhosphorIcons.arrowUpRightBold, size: 16),
                      label: const Text(
                        "TARIK DANA",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      onPressed: () => _adjustMoney(context, ref, false),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const LinearProgressIndicator(color: Color(0xFF059669)),
      error: (_, __) => const Text("Gagal memuat saldo."),
    );
  }

  // WIDGET: AI OPPORTUNITIES (SARAN BELI)
  Widget _buildAiRecommendations(
    WidgetRef ref,
    BuildContext context,
    NumberFormat fmt,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(PhosphorIcons.sparkleFill, color: Color(0xFF059669), size: 16),
            SizedBox(width: 6),
            Text(
              "AI OPPORTUNITIES",
              style: TextStyle(
                color: Color(0xFF059669),
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        Consumer(
          builder: (context, ref, _) {
            final portfolioAsync = ref.watch(portfolioProvider);
            final analysisAsync = ref.watch(analysisProvider);

            return analysisAsync.when(
              data: (marketData) {
                return portfolioAsync.when(
                  data: (portfolioList) {
                    final ownedSymbols = portfolioList.map((e) => e['symbol'].toString()).toSet();

                    final suggestions = marketData.where((item) {
                      final rec = item['recommendation'] ?? 'NETRAL';
                      final symbol = item['symbol'];
                      final isGoodSignal = rec.contains("STRONG") || rec == "BELI";
                      final isNotOwned = !ownedSymbols.contains(symbol);
                      return isGoodSignal && isNotOwned;
                    }).toList();

                    if (suggestions.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Text(
                          "Belum ada sinyal beli baru yang valid saat ini.",
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    return SizedBox(
                      height: 175,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: suggestions.length,
                        itemBuilder: (ctx, i) {
                          final item = suggestions[i];
                          final rec = item['recommendation'] ?? '';
                          final isStrong = rec.contains("STRONG");
                          final num prob = (item['prediction_probability'] as num? ?? 0);

                          return Container(
                            width: 185,
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isStrong ? const Color(0xFF059669) : const Color(0xFFCBD5E1),
                                width: isStrong ? 1.5 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      item['symbol'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isStrong ? const Color(0xFFFEF3C7) : const Color(0xFFD1FAE5),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        isStrong ? "🔥 TOP" : "${prob.toStringAsFixed(0)}%",
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: isStrong ? const Color(0xFFB45309) : const Color(0xFF059669),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fmt.format(item['current_price'] ?? 0),
                                      style: const TextStyle(
                                        color: Color(0xFF0F172A),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      "TP: ${fmt.format(item['predicted_peak'] ?? 0)}",
                                      style: const TextStyle(
                                        color: Color(0xFF059669),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(2),
                                      child: LinearProgressIndicator(
                                        value: (prob / 100.0).clamp(0.0, 1.0),
                                        minHeight: 3,
                                        color: const Color(0xFF059669),
                                        backgroundColor: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(
                                  width: double.infinity,
                                  height: 32,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF059669),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () {
                                      int suggestedLot = 1;
                                      final recString = item['recommendation'].toString();
                                      if (recString.contains("Target:")) {
                                        final match = RegExp(r'Target:\s*(\d+)').firstMatch(recString);
                                        if (match != null) {
                                          suggestedLot = int.tryParse(match.group(1)!) ?? 1;
                                        }
                                      }

                                      _showManualBuyDialog(
                                        context,
                                        ref,
                                        prefillSymbol: item['symbol'],
                                        prefillPrice: (item['current_price'] as num).toDouble(),
                                        prefillLot: suggestedLot > 0 ? suggestedLot : null,
                                      );
                                    },
                                    child: const Text(
                                      "BELI SEKARANG",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                );
              },
              loading: () => const LinearProgressIndicator(color: Color(0xFF059669)),
              error: (_, __) => const Text("Gagal memuat data rekomendasi."),
            );
          },
        ),
      ],
    );
  }

  // DIALOG: INPUT BELI MANUAL (LIGHT THEME)
  void _showManualBuyDialog(
    BuildContext context,
    WidgetRef ref, {
    String? prefillSymbol,
    double? prefillPrice,
    int? prefillLot,
  }) {
    final symbolCtrl = TextEditingController(text: prefillSymbol ?? "");
    final priceCtrl = TextEditingController(
      text: prefillPrice?.toStringAsFixed(0) ?? "",
    );
    final lotCtrl = TextEditingController(text: prefillLot?.toString() ?? "");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Input Buy Manual",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF0F172A)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: symbolCtrl,
              decoration: const InputDecoration(
                labelText: "Kode Saham (cth: BBRI)",
                hintText: "BBRI",
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              decoration: const InputDecoration(
                labelText: "Harga Beli (Rp)",
                hintText: "3000",
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: lotCtrl,
              decoration: const InputDecoration(
                labelText: "Jumlah Lot",
                hintText: "5",
              ),
              keyboardType: TextInputType.number,
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
              if (symbolCtrl.text.isNotEmpty) {
                Navigator.pop(ctx);
                await ref.read(apiProvider).addPortfolioPosition(
                  symbol: symbolCtrl.text,
                  price: double.tryParse(priceCtrl.text) ?? 0,
                  lot: int.tryParse(lotCtrl.text) ?? 0,
                );
                ref.invalidate(portfolioProvider);
                ref.invalidate(capitalProvider);
              }
            },
            child: const Text("SIMPAN ORDER", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _adjustMoney(BuildContext context, WidgetRef ref, bool isAdd) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isAdd ? "Top Up Saldo" : "Tarik Saldo",
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF0F172A)),
        ),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: "Nominal (Rp)",
            hintText: "1000000",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
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
              final val = double.tryParse(ctrl.text) ?? 0;
              if (val > 0) {
                await ref.read(apiProvider).adjustCapital(
                  isAdd ? val : -val,
                  "Manual App",
                );
                ref.invalidate(capitalProvider);
                Navigator.pop(context);
              }
            },
            child: const Text("KONFIRMASI", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSellDialog(BuildContext context, WidgetRef ref, dynamic item) {
    final ctrl = TextEditingController(text: item['avg_price']?.toString() ?? "");
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Jual ${item['symbol']}?",
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF0F172A)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Jumlah: ${item['lot']} Lot (${item['shares'] ?? item['lot'] * 100} Lbr)",
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Harga Jual Realisasi (Rp)",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
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
              if (ctrl.text.isNotEmpty) {
                await ref.read(apiProvider).sellPortfolioPosition(
                  item['id'],
                  double.tryParse(ctrl.text) ?? 0,
                );
                ref.invalidate(portfolioProvider);
                ref.invalidate(capitalProvider);
                Navigator.pop(context);
              }
            },
            child: const Text("JUAL SEKARANG", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
