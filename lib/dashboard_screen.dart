import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'api_service.dart';

// Provider
final capitalProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(apiProvider).getCapital(),
);
final portfolioProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(apiProvider).getPortfolio(),
);
final analysisProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(apiProvider).getAnalysis(),
); // Untuk saran beli

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
      appBar: AppBar(
        title: const Text("DASHBOARD LIVE"),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIcons.arrowsClockwise),
            onPressed: () {
              ref.invalidate(capitalProvider);
              ref.invalidate(portfolioProvider);
              ref.invalidate(analysisProvider);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF00E676),
        icon: const Icon(PhosphorIcons.plus, color: Colors.black),
        label: const Text(
          "INPUT BUY MANUAL",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        onPressed: () => _showManualBuyDialog(context, ref),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(capitalProvider);
          ref.invalidate(portfolioProvider);
          ref.invalidate(analysisProvider);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. KARTU SALDO
              _buildWalletCard(ref, fmt, context),

              const SizedBox(height: 24),

              // 2. [BARU] SARAN PEMBELIAN DARI AI (DIFILTER)
              _buildAiRecommendations(ref, context, fmt),

              const SizedBox(height: 24),
              const Text(
                "LIVE HOLDINGS (Saham Aktif)",
                style: TextStyle(
                  color: Colors.white54,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),

              // 3. LIST SAHAM AKTIF
              ref
                  .watch(portfolioProvider)
                  .when(
                    data: (list) {
                      if (list.isEmpty)
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              "Portofolio Kosong.",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        );

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: list.length,
                        itemBuilder: (ctx, i) {
                          final item = list[i];
                          // Ambil saran dari database yang sudah diupdate backend
                          final advice =
                              item['advice'] as String? ??
                              "Menunggu analisis AI...";

                          // Tentukan warna status berdasarkan kata kunci
                          Color statusColor = const Color(
                            0xFF2979FF,
                          ); // Default Biru (Netral)
                          if (advice.contains("TAKE PROFIT") ||
                              advice.contains("Untung"))
                            statusColor = const Color(0xFF00E676);
                          if (advice.contains("CUT LOSS") ||
                              advice.contains("JUAL"))
                            statusColor = Colors.red;
                          if (advice.contains("HOLD"))
                            statusColor = Colors.amber;

                          return Card(
                            color: const Color(0xFF1E1E1E),
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              side: BorderSide(
                                color: statusColor.withOpacity(0.3),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['symbol'],
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            "${item['lot']} Lot  •  Avg: ${fmt.format(item['avg_price'])}",
                                            style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red
                                              .withOpacity(0.2),
                                          foregroundColor: Colors.red,
                                        ),
                                        onPressed:
                                            () => _showSellDialog(
                                              context,
                                              ref,
                                              item,
                                            ),
                                        child: const Text("JUAL"),
                                      ),
                                    ],
                                  ),
                                  const Divider(color: Colors.white10),
                                  Row(
                                    children: [
                                      Icon(
                                        PhosphorIcons.robot,
                                        size: 16,
                                        color: statusColor,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          advice,
                                          style: TextStyle(
                                            color: statusColor,
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                    loading:
                        () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text("Error Porto: $e"),
                  ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  // WIDGET: SARAN PEMBELIAN BARU (DIFILTER)
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
            Icon(PhosphorIcons.sparkle, color: Color(0xFF00E676), size: 16),
            SizedBox(width: 8),
            Text(
              "AI OPPORTUNITIES (Rekomendasi Beli)",
              style: TextStyle(
                color: Color(0xFF00E676),
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Gabungkan data Portfolio & Market Analysis untuk filtering
        Consumer(
          builder: (context, ref, _) {
            final portfolioAsync = ref.watch(portfolioProvider);
            final analysisAsync = ref.watch(analysisProvider);

            return analysisAsync.when(
              data: (marketData) {
                return portfolioAsync.when(
                  data: (portfolioList) {
                    // 1. Ambil List Saham yang SUDAH DIBELI
                    final ownedSymbols =
                        portfolioList
                            .map((e) => e['symbol'].toString())
                            .toSet();

                    // 2. Filter Market Data:
                    //    - Rekomendasi harus "STRONG BUY" atau "BELI"
                    //    - Symbol TIDAK BOLEH ada di ownedSymbols
                    final suggestions =
                        marketData.where((item) {
                          final rec = item['recommendation'] ?? 'NETRAL';
                          final symbol = item['symbol'];
                          final isGoodSignal =
                              rec.contains("STRONG") || rec == "BELI";
                          final isNotOwned = !ownedSymbols.contains(symbol);
                          return isGoodSignal && isNotOwned;
                        }).toList();

                    if (suggestions.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          "Tidak ada sinyal beli baru yang valid saat ini.",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    // 3. Tampilkan Horizontal List
                    return SizedBox(
                      height: 140, // Tinggi area saran
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: suggestions.length,
                        itemBuilder: (ctx, i) {
                          final item = suggestions[i];
                          final rec = item['recommendation'];
                          final isStrong = rec.contains("STRONG");

                          return Container(
                            width: 160,
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E1E),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    isStrong
                                        ? const Color(0xFF00E676)
                                        : Colors.green.withOpacity(0.5),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      item['symbol'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (isStrong)
                                      const Icon(
                                        PhosphorIcons.fire,
                                        size: 16,
                                        color: Colors.orange,
                                      ),
                                  ],
                                ),
                                Text(
                                  fmt.format(item['current_price']),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Target: ${fmt.format(item['predicted_peak'])}",
                                  style: const TextStyle(
                                    color: Color(0xFF00E676),
                                    fontSize: 11,
                                  ),
                                ),

                                // [BARU] Tampilkan Badge Lot jika ada
                                if (item['recommendation'].toString().contains(
                                  "Target:",
                                ))
                                  Container(
                                    margin: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      item['recommendation']
                                          .toString()
                                          .split('(')
                                          .last
                                          .replaceAll(
                                            ')',
                                            '',
                                          ), // Ambil teks "(Target: 5 Lot)"
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF00E676),
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),

                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  height: 30,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00E676),
                                      padding: EdgeInsets.zero,
                                    ),
                                    onPressed: () {
                                      // [BARU] Ambil angka lot dari teks rekomendasi
                                      int suggestedLot = 0;
                                      final recString =
                                          item['recommendation'].toString();
                                      if (recString.contains("Target:")) {
                                        final match = RegExp(
                                          r'Target:\s*(\d+)',
                                        ).firstMatch(recString);
                                        if (match != null)
                                          suggestedLot =
                                              int.tryParse(match.group(1)!) ??
                                              0;
                                      }

                                      _showManualBuyDialog(
                                        context,
                                        ref,
                                        prefillSymbol: item['symbol'],
                                        prefillPrice:
                                            (item['current_price'] as num)
                                                .toDouble(),
                                        prefillLot:
                                            suggestedLot > 0
                                                ? suggestedLot
                                                : null, // Kirim Lot
                                      );
                                    },
                                    child: const Text(
                                      "BELI",
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
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
                  loading: () => const SizedBox(), // Tunggu portfolio load
                  error: (_, __) => const Text("Gagal load portfolio filter"),
                );
              },
              loading:
                  () => const Center(
                    child: LinearProgressIndicator(color: Color(0xFF00E676)),
                  ),
              error: (e, _) => const Text("Gagal load market data"),
            );
          },
        ),
      ],
    );
  }

  Widget _buildWalletCard(
    WidgetRef ref,
    NumberFormat fmt,
    BuildContext context,
  ) {
    return ref
        .watch(capitalProvider)
        .when(
          data: (data) {
            final cash = (data['current_capital'] as num).toDouble();
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E1E1E), Color(0xFF2C2C2C)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  const Text(
                    "CASH AVAILABLE",
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    fmt.format(cash),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _adjustMoney(context, ref, true),
                          child: const Text("TOP UP"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _adjustMoney(context, ref, false),
                          child: const Text("WITHDRAW"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const Text("Gagal muat saldo"),
        );
  }

  // [MODIFIKASI] Support Prefill Data untuk tombol Beli Cepat
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
    // Isi lot otomatis jika ada
    final lotCtrl = TextEditingController(text: prefillLot?.toString() ?? "");

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text("Input Buy Manual"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: symbolCtrl,
                  decoration: const InputDecoration(
                    labelText: "Kode (cth: BBCA)",
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                TextField(
                  controller: priceCtrl,
                  decoration: const InputDecoration(labelText: "Harga Beli"),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: lotCtrl,
                  decoration: const InputDecoration(labelText: "Jumlah Lot"),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                ),
                onPressed: () async {
                  if (symbolCtrl.text.isNotEmpty) {
                    Navigator.pop(ctx);
                    await ref
                        .read(apiProvider)
                        .addPortfolioPosition(
                          symbol: symbolCtrl.text,
                          price: double.tryParse(priceCtrl.text) ?? 0,
                          lot: int.tryParse(lotCtrl.text) ?? 0,
                        );
                    ref.invalidate(portfolioProvider);
                    ref.invalidate(capitalProvider);
                  }
                },
                child: const Text(
                  "SIMPAN",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  void _adjustMoney(BuildContext context, WidgetRef ref, bool isAdd) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text(isAdd ? "Top Up" : "Withdraw"),
            content: TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Nominal"),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await ref
                      .read(apiProvider)
                      .adjustCapital(
                        isAdd
                            ? (double.tryParse(ctrl.text) ?? 0)
                            : -(double.tryParse(ctrl.text) ?? 0),
                        "Manual App",
                      );
                  ref.invalidate(capitalProvider);
                  Navigator.pop(context);
                },
                child: const Text("OK"),
              ),
            ],
          ),
    );
  }

  void _showSellDialog(BuildContext context, WidgetRef ref, dynamic item) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text("Jual ${item['symbol']}?"),
            content: TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Harga Jual Laku"),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  if (ctrl.text.isNotEmpty) {
                    await ref
                        .read(apiProvider)
                        .sellPortfolioPosition(
                          item['id'],
                          double.tryParse(ctrl.text) ?? 0,
                        );
                    ref.invalidate(portfolioProvider);
                    ref.invalidate(capitalProvider);
                    Navigator.pop(context);
                  }
                },
                child: const Text(
                  "JUAL SEKARANG",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }
}
