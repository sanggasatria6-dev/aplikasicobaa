import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'api_service.dart';

final historyProvider = FutureProvider.autoDispose((ref) => ref.watch(apiProvider).getSoldPortfolio());

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("History Transaksi"),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIcons.arrowsClockwise, color: Color(0xFF0F172A)),
            tooltip: "Refresh History",
            onPressed: () => ref.refresh(historyProvider),
          ),
        ],
      ),
      body: ref.watch(historyProvider).when(
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(PhosphorIcons.clockCounterClockwise, size: 48, color: Color(0xFF94A3B8)),
                    SizedBox(height: 12),
                    Text(
                      "Belum Ada Riwayat Transaksi",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    SizedBox(height: 6),
                    Text(
                      "Penjualan saham portofolio akan tercatat secara otomatis di sini.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (ctx, i) {
              final item = list[i];
              final shares = (item['shares'] as num?)?.toInt() ?? ((item['lot'] as num?)?.toInt() ?? 1) * 100;
              final sellPrice = (item['sell_price'] as num?)?.toDouble() ?? 0.0;
              final cost = (item['cost'] as num?)?.toDouble() ?? 0.0;

              // Revenue Bersih = (Shares * SellPrice) * (1 - 0.25% fee)
              final revenue = (shares * sellPrice) * (1 - 0.0025);
              final profit = revenue - cost;
              final isProfit = profit >= 0;

              final sellDate = (item['sell_date'] ?? item['created_at'] ?? '').toString().split(' ')[0];

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
                child: Row(
                  children: [
                    // Icon Status Pill
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isProfit ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isProfit ? PhosphorIcons.trendUpBold : PhosphorIcons.trendDownBold,
                        color: isProfit ? const Color(0xFF059669) : const Color(0xFFDC2626),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Detail Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                item['symbol'] ?? '-',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isProfit ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isProfit ? "+PROFIT" : "-LOSS",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: isProfit ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "$sellDate • $shares Lbr @ ${fmt.format(sellPrice)}",
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                          ),
                        ],
                      ),
                    ),

                    // Profit Amount
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "${isProfit ? '+' : ''}${fmt.format(profit)}",
                          style: TextStyle(
                            color: isProfit ? const Color(0xFF059669) : const Color(0xFFDC2626),
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Modal: ${fmt.format(cost)}",
                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF059669)),
        ),
        error: (e, _) => Center(
          child: Text("Error: $e", style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  }
}