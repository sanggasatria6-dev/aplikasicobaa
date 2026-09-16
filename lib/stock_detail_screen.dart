import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'api_service.dart';

// Provider detail saham dengan parameter symbol & timeframe
final stockDetailProvider = FutureProvider.family.autoDispose<Map<String, dynamic>, ({String symbol, String timeframe})>(
  (ref, arg) async {
    final api = ref.watch(apiProvider);
    return await api.getStockDetail(arg.symbol, timeframe: arg.timeframe);
  },
);

class StockDetailScreen extends ConsumerStatefulWidget {
  final String symbol;
  final Map<String, dynamic>? initialData;

  const StockDetailScreen({
    super.key,
    required this.symbol,
    this.initialData,
  });

  @override
  ConsumerState<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends ConsumerState<StockDetailScreen> {
  // Default timeframe dimulai dari 1M sesuai instruksi user
  String _timeframe = "1M"; // '1W', '1M', '3M', '1Y'
  bool _isCandleMode = false;
  int? _hoveredIndex;

  final fmt = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
  final fmtNum = NumberFormat.decimalPattern('id');

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(stockDetailProvider((symbol: widget.symbol, timeframe: _timeframe)));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Tema Terang Clean Modern
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(PhosphorIcons.arrowLeftBold, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Hero(
              tag: 'stock_${widget.symbol}',
              child: Material(
                color: Colors.transparent,
                child: Text(
                  widget.symbol,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    color: const Color(0xFF0F172A),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                "IDX",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIcons.databaseBold, color: Color(0xFF0284C7)),
            tooltip: "Ubah Data Saham di Database",
            onPressed: () => _openDatabaseEditModal(context),
          ),
          IconButton(
            icon: const Icon(PhosphorIcons.arrowsClockwiseBold, color: Color(0xFF0F172A)),
            tooltip: "Refresh Data",
            onPressed: () {
              HapticFeedback.lightImpact();
              ref.refresh(stockDetailProvider((symbol: widget.symbol, timeframe: _timeframe)));
            },
          ),
        ],
      ),
      body: detailAsync.when(
        data: (data) => _buildDetailContent(context, data),
        loading: () => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Color(0xFF059669)),
              const SizedBox(height: 16),
              Text(
                "Mengambil data ${widget.symbol}...",
                style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 13),
              ),
            ],
          ),
        ),
        error: (err, _) => _buildErrorState(context, err.toString()),
      ),
      bottomNavigationBar: _buildBottomActionBar(context),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(PhosphorIcons.warningCircleBold, size: 48, color: Color(0xFFDC2626)),
            const SizedBox(height: 12),
            Text(
              "Gagal Memuat Data Saham",
              style: GoogleFonts.plusJakartaSans(color: const Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 12),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(PhosphorIcons.arrowsClockwiseBold, size: 16),
              label: const Text("Coba Lagi"),
              onPressed: () => ref.refresh(stockDetailProvider((symbol: widget.symbol, timeframe: _timeframe))),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDetailContent(BuildContext context, Map<String, dynamic> data) {
    final price = (data['price'] as num?)?.toDouble() ?? 0.0;
    final change = (data['change'] as num?)?.toDouble() ?? 0.0;
    final changePct = (data['change_percent'] as num?)?.toDouble() ?? 0.0;
    final isUp = change >= 0;

    final bandarmologi = (data['bandarmologi'] as Map<String, dynamic>?) ?? {};
    final orderbook = (bandarmologi['orderbook'] as Map<String, dynamic>?) ?? {};
    final ai = (data['ai_analysis'] as Map<String, dynamic>?) ?? {};
    final config = (data['user_config'] as Map<String, dynamic>?) ?? {};
    final rawCandles = (data['candles'] as List<dynamic>?) ?? [];

    final candles = rawCandles.map((e) => Map<String, dynamic>.from(e as Map)).toList();

    return RefreshIndicator(
      color: const Color(0xFF059669),
      backgroundColor: Colors.white,
      onRefresh: () async {
        ref.refresh(stockDetailProvider((symbol: widget.symbol, timeframe: _timeframe)));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. TOP HEADER: PRICE & BADGES
            _buildPriceHeader(price, change, changePct, isUp, config, ai),
            const SizedBox(height: 16),

            // 2. TIMEFRAME SELECTOR (1W, 1M, 3M, 1Y) & CHART TOGGLE
            _buildChartHeaderControls(),
            const SizedBox(height: 10),

            // 3. INTERACTIVE STOCKBIT CHART (LIGHT THEME)
            _buildInteractiveChartSection(candles, isUp, price),
            const SizedBox(height: 18),

            // 4. LIVE ORDERBOOK (LEVEL 2) ALA STOCKBIT (MENGGANTIKAN STATISTIK)
            _buildLiveOrderbookCard(orderbook, price),
            const SizedBox(height: 16),

            // 5. BANDARMOLOGI & FLOW RADAR
            _buildBandarmologiCard(bandarmologi),
            const SizedBox(height: 16),

            // 6. AI SUPER-VERDICT & TARGETS
            _buildAIVerdictCard(ai),
            const SizedBox(height: 16),

            // 7. DATABASE CONFIG BANNER
            _buildDatabaseConfigBanner(config),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // --- HEADER PRICE & BADGE ---
  Widget _buildPriceHeader(
    double price,
    double change,
    double changePct,
    bool isUp,
    Map<String, dynamic> config,
    Map<String, dynamic> ai,
  ) {
    final sectorName = config['sector_name'] ?? 'Sektor Belum Ditentukan';
    final rec = ai['recommendation'] ?? 'NETRAL';

    Color badgeBg = const Color(0xFFF1F5F9);
    Color badgeFg = const Color(0xFF64748B);
    if (rec.contains("STRONG")) {
      badgeBg = const Color(0xFFD1FAE5);
      badgeFg = const Color(0xFF059669);
    } else if (rec.contains("BELI") || rec.contains("BUY")) {
      badgeBg = const Color(0xFFE0F2FE);
      badgeFg = const Color(0xFF0284C7);
    } else if (rec.contains("JUAL") || rec.contains("HINDARI") || rec.contains("AVOID")) {
      badgeBg = const Color(0xFFFEE2E2);
      badgeFg = const Color(0xFFDC2626);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InkWell(
              onTap: () => _openDatabaseEditModal(context),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(PhosphorIcons.tagBold, size: 12, color: Color(0xFF0284C7)),
                    const SizedBox(width: 6),
                    Text(
                      sectorName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(PhosphorIcons.pencilSimpleBold, size: 11, color: Color(0xFF94A3B8)),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                rec.contains("STRONG")
                    ? "🚀 STRONG BUY"
                    : (rec.contains("BELI")
                        ? "📈 SIGNAL BUY"
                        : (rec.contains("HINDARI") || rec.contains("AVOID") ? "🛡️ WAIT / DEFENSE" : "⚖️ NETRAL")),
                style: GoogleFonts.plusJakartaSans(
                  color: badgeFg,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              fmt.format(price),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isUp ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isUp ? PhosphorIcons.arrowUpBold : PhosphorIcons.arrowDownBold,
                    size: 13,
                    color: isUp ? const Color(0xFF059669) : const Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "${isUp ? '+' : ''}${fmtNum.format(change)} (${isUp ? '+' : ''}${changePct.toStringAsFixed(2)}%)",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isUp ? const Color(0xFF059669) : const Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- TIMEFRAME SELECTOR (1W, 1M, 3M, 1Y) ---
  Widget _buildChartHeaderControls() {
    final timeframes = ["1W", "1M", "3M", "1Y"];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Timeframe Segmented Control
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0).withOpacity(0.6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: timeframes.map((tf) {
              final active = _timeframe == tf;
              return GestureDetector(
                onTap: () {
                  if (_timeframe != tf) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _timeframe = tf;
                      _hoveredIndex = null;
                    });
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: active ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: active
                        ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))]
                        : null,
                  ),
                  child: Text(
                    tf,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                      color: active ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // Toggle Line vs Candle
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _isCandleMode = !_isCandleMode);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  _isCandleMode ? PhosphorIcons.chartBarBold : PhosphorIcons.chartLineBold,
                  size: 14,
                  color: const Color(0xFF059669),
                ),
                const SizedBox(width: 6),
                Text(
                  _isCandleMode ? "Candle" : "Line Area",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- INTERACTIVE CHART (LIGHT THEME) ---
  Widget _buildInteractiveChartSection(List<Map<String, dynamic>> candles, bool isUp, double currentPrice) {
    if (candles.isEmpty) {
      return Container(
        height: 230,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(
          "Memuat grafik data...",
          style: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8), fontSize: 12),
        ),
      );
    }

    final activeCandle = (_hoveredIndex != null && _hoveredIndex! < candles.length)
        ? candles[_hoveredIndex!]
        : candles.last;

    final hoverPrice = (activeCandle['price'] as num?)?.toDouble() ??
        (activeCandle['close'] as num?)?.toDouble() ??
        currentPrice;
    final hoverDate = activeCandle['date'] ?? activeCandle['time'] ?? '-';
    final hoverVol = (activeCandle['volume'] as num?)?.toDouble() ?? 0.0;
    final hoverNf = (activeCandle['net_foreign'] as num?)?.toDouble();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // FLOATING HUD TOOLTIP ON TOP OF CHART
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fmt.format(hoverPrice),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isUp ? const Color(0xFF059669) : const Color(0xFFDC2626),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Tanggal: $hoverDate",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "Vol: ${fmtNum.format(hoverVol.round())} Lot",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    if (hoverNf != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        "Foreign: ${fmtNum.format((hoverNf / 1000000).round())} Jt",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: hoverNf >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // THE CANVAS
          SizedBox(
            height: 200,
            width: double.infinity,
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                return GestureDetector(
                  onPanDown: (details) => _handleTouch(details.localPosition.dx, constraints.maxWidth, candles.length),
                  onPanUpdate: (details) => _handleTouch(details.localPosition.dx, constraints.maxWidth, candles.length),
                  onPanEnd: (_) => setState(() => _hoveredIndex = null),
                  child: CustomPaint(
                    size: Size(constraints.maxWidth, 200),
                    painter: StockbitLightChartPainter(
                      candles: candles,
                      isCandleMode: _isCandleMode,
                      isUp: isUp,
                      hoveredIndex: _hoveredIndex,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _handleTouch(double dx, double width, int count) {
    if (count <= 1 || width <= 0) return;
    final pct = (dx / width).clamp(0.0, 1.0);
    final idx = (pct * (count - 1)).round().clamp(0, count - 1);
    if (_hoveredIndex != idx) {
      HapticFeedback.selectionClick();
      setState(() => _hoveredIndex = idx);
    }
  }

  // --- LIVE ORDERBOOK (LEVEL 2) ALA STOCKBIT ---
  Widget _buildLiveOrderbookCard(Map<String, dynamic> orderbook, double currentPrice) {
    final rawBids = (orderbook['bids'] as List<dynamic>?) ?? [];
    final rawAsks = (orderbook['asks'] as List<dynamic>?) ?? [];

    final bids = rawBids.map((e) => Map<String, dynamic>.from(e as Map)).take(7).toList();
    final asks = rawAsks.map((e) => Map<String, dynamic>.from(e as Map)).take(7).toList();

    final totalBidVol = (orderbook['total_bid_vol'] as num?)?.toDouble() ?? 1.0;
    final totalAskVol = (orderbook['total_ask_vol'] as num?)?.toDouble() ?? 1.0;
    final bidRatio = (totalBidVol / (totalBidVol + totalAskVol)).clamp(0.05, 0.95);

    double maxRowVol = 1.0;
    for (var b in bids) {
      final v = (b['volume'] as num?)?.toDouble() ?? 0;
      if (v > maxRowVol) maxRowVol = v;
    }
    for (var a in asks) {
      final v = (a['volume'] as num?)?.toDouble() ?? 0;
      if (v > maxRowVol) maxRowVol = v;
    }

    final rowCount = max(bids.length, asks.length);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Orderbook Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF059669),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Live Orderbook (Level 2)",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  totalBidVol > totalAskVol ? "Bid Dominan (Akumulasi)" : "Offer Dominan (Distribusi)",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: totalBidVol > totalAskVol ? const Color(0xFF059669) : const Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Orderbook Table Header (Bid | Ask)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    "B.Lot",
                    textAlign: TextAlign.left,
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    "Bid",
                    textAlign: TextAlign.right,
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF059669)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Text(
                    "Ask",
                    textAlign: TextAlign.left,
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFFDC2626)),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    "O.Lot",
                    textAlign: TextAlign.right,
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Rows
          if (rowCount == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  "Orderbook realtime belum tersedia saat bursa tutup.",
                  style: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8), fontSize: 12),
                ),
              ),
            )
          else
            ...List.generate(rowCount, (index) {
              final b = index < bids.length ? bids[index] : null;
              final a = index < asks.length ? asks[index] : null;

              final bPrice = b != null ? (b['price'] as num).toDouble() : 0.0;
              final bVol = b != null ? (b['volume'] as num).toDouble() : 0.0;
              final bRatio = (bVol / maxRowVol).clamp(0.0, 1.0);

              final aPrice = a != null ? (a['price'] as num).toDouble() : 0.0;
              final aVol = a != null ? (a['volume'] as num).toDouble() : 0.0;
              final aRatio = (aVol / maxRowVol).clamp(0.0, 1.0);

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: [
                    // BID SIDE (Volume Bar + Price)
                    Expanded(
                      flex: 3,
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          FractionallySizedBox(
                            widthFactor: bRatio,
                            alignment: Alignment.centerLeft,
                            child: Container(
                              height: 20,
                              decoration: BoxDecoration(
                                color: const Color(0xFFD1FAE5),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              bVol > 0 ? fmtNum.format(bVol.round()) : "-",
                              style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        bPrice > 0 ? fmtNum.format(bPrice.round()) : "-",
                        textAlign: TextAlign.right,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF059669),
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // ASK SIDE (Price + Volume Bar)
                    Expanded(
                      flex: 2,
                      child: Text(
                        aPrice > 0 ? fmtNum.format(aPrice.round()) : "-",
                        textAlign: TextAlign.left,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Stack(
                        alignment: Alignment.centerRight,
                        children: [
                          FractionallySizedBox(
                            widthFactor: aRatio,
                            alignment: Alignment.centerRight,
                            child: Container(
                              height: 20,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              aVol > 0 ? fmtNum.format(aVol.round()) : "-",
                              style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),

          const SizedBox(height: 12),
          const Divider(color: Color(0xFFE2E8F0)),
          const SizedBox(height: 8),

          // Total Depth Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Total Bid: ${fmtNum.format(totalBidVol.round())} Lot",
                style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF059669)),
              ),
              Text(
                "Total Offer: ${fmtNum.format(totalAskVol.round())} Lot",
                style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFDC2626)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  Expanded(
                    flex: (bidRatio * 100).round(),
                    child: Container(color: const Color(0xFF059669)),
                  ),
                  Expanded(
                    flex: ((1 - bidRatio) * 100).round(),
                    child: Container(color: const Color(0xFFDC2626)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- BANDARMOLOGI & FLOW RADAR ---
  Widget _buildBandarmologiCard(Map<String, dynamic> bandar) {
    final status = bandar['foreign_status'] ?? 'NEUTRAL';
    final netForeign = (bandar['net_foreign'] as num?)?.toDouble() ?? 0.0;
    final cvd = (bandar['cvd'] as num?)?.toDouble() ?? 0.0;

    Color statusColor = const Color(0xFF64748B);
    Color statusBg = const Color(0xFFF1F5F9);
    if (status.contains("BIG ACCUMULATION")) {
      statusColor = const Color(0xFF059669);
      statusBg = const Color(0xFFD1FAE5);
    } else if (status.contains("ACCUMULATION")) {
      statusColor = const Color(0xFF0284C7);
      statusBg = const Color(0xFFE0F2FE);
    } else if (status.contains("BIG DISTRIBUTION")) {
      statusColor = const Color(0xFFDC2626);
      statusBg = const Color(0xFFFEE2E2);
    } else if (status.contains("DISTRIBUTION")) {
      statusColor = const Color(0xFFEA580C);
      statusBg = const Color(0xFFFFEDD5);
    }

    String netForeignStr;
    if (netForeign.abs() >= 1000000000000) {
      netForeignStr = "${(netForeign / 1000000000000).toStringAsFixed(2)} T";
    } else if (netForeign.abs() >= 1000000000) {
      netForeignStr = "${(netForeign / 1000000000).toStringAsFixed(2)} M";
    } else {
      netForeignStr = "${(netForeign / 1000000).toStringAsFixed(1)} Jt";
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(PhosphorIcons.broadcastBold, size: 18, color: Color(0xFF0284C7)),
                  const SizedBox(width: 8),
                  Text(
                    "Bandarmologi & Big Flow",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Flow metrics
          Row(
            children: [
              Expanded(
                child: _buildBandarPill(
                  title: "ASING NET FLOW",
                  value: "${netForeign >= 0 ? '+' : ''}Rp $netForeignStr",
                  color: netForeign >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                  icon: netForeign >= 0 ? PhosphorIcons.trendUpBold : PhosphorIcons.trendDownBold,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildBandarPill(
                  title: "INTRADAY CVD DELTA",
                  value: "${cvd >= 0 ? '+' : ''}${fmtNum.format(cvd.round())} Lot",
                  color: cvd >= 0 ? const Color(0xFF0284C7) : const Color(0xFFDC2626),
                  icon: PhosphorIcons.lightningBold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBandarPill({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // --- AI SUPER-VERDICT & TARGETS ---
  Widget _buildAIVerdictCard(Map<String, dynamic> ai) {
    if (ai.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(
          "Belum ada kalkulasi prediksi AI terkini untuk saham ini.",
          style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 12),
        ),
      );
    }

    final winRate = (ai['prediction_probability'] as num?)?.toDouble() ?? 0.0;
    final tp = (ai['predicted_peak'] as num?)?.toDouble() ?? 0.0;
    final sl = (ai['stop_loss_now'] as num?)?.toDouble() ?? (ai['predicted_floor'] as num?)?.toDouble() ?? 0.0;
    final days = (ai['predicted_days'] as num?)?.toInt() ?? 0;
    final gainPct = (ai['potential_gain_percent'] as num?)?.toDouble() ?? 0.0;
    final riskPct = (ai['potential_risk_percent'] as num?)?.toDouble() ?? 0.0;
    final rr = (ai['risk_reward_ratio'] as num?)?.toDouble() ?? 0.0;
    final reason = ai['reason']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(PhosphorIcons.brainBold, size: 18, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 8),
                  Text(
                    "AI Trading Super-Verdict",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "${winRate.toStringAsFixed(1)}% Conviction",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF7C3AED),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Progress Bar Conviction
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (winRate / 100.0).clamp(0.0, 1.0),
              minHeight: 8,
              color: winRate >= 60 ? const Color(0xFF059669) : (winRate >= 45 ? const Color(0xFF0284C7) : const Color(0xFFD97706)),
              backgroundColor: const Color(0xFFF1F5F9),
            ),
          ),
          const SizedBox(height: 14),

          // Target grid
          Row(
            children: [
              Expanded(
                child: _buildTargetCard(
                  label: "TARGET TP (PEAK)",
                  value: fmt.format(tp),
                  subValue: "+${gainPct.toStringAsFixed(1)}% Gain",
                  color: const Color(0xFF059669),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTargetCard(
                  label: "STOP LOSS (FLOOR)",
                  value: fmt.format(sl),
                  subValue: "-${riskPct.toStringAsFixed(1)}% Risk",
                  color: const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildTargetCard(
                  label: "RISK / REWARD",
                  value: "${rr.toStringAsFixed(2)}x",
                  subValue: rr >= 2.0 ? "Menguntungkan" : "Defensif",
                  color: const Color(0xFF0284C7),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTargetCard(
                  label: "HORIZON AI",
                  value: "$days Hari",
                  subValue: "Swing Position",
                  color: const Color(0xFF7C3AED),
                ),
              ),
            ],
          ),

          if (reason.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(PhosphorIcons.sparkleBold, size: 13, color: Color(0xFFD97706)),
                      const SizedBox(width: 6),
                      Text(
                        "AI Rationale & Analisa Pasar:",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    reason,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF475569),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTargetCard({
    required String label,
    required String value,
    required String subValue,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subValue,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color.withOpacity(0.85),
            ),
          ),
        ],
      ),
    );
  }

  // --- BANNER DATABASE CONFIG ---
  Widget _buildDatabaseConfigBanner(Map<String, dynamic> config) {
    final sectorName = config['sector_name'] ?? 'Belum Ditentukan';
    final isActive = (config['is_active'] as num?)?.toInt() == 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(PhosphorIcons.databaseBold, color: Color(0xFF0284C7), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Pengaturan Database Saham",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Sektor: $sectorName • ${isActive ? 'Aktif' : 'Nonaktif'}",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => _openDatabaseEditModal(context),
            child: Text(
              "Koreksi",
              style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  // --- BOTTOM ACTION BAR ---
  Widget _buildBottomActionBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0284C7),
                side: const BorderSide(color: Color(0xFF0284C7)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(PhosphorIcons.databaseBold, size: 16),
              label: Text(
                "Ubah DB",
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              onPressed: () => _openDatabaseEditModal(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 1,
              ),
              icon: const Icon(PhosphorIcons.lightningBold, size: 18),
              label: Text(
                "ORDER SMART BUY",
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              onPressed: () => _showSmartBuyModal(context),
            ),
          ),
        ],
      ),
    );
  }

  // --- MODAL: UBAH DATA SAHAM DI DATABASE ---
  void _openDatabaseEditModal(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DatabaseEditSheet(
        symbol: widget.symbol,
        onSaved: () {
          ref.refresh(stockDetailProvider((symbol: widget.symbol, timeframe: _timeframe)));
        },
      ),
    );
  }

  // --- MODAL: SMART BUY ---
  void _showSmartBuyModal(BuildContext context) {
    final detailAsync = ref.read(stockDetailProvider((symbol: widget.symbol, timeframe: _timeframe)));
    detailAsync.whenData((data) {
      final price = (data['price'] as num?)?.toDouble() ?? 0.0;
      final ai = (data['ai_analysis'] as Map<String, dynamic>?) ?? {};
      final rec = ai['recommendation'] ?? '';

      int defaultLots = 1;
      final regex = RegExp(r'Target:\s*(\d+)\s*Lot');
      final match = regex.firstMatch(rec);
      if (match != null) {
        defaultLots = int.tryParse(match.group(1)!) ?? 1;
      }

      int lots = defaultLots;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetCtx) => StatefulBuilder(
          builder: (stCtx, setModalState) {
            final totalCost = (lots * 100 * price) * 1.0015;
            return Container(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(stCtx).viewInsets.bottom + 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Smart Order AI: ${widget.symbol}",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        fmt.format(price),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Jumlah Lot (1 Lot = 100 Lembar):",
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        style: IconButton.styleFrom(backgroundColor: const Color(0xFFF1F5F9)),
                        icon: const Icon(PhosphorIcons.minusBold, color: Color(0xFF0F172A)),
                        onPressed: () {
                          if (lots > 1) {
                            setModalState(() => lots--);
                          }
                        },
                      ),
                      const SizedBox(width: 16),
                      Text(
                        "$lots Lot",
                        style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        style: IconButton.styleFrom(backgroundColor: const Color(0xFFF1F5F9)),
                        icon: const Icon(PhosphorIcons.plusBold, color: Color(0xFF0F172A)),
                        onPressed: () => setModalState(() => lots++),
                      ),
                      const Spacer(),
                      Text(
                        "Total: ${fmt.format(totalCost)}",
                        style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () async {
                        try {
                          await ref.read(apiProvider).addPortfolioPosition(
                                symbol: widget.symbol,
                                price: price,
                                lot: lots,
                              );
                          Navigator.pop(sheetCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Berhasil membeli $lots Lot ${widget.symbol}!"),
                              backgroundColor: const Color(0xFF059669),
                            ),
                          );
                          ref.refresh(stockDetailProvider((symbol: widget.symbol, timeframe: _timeframe)));
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Gagal order: $e"),
                              backgroundColor: const Color(0xFFDC2626),
                            ),
                          );
                        }
                      },
                      child: Text(
                        "EKSEKUSI BELI SEKARANG",
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    });
  }
}

// --- SHEET UBAH DATA DATABASE (LIGHT THEME) ---
class _DatabaseEditSheet extends ConsumerStatefulWidget {
  final String symbol;
  final VoidCallback onSaved;

  const _DatabaseEditSheet({
    required this.symbol,
    required this.onSaved,
  });

  @override
  ConsumerState<_DatabaseEditSheet> createState() => _DatabaseEditSheetState();
}

class _DatabaseEditSheetState extends ConsumerState<_DatabaseEditSheet> {
  int? _selectedSectorId;
  bool _isActive = true;
  final _tpController = TextEditingController();
  final _slController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  List<Map<String, dynamic>> _sectors = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final api = ref.read(apiProvider);
      final detail = await api.getStockDetail(widget.symbol);
      final sectors = await api.getSectors();

      final cfg = detail['user_config'] as Map<String, dynamic>? ?? {};
      final port = detail['portfolio'] as Map<String, dynamic>? ?? {};

      setState(() {
        _sectors = sectors.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _selectedSectorId = (cfg['sector_id'] as num?)?.toInt() ?? (_sectors.isNotEmpty ? _sectors.first['id'] as int : 0);
        _isActive = (cfg['is_active'] as num?)?.toInt() != 0;

        if (port['target_price'] != null && (port['target_price'] as num) > 0) {
          _tpController.text = (port['target_price'] as num).toInt().toString();
        }
        if (port['stop_loss'] != null && (port['stop_loss'] as num) > 0) {
          _slController.text = (port['stop_loss'] as num).toInt().toString();
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();
    try {
      final api = ref.read(apiProvider);
      final double? target = double.tryParse(_tpController.text.trim());
      final double? sl = double.tryParse(_slController.text.trim());

      await api.updateStockData(
        widget.symbol,
        sectorId: _selectedSectorId,
        isActive: _isActive ? 1 : 0,
        targetPrice: target,
        stopLoss: sl,
      );

      widget.onSaved();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(PhosphorIcons.checkCircleBold, color: Colors.white),
              const SizedBox(width: 8),
              Text("Database ${widget.symbol} berhasil diperbarui!"),
            ],
          ),
          backgroundColor: const Color(0xFF059669),
        ),
      );
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal simpan database: $e"), backgroundColor: const Color(0xFFDC2626)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: _isLoading
          ? const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator(color: Color(0xFF0284C7))),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(PhosphorIcons.databaseBold, color: Color(0xFF0284C7), size: 22),
                      const SizedBox(width: 10),
                      Text(
                        "Kelola Data Saham: ${widget.symbol}",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Ubah sektor klasifikasi, status aktif pantauan AI, atau override target di database server.",
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 20),

                  // SEKTOR PILIHAN
                  Text(
                    "Klasifikasi Sektor Saham:",
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _sectors.map((sec) {
                      final secId = sec['id'] as int;
                      final isSelected = _selectedSectorId == secId;
                      return ChoiceChip(
                        label: Text(sec['name'].toString()),
                        selected: isSelected,
                        selectedColor: const Color(0xFF0284C7),
                        backgroundColor: const Color(0xFFF1F5F9),
                        labelStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF334155),
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _selectedSectorId = secId);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // STATUS AKTIF WATCHLIST
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Status Pantauan AI",
                              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                            ),
                            Text(
                              _isActive ? "AI aktif menganalisa pergerakan saham ini" : "Saham di-pause dari pemindaian",
                              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                        Switch(
                          value: _isActive,
                          activeColor: const Color(0xFF059669),
                          onChanged: (val) => setState(() => _isActive = val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // TARGET HARGA CUSTOM (OPSIONAL)
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Custom Target TP (Rp):",
                              style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _tpController,
                              keyboardType: TextInputType.number,
                              style: GoogleFonts.plusJakartaSans(color: const Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w700),
                              decoration: InputDecoration(
                                hintText: "Contoh: 3500",
                                hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Custom Stop Loss (Rp):",
                              style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _slController,
                              keyboardType: TextInputType.number,
                              style: GoogleFonts.plusJakartaSans(color: const Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w700),
                              decoration: InputDecoration(
                                hintText: "Contoh: 3100",
                                hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // TOMBOL SIMPAN
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _isSaving ? null : _saveChanges,
                      child: _isSaving
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(
                              "SIMPAN KE DATABASE",
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 14),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// --- CUSTOM PAINTER: STOCKBIT-STYLE CHART (LIGHT THEME) ---
class StockbitLightChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> candles;
  final bool isCandleMode;
  final bool isUp;
  final int? hoveredIndex;

  StockbitLightChartPainter({
    required this.candles,
    required this.isCandleMode,
    required this.isUp,
    required this.hoveredIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;

    final n = candles.length;
    final w = size.width;
    final h = size.height;

    // Bottom 22% reserved for volume histogram
    final chartHeight = h * 0.74;
    final volHeight = h * 0.20;

    // 1. Calculate price min & max
    double minP = double.infinity;
    double maxP = -double.infinity;
    double maxVol = 0.0;

    for (var c in candles) {
      final p = (c['price'] as num?)?.toDouble() ?? (c['close'] as num?)?.toDouble() ?? 0.0;
      final hi = (c['high'] as num?)?.toDouble() ?? p;
      final lo = (c['low'] as num?)?.toDouble() ?? p;
      final v = (c['volume'] as num?)?.toDouble() ?? 0.0;

      if (hi > maxP) maxP = hi;
      if (lo < minP && lo > 0) minP = lo;
      if (v > maxVol) maxVol = v;
    }

    if (maxP == minP) {
      maxP += 10;
      minP = max(1, minP - 10);
    }
    // Headroom
    final rangeP = maxP - minP;
    final paddedMaxP = maxP + rangeP * 0.08;
    final paddedMinP = max(1.0, minP - rangeP * 0.08);
    final finalRange = paddedMaxP - paddedMinP;

    // 2. Draw Horizontal Gridlines & Price Labels (Light Theme)
    final gridPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final textStyle = GoogleFonts.plusJakartaSans(
      fontSize: 9,
      fontWeight: FontWeight.w600,
      color: const Color(0xFF94A3B8),
    );

    for (int i = 0; i <= 3; i++) {
      final y = chartHeight * (i / 3.0);
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);

      final priceLabel = paddedMaxP - (finalRange * (i / 3.0));
      final tp = TextPainter(
        text: TextSpan(text: priceLabel.toStringAsFixed(0), style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(w - tp.width - 4, y - tp.height - 2));
    }

    // 3. Draw Volume Histogram at bottom
    final barW = (w / n) * 0.65;
    for (int i = 0; i < n; i++) {
      final v = (candles[i]['volume'] as num?)?.toDouble() ?? 0.0;
      final cClose = (candles[i]['close'] as num?)?.toDouble() ?? (candles[i]['price'] as num?)?.toDouble() ?? 0.0;
      final cOpen = (candles[i]['open'] as num?)?.toDouble() ?? cClose;
      final cIsGreen = cClose >= cOpen;

      final vPct = maxVol > 0 ? (v / maxVol).clamp(0.02, 1.0) : 0.05;
      final vBarH = volHeight * vPct;
      final x = (i / (n - 1 == 0 ? 1 : n - 1)) * w;

      final vPaint = Paint()
        ..color = (cIsGreen ? const Color(0xFF059669) : const Color(0xFFDC2626)).withOpacity(0.2)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - barW / 2, h - vBarH, barW, vBarH),
          const Radius.circular(2),
        ),
        vPaint,
      );
    }

    // 4. Draw Line or Candlestick
    final lineColor = isUp ? const Color(0xFF059669) : const Color(0xFFDC2626);

    if (isCandleMode) {
      // CANDLESTICK DRAWING
      for (int i = 0; i < n; i++) {
        final c = candles[i];
        final op = (c['open'] as num?)?.toDouble() ?? 0.0;
        final hi = (c['high'] as num?)?.toDouble() ?? op;
        final lo = (c['low'] as num?)?.toDouble() ?? op;
        final cl = (c['close'] as num?)?.toDouble() ?? op;
        final isGreen = cl >= op;

        final x = (i / (n - 1 == 0 ? 1 : n - 1)) * w;
        final yHi = chartHeight - ((hi - paddedMinP) / finalRange * chartHeight);
        final yLo = chartHeight - ((lo - paddedMinP) / finalRange * chartHeight);
        final yOp = chartHeight - ((op - paddedMinP) / finalRange * chartHeight);
        final yCl = chartHeight - ((cl - paddedMinP) / finalRange * chartHeight);

        final candleColor = isGreen ? const Color(0xFF059669) : const Color(0xFFDC2626);
        final wickPaint = Paint()
          ..color = candleColor
          ..strokeWidth = 1.2;

        // Wick
        canvas.drawLine(Offset(x, yHi), Offset(x, yLo), wickPaint);

        // Body
        final bodyTop = min(yOp, yCl);
        final bodyBottom = max(yOp, yCl);
        final bodyHeight = max(2.0, bodyBottom - bodyTop);

        final bodyPaint = Paint()
          ..color = candleColor
          ..style = PaintingStyle.fill;

        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x - barW / 2, bodyTop, barW, bodyHeight),
            const Radius.circular(2),
          ),
          bodyPaint,
        );
      }
    } else {
      // LINE + AREA GRADIENT DRAWING
      final path = Path();
      final fillPath = Path();

      for (int i = 0; i < n; i++) {
        final p = (candles[i]['price'] as num?)?.toDouble() ?? (candles[i]['close'] as num?)?.toDouble() ?? 0.0;
        final x = (i / (n - 1 == 0 ? 1 : n - 1)) * w;
        final y = chartHeight - ((p - paddedMinP) / finalRange * chartHeight);

        if (i == 0) {
          path.moveTo(x, y);
          fillPath.moveTo(x, chartHeight);
          fillPath.lineTo(x, y);
        } else {
          final prevP = (candles[i - 1]['price'] as num?)?.toDouble() ?? (candles[i - 1]['close'] as num?)?.toDouble() ?? 0.0;
          final prevX = ((i - 1) / (n - 1)) * w;
          final prevY = chartHeight - ((prevP - paddedMinP) / finalRange * chartHeight);

          // Smooth cubic bezier
          final cx1 = prevX + (x - prevX) / 2;
          final cy1 = prevY;
          final cx2 = prevX + (x - prevX) / 2;
          final cy2 = y;

          path.cubicTo(cx1, cy1, cx2, cy2, x, y);
          fillPath.cubicTo(cx1, cy1, cx2, cy2, x, y);
        }
      }

      fillPath.lineTo(w, chartHeight);
      fillPath.close();

      // Shader fill
      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lineColor.withOpacity(0.18),
            lineColor.withOpacity(0.01),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, chartHeight));

      canvas.drawPath(fillPath, fillPaint);

      // Stroke Line
      final strokePaint = Paint()
        ..color = lineColor
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke;

      canvas.drawPath(path, strokePaint);
    }

    // 5. Crosshair Touch Indicator
    if (hoveredIndex != null && hoveredIndex! >= 0 && hoveredIndex! < n) {
      final hIdx = hoveredIndex!;
      final hX = (hIdx / (n - 1 == 0 ? 1 : n - 1)) * w;
      final hP = (candles[hIdx]['price'] as num?)?.toDouble() ?? (candles[hIdx]['close'] as num?)?.toDouble() ?? 0.0;
      final hY = chartHeight - ((hP - paddedMinP) / finalRange * chartHeight);

      // Vertical line
      final crossPaint = Paint()
        ..color = const Color(0xFF64748B).withOpacity(0.6)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      canvas.drawLine(Offset(hX, 0), Offset(hX, h), crossPaint);

      // Dot
      final dotHalo = Paint()..color = lineColor.withOpacity(0.25);
      final dotCore = Paint()..color = lineColor;

      canvas.drawCircle(Offset(hX, hY), 7, dotHalo);
      canvas.drawCircle(Offset(hX, hY), 3.5, dotCore);
    }
  }

  @override
  bool shouldRepaint(covariant StockbitLightChartPainter oldDelegate) {
    return oldDelegate.candles != candles ||
        oldDelegate.isCandleMode != isCandleMode ||
        oldDelegate.hoveredIndex != hoveredIndex ||
        oldDelegate.isUp != isUp;
  }
}
