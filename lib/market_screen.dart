import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'api_service.dart';

final analysisProvider = FutureProvider.autoDispose((ref) => ref.watch(apiProvider).getAnalysis());
final capitalProvider = FutureProvider.autoDispose((ref) => ref.watch(apiProvider).getCapital());

class MarketScreen extends ConsumerWidget {
  const MarketScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat.currency(locale: 'id', symbol: '', decimalDigits: 0);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("MARKET ADVISOR"),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIcons.scan, color: Color(0xFF00E676)),
            tooltip: "Scan Market AI Sekarang",
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("AI sedang menganalisa market... Cek Tab Control untuk progress.")));
              await ref.read(apiProvider).triggerMarketScan();
            },
          ),
          IconButton(
            icon: const Icon(PhosphorIcons.arrowsClockwise),
            onPressed: () => ref.refresh(analysisProvider),
          )
        ],
      ),
      body: ref.watch(analysisProvider).when(
        data: (data) {
          if (data.isEmpty) {
            return const Center(child: Text("Belum ada data analisa AI.\nTekan tombol SCAN di atas.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: data.length,
            itemBuilder: (ctx, i) {
              final item = data[i];
              
              final symbol = item['symbol'] ?? '-';
              final price = (item['current_price'] as num).toDouble();
              final target = (item['predicted_peak'] as num).toDouble();
              
              final rec = item['recommendation'] ?? 'NETRAL'; 
              
              // [BARU] Ambil angka lot dari string rekomendasi backend "Target: X Lot"
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
              
              Color badgeColor = Colors.grey;
              if (rec.contains("STRONG")) badgeColor = const Color(0xFF00E676); 
              else if (rec == "BELI") badgeColor = Colors.green;
              else if (rec.contains("JUAL")) badgeColor = Colors.red;

              return Card(
                color: const Color(0xFF1E1E1E),
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: badgeColor.withOpacity(0.3), width: 1),
                  borderRadius: BorderRadius.circular(12)
                ),
                child: InkWell(
                  onTap: () => _showSmartBuySheet(context, ref, item),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        // BARIS 1
                        // BARIS 1
                        // [BARU] Logika Deteksi Kondisi Pasar (Regime)
                        // Backend mengirim: 0 (Normal), 1 (Bull/Naik), 2 (Bear/Crash)
                        Builder(
                          builder: (context) {
                            final regime = item['market_regime'] ?? 0; 
                            String regimeLabel = "";
                            Color regimeColor = Colors.transparent;

                            if (regime == 2) {
                              regimeLabel = "⚠️ CRASH"; 
                              regimeColor = Colors.red;
                            } else if (regime == 1) {
                              regimeLabel = "🚀 BULL";
                              regimeColor = Colors.blue;
                            }

                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Nama Saham + Badge Regime (jika ada)
                                Row(
                                  children: [
                                    Text(symbol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                    
                                    // Jika status bukan normal, tampilkan badge peringatan
                                    if (regimeLabel.isNotEmpty)
                                      Container(
                                        margin: const EdgeInsets.only(left: 8),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: regimeColor), 
                                          borderRadius: BorderRadius.circular(4)
                                        ),
                                        child: Text(regimeLabel, style: TextStyle(color: regimeColor, fontSize: 9, fontWeight: FontWeight.bold)),
                                      )
                                  ],
                                ),

                                // Badge Rekomendasi (Beli/Jual) - Tetap Disini
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: badgeColor.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                                  child: Text(rec, style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 11)),
                                )
                              ],
                            );
                          }
                        ),
                        
                        // [BARU] Tampilkan badge kecil jika ada saran lot
                        if (lotSuggestion.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 4, bottom: 4),
                            child: Text("Saran AI: $lotSuggestion", style: const TextStyle(fontSize: 11, color: Color(0xFF00E676), fontStyle: FontStyle.italic)),
                          ),

                        const SizedBox(height: 8),
                        // BARIS 2
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Win Rate: ${winRate.toStringAsFixed(1)}%", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            Text("Potensi: +${profitPot.toStringAsFixed(1)}%", style: TextStyle(color: profitPot > 0 ? const Color(0xFF00E676) : Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        const Divider(color: Colors.white10),
                        // BARIS 3
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                             Text("Harga: ${fmt.format(price)}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                             Text("Target: ${fmt.format(target)}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Error: $e")),
      ),
    );
  }

  // --- MODIFIKASI: SMART BUY SHEET DENGAN EDIT HARGA ---
  void _showSmartBuySheet(BuildContext context, WidgetRef ref, dynamic item) {
    ref.read(capitalProvider.future).then((capData) {
      final cash = (capData['current_capital'] as num).toDouble();
      final initialPrice = (item['current_price'] as num).toDouble();
      
      // [BARU] Ambil angka dari rekomendasi untuk mengisi default lot
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
        backgroundColor: const Color(0xFF1E1E1E),
        isScrollControlled: true,
        builder: (ctx) {
          // Setup Controller untuk Edit Harga
          final priceCtrl = TextEditingController(text: initialPrice.toStringAsFixed(0));
          
          // Variabel State Lokal
          double currentPrice = initialPrice;
          int lots = initialLot; // <--- SEKARANG MENGIKUTI SARAN AI
          

          return StatefulBuilder(
            builder: (ctx, setState) {
              // 1. Hitung Max Lot berdasarkan Harga Terkini (yang mungkin sudah diedit user)
              final costPerLot = (currentPrice * 100) * 1.0015; // Fee 0.15%
              int maxLot = (cash / costPerLot).floor();
              if (maxLot < 0) maxLot = 0;

              // 2. Proteksi: Jika harga naik dan lot saat ini melebihi maxLot, turunkan lot
              if (lots > maxLot) lots = maxLot > 0 ? maxLot : 1;
              
              // 3. Hitung Total Cost Real
              final totalCost = lots * costPerLot;
              final isOverBudget = totalCost > cash;

              return Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, top: 24, left: 24, right: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // HEADER
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("BELI ${item['symbol']}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF00E676))),
                        Text("Saldo: ${NumberFormat.compact(locale: 'id').format(cash)}", style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // INPUT HARGA (EDITABLE)
                    const Text("Harga Beli (Rp)", style: TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        suffixText: " / lembar",
                      ),
                      onChanged: (val) {
                        setState(() {
                          // Update harga real-time saat user mengetik
                          currentPrice = double.tryParse(val) ?? 0;
                        });
                      },
                    ),

                    const SizedBox(height: 16),

                    // INPUT LOT (SLIDER)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Jumlah Lot", style: TextStyle(color: Colors.white54, fontSize: 12)),
                        Text("Max: $maxLot Lot", style: const TextStyle(color: Colors.white24, fontSize: 12)),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: (lots > maxLot ? maxLot : lots).toDouble(), // Safety check visual
                            min: 0,
                            max: maxLot > 0 ? maxLot.toDouble() : 1.0, // Hindari error division by zero
                            activeColor: const Color(0xFF00E676),
                            divisions: maxLot > 0 ? maxLot : 1,
                            onChanged: (v) => setState(() => lots = v.toInt()),
                          ),
                        ),
                        Container(
                          width: 60,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(8)),
                          child: Text("$lots", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        ),
                      ],
                    ),

                    const Divider(color: Colors.white10, height: 30),

                    // TOTAL ESTIMASI
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Total Estimasi:", style: TextStyle(color: Colors.white54)),
                        Text(NumberFormat.currency(locale:'id', symbol:'Rp ', decimalDigits:0).format(totalCost), 
                          style: TextStyle(
                            fontSize: 18, 
                            fontWeight: FontWeight.bold, 
                            color: isOverBudget ? Colors.red : Colors.white // Merah jika saldo kurang
                          )
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    
                    // BUTTON CONFIRM
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isOverBudget ? Colors.grey : const Color(0xFF00E676)
                        ),
                        onPressed: (lots == 0 || isOverBudget || currentPrice <= 0) ? null : () async {
                          Navigator.pop(ctx);
                          try {
                            await ref.read(apiProvider).addPortfolioPosition(
                              symbol: item['symbol'], 
                              price: currentPrice, // Kirim harga yg sudah diedit
                              lot: lots
                            );
                            if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Order Berhasil Dikirim!")));
                            // Auto refresh saldo
                            ref.invalidate(capitalProvider);
                          } catch (e) {
                            if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e")));
                          }
                        },
                        child: const Text("KONFIRMASI BELI", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              );
            }
          );
        }
      );
    });
  }
}