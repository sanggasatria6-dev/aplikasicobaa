import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'api_service.dart';
import 'notifications_screen.dart';
import 'stock_detail_screen.dart';

final analysisProvider = FutureProvider.autoDispose((ref) => ref.watch(apiProvider).getAnalysis());
final capitalProvider = FutureProvider.autoDispose((ref) => ref.watch(apiProvider).getCapital());

class MarketScreen extends ConsumerStatefulWidget {
  const MarketScreen({super.key});

  @override
  ConsumerState<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends ConsumerState<MarketScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = "";
  String _selectedSector = "Semua";

  final List<String> _sectorCategories = [
    "Semua",
    "Perbankan",
    "Energi",
    "Pertambangan",
    "Konsumen",
    "Infrastruktur & Telco",
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Tema Terang Bersih & Modern
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Row(
          children: [
            Text(
              "Market Advisor",
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF059669).withOpacity(0.3)),
              ),
              child: Text(
                "LIVE AI",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF059669),
                ),
              ),
            ),
          ],
        ),
        actions: [
          Consumer(
            builder: (ctx, watchRef, _) {
              final notifsAsync = watchRef.watch(notificationsProvider);
              final unread = notifsAsync.maybeWhen(
                data: (res) => res['unread_count'] as int? ?? 0,
                orElse: () => 0,
              );

              return IconButton(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(PhosphorIcons.bellBold, color: Color(0xFF0F172A)),
                    if (unread > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Color(0xFFDC2626),
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            unread > 99 ? '99+' : '$unread',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                tooltip: "Notifikasi Sinyal ($unread)",
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                  );
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(PhosphorIcons.scanBold, color: Color(0xFF059669)),
            tooltip: "Scan Market AI Sekarang",
            onPressed: () async {
              HapticFeedback.mediumImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    "AI sedang menganalisa seluruh pasar & flow transaksi...",
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                  ),
                  backgroundColor: const Color(0xFF0F172A),
                ),
              );
              await ref.read(apiProvider).triggerMarketScan();
            },
          ),
          IconButton(
            icon: const Icon(PhosphorIcons.arrowsClockwiseBold, color: Color(0xFF0F172A)),
            tooltip: "Refresh Data",
            onPressed: () {
              HapticFeedback.lightImpact();
              ref.refresh(analysisProvider);
              ref.refresh(notificationsProvider);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // SEARCH BAR & SECTOR PILL FILTERS (LIGHT THEME)
          _buildSearchAndFilters(),

          // LIST DATA SAHAM
          Expanded(
            child: ref.watch(analysisProvider).when(
              data: (data) => _buildStockList(context, data, fmt),
              loading: () => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFF059669)),
                    const SizedBox(height: 16),
                    Text(
                      "Mengambil rekomendasi & analisa AI...",
                      style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 13),
                    ),
                  ],
                ),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFECACA)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(PhosphorIcons.warningOctagonBold, size: 40, color: Color(0xFFDC2626)),
                        const SizedBox(height: 10),
                        Text(
                          "Gagal Memuat Analisa Pasar",
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "$e",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(PhosphorIcons.arrowsClockwiseBold, size: 16),
                          label: const Text("COBA LAGI"),
                          onPressed: () => ref.refresh(analysisProvider),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- SEARCH & FILTER BAR (LIGHT THEME) ---
  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search TextField
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => setState(() => _searchQuery = val.trim().toUpperCase()),
              style: GoogleFonts.plusJakartaSans(color: const Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: "Cari saham (Contoh: BBRI, ANTM, ...)",
                hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8), fontSize: 13),
                prefixIcon: const Icon(PhosphorIcons.magnifyingGlassBold, size: 16, color: Color(0xFF64748B)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(PhosphorIcons.xCircleFill, size: 16, color: Color(0xFF94A3B8)),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = "");
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Horizontal Sector Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _sectorCategories.map((sec) {
                final isSelected = _selectedSector == sec;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedSector = sec);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Text(
                        sec,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // --- LISTVIEW BUILDER (LIGHT THEME) ---
  Widget _buildStockList(BuildContext context, List<dynamic> data, NumberFormat fmt) {
    if (data.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(PhosphorIcons.chartLineBold, size: 48, color: Color(0xFF94A3B8)),
              const SizedBox(height: 12),
              Text(
                "Belum Ada Data Analisis AI",
                style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 6),
              Text(
                "Tekan tombol SCAN di kanan atas untuk menganalisis pergerakan saham hari ini.",
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                icon: const Icon(PhosphorIcons.scanBold, size: 16),
                label: Text("SCAN PASAR SEKARANG", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                onPressed: () async {
                  await ref.read(apiProvider).triggerMarketScan();
                  ref.refresh(analysisProvider);
                },
              ),
            ],
          ),
        ),
      );
    }

    // Filter by search & sector
    final filtered = data.where((item) {
      final sym = (item['symbol'] ?? '').toString().toUpperCase();
      final matchSearch = _searchQuery.isEmpty || sym.contains(_searchQuery);
      if (!matchSearch) return false;

      if (_selectedSector == "Semua") return true;

      final reason = (item['reason'] ?? '').toString().toLowerCase();
      final rec = (item['recommendation'] ?? '').toString().toLowerCase();

      if (_selectedSector == "Perbankan" && (sym.startsWith("BB") || reason.contains("bank") || rec.contains("bank"))) return true;
      if (_selectedSector == "Energi" && (sym.contains("ADRO") || sym.contains("PGAS") || sym.contains("MEDC") || sym.contains("ENRG"))) return true;
      if (_selectedSector == "Pertambangan" && (sym.contains("ANTM") || sym.contains("MDKA") || sym.contains("BRMS") || sym.contains("INCO") || sym.contains("BUMI"))) return true;
      if (_selectedSector == "Konsumen" && (sym.contains("ICBP") || sym.contains("INDF") || sym.contains("UNVR"))) return true;
      if (_selectedSector == "Infrastruktur & Telco" && (sym.contains("TLKM") || sym.contains("EXCL") || sym.contains("JSMR") || sym.contains("ASII"))) return true;

      return _selectedSector == "Semua";
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(PhosphorIcons.magnifyingGlassBold, size: 40, color: Color(0xFF94A3B8)),
              const SizedBox(height: 12),
              Text(
                "Tidak ada saham yang cocok",
                style: GoogleFonts.plusJakartaSans(color: const Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 6),
              Text(
                "Coba gunakan kata kunci lain atau pilih tab 'Semua'.",
                style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: filtered.length,
      itemBuilder: (ctx, i) {
        final item = filtered[i];
        final symbol = item['symbol'] ?? '-';
        final price = (item['current_price'] as num).toDouble();
        final target = (item['predicted_peak'] as num).toDouble();
        final rec = item['recommendation'] ?? 'NETRAL';

        // Extract lot suggestion
        String lotSuggestion = "";
        if (rec.contains("Target:")) {
          final regex = RegExp(r'Target:\s*(\d+)\s*Lot');
          final match = regex.firstMatch(rec);
          if (match != null) {
            lotSuggestion = "${match.group(1)} Lot";
          }
        }

        final winRate = (item['prediction_probability'] as num? ?? 0).toDouble();
        final profitPot = (item['potential_gain_percent'] as num? ?? 0).toDouble();

        // Recommendation styling
        Color badgeBg = const Color(0xFFF1F5F9);
        Color badgeFg = const Color(0xFF64748B);
        Color cardBorder = const Color(0xFFE2E8F0);

        if (rec.contains("STRONG")) {
          badgeBg = const Color(0xFFD1FAE5);
          badgeFg = const Color(0xFF059669);
          cardBorder = const Color(0xFF059669).withOpacity(0.5);
        } else if (rec.contains("BELI") || rec.contains("BUY")) {
          badgeBg = const Color(0xFFE0F2FE);
          badgeFg = const Color(0xFF0284C7);
          cardBorder = const Color(0xFF0284C7).withOpacity(0.4);
        } else if (rec.contains("JUAL") || rec.contains("HINDARI") || rec.contains("AVOID")) {
          badgeBg = const Color(0xFFFEE2E2);
          badgeFg = const Color(0xFFDC2626);
          cardBorder = const Color(0xFFDC2626).withOpacity(0.3);
        }

        // Regime HMM mapping: 0=Crash, 1=Sideways, 2=Bull
        final regime = item['market_regime'] ?? 1;
        String regimeLabel = "";
        Color regimeBg = Colors.transparent;
        Color regimeFg = Colors.transparent;

        if (regime == 0) {
          regimeLabel = "⚠️ CRASH";
          regimeBg = const Color(0xFFFEE2E2);
          regimeFg = const Color(0xFFDC2626);
        } else if (regime == 2) {
          regimeLabel = "🚀 BULL";
          regimeBg = const Color(0xFFD1FAE5);
          regimeFg = const Color(0xFF059669);
        } else if (regime == 1) {
          regimeLabel = "⚖️ SIDEWAYS";
          regimeBg = const Color(0xFFFEF3C7);
          regimeFg = const Color(0xFFD97706);
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cardBorder, width: rec.contains("STRONG") ? 1.5 : 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StockDetailScreen(
                    symbol: symbol,
                    initialData: item,
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // BARIS 1: Header Ticker & Badges
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Hero(
                            tag: 'stock_$symbol',
                            child: Material(
                              color: Colors.transparent,
                              child: Text(
                                symbol,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 19,
                                  color: const Color(0xFF0F172A),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                          if (regimeLabel.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: regimeBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                regimeLabel,
                                style: GoogleFonts.plusJakartaSans(
                                  color: regimeFg,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          rec.contains("STRONG")
                              ? "🚀 STRONG BUY"
                              : (rec.contains("BELI")
                                  ? "📈 SIGNAL BUY"
                                  : (rec.contains("HINDARI") || rec.contains("AVOID") ? "🛡️ WAIT" : "⚖️ NETRAL")),
                          style: GoogleFonts.plusJakartaSans(
                            color: badgeFg,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (lotSuggestion.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(PhosphorIcons.lightningFill, size: 14, color: Color(0xFF059669)),
                        const SizedBox(width: 4),
                        Text(
                          "Rekomendasi AI: $lotSuggestion",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: const Color(0xFF059669),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 12),

                  // BARIS 2: Metrics Chips
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "WIN RATE AI",
                                style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "${winRate.toStringAsFixed(1)}%",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0284C7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "POTENSI GAIN",
                                style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "+${profitPot.toStringAsFixed(1)}%",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: profitPot > 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // BARIS 3: Price vs Target
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Harga: ${fmt.format(price)}",
                        style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF0F172A), fontWeight: FontWeight.w700),
                      ),
                      Text(
                        "Target TP: ${fmt.format(target)}",
                        style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF059669), fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // BARIS 4: Conviction Progress Bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "AI Conviction Score",
                            style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
                          ),
                          Text(
                            "${winRate.toStringAsFixed(0)}%",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: winRate >= 65 ? const Color(0xFF059669) : (winRate >= 50 ? const Color(0xFF0284C7) : const Color(0xFFD97706)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (winRate / 100.0).clamp(0.0, 1.0),
                          minHeight: 6,
                          color: winRate >= 65 ? const Color(0xFF059669) : (winRate >= 50 ? const Color(0xFF0284C7) : const Color(0xFFD97706)),
                          backgroundColor: const Color(0xFFF1F5F9),
                        ),
                      ),
                    ],
                  ),

                  if ((item['reason']?.toString() ?? '').isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(PhosphorIcons.brainBold, size: 14, color: Color(0xFF7C3AED)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item['reason'].toString(),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF475569),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // ACTION BUTTONS INSIDE CARD
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(PhosphorIcons.chartLineUpBold, size: 14, color: Color(0xFF0284C7)),
                          const SizedBox(width: 4),
                          Text(
                            "Detail & Live Orderbook ➔",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0284C7),
                            ),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          _showSmartBuySheet(context, ref, item);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(PhosphorIcons.lightningBold, size: 12, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                "Beli Cepat",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // SMART BUY BOTTOM SHEET (LIGHT THEME)
  void _showSmartBuySheet(BuildContext context, WidgetRef ref, dynamic item) {
    ref.read(capitalProvider.future).then((capData) {
      final cash = (capData['current_capital'] as num).toDouble();
      final initialPrice = (item['current_price'] as num).toDouble();

      int initialLot = 1;
      final rec = item['recommendation'] ?? "";
      if (rec.contains("Target:")) {
        final regex = RegExp(r'Target:\s*(\d+)\s*Lot');
        final match = regex.firstMatch(rec);
        if (match != null) {
          initialLot = int.tryParse(match.group(1)!) ?? 1;
        }
      }

      if (!context.mounted) return;

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) {
          final priceCtrl = TextEditingController(text: initialPrice.toStringAsFixed(0));
          double currentPrice = initialPrice;
          int lots = initialLot;

          return StatefulBuilder(
            builder: (ctx, setState) {
              final costPerLot = (currentPrice * 100) * 1.0015; // Fee 0.15%
              int maxLot = (cash / costPerLot).floor();
              if (maxLot < 0) maxLot = 0;

              if (lots > maxLot && maxLot > 0) lots = maxLot;
              if (lots == 0 && maxLot > 0) lots = 1;

              final totalCost = lots * costPerLot;
              final isOverBudget = totalCost > cash;

              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                  top: 24,
                  left: 24,
                  right: 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle Bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Beli ${item['symbol']}",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "Saldo: ${NumberFormat.compact(locale: 'id').format(cash)}",
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Input Harga
                    Text(
                      "HARGA BELI (RP)",
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        suffixText: "/ lembar",
                        suffixStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      onChanged: (val) {
                        setState(() {
                          currentPrice = double.tryParse(val) ?? 0;
                        });
                      },
                    ),

                    const SizedBox(height: 16),

                    // Input Lot Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "JUMLAH LOT",
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF64748B),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          "Max: $maxLot Lot",
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF94A3B8),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(ctx).copyWith(
                              activeTrackColor: const Color(0xFF059669),
                              inactiveTrackColor: const Color(0xFFE2E8F0),
                              thumbColor: const Color(0xFF059669),
                              overlayColor: const Color(0xFF059669).withOpacity(0.12),
                            ),
                            child: Slider(
                              value: (lots > maxLot ? maxLot : lots).toDouble(),
                              min: 0,
                              max: maxLot > 0 ? maxLot.toDouble() : 1.0,
                              divisions: maxLot > 0 ? maxLot : 1,
                              onChanged: (v) => setState(() => lots = v.toInt()),
                            ),
                          ),
                        ),
                        Container(
                          width: 56,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            "$lots",
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    const Divider(color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 12),

                    // Total Biaya
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Total Estimasi (inc fee):",
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF64748B),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(totalCost),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isOverBudget ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),

                    if (isOverBudget) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          children: [
                            const Icon(PhosphorIcons.warningCircleBold, size: 16, color: Color(0xFFDC2626)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                cash <= 0
                                    ? "Saldo kas Anda saat ini Rp 0. Silakan Top Up terlebih dahulu di Dashboard."
                                    : "Saldo kas tidak mencukupi untuk ${lots} lot.",
                                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFFDC2626), fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Tombol Konfirmasi Beli
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isOverBudget ? const Color(0xFF94A3B8) : const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: (lots == 0 || isOverBudget || currentPrice <= 0)
                            ? null
                            : () async {
                                Navigator.pop(ctx);
                                try {
                                  await ref.read(apiProvider).addPortfolioPosition(
                                    symbol: item['symbol'],
                                    price: currentPrice,
                                    lot: lots,
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Order Pembelian Berhasil Dikirim!"),
                                        backgroundColor: Color(0xFF059669),
                                      ),
                                    );
                                  }
                                  ref.invalidate(capitalProvider);
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red),
                                    );
                                  }
                                }
                              },
                        child: Text(
                          "KONFIRMASI BELI",
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    });
  }
}
