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
      appBar: AppBar(title: const Text("HISTORY TRANSAKSI")),
      body: ref.watch(historyProvider).when(
        data: (list) {
          if (list.isEmpty) return const Center(child: Text("Belum ada data penjualan.", style: TextStyle(color: Colors.grey)));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (ctx, i) {
              final item = list[i];
              // Hitung Profit Bersih (Harga Jual Net - Harga Beli Net)
              // Backend biasanya sudah menyimpan data cost awal. 
              // Sell price di backend sudah dipotong fee? Kita asumsikan backend mengirim data mentah atau kita hitung selisih cost vs revenue.
              
              final shares = item['shares'] as int;
              final sellPrice = (item['sell_price'] as num).toDouble();
              final cost = (item['cost'] as num).toDouble();
              
              // Revenue Bersih = (Shares * SellPrice) * (1 - 0.25% fee)
              final revenue = (shares * sellPrice) * (1 - 0.0025);
              final profit = revenue - cost;
              final isProfit = profit >= 0;

              return Card(
                color: const Color(0xFF1E1E1E),
                child: ListTile(
                  leading: Icon(
                    isProfit ? PhosphorIcons.trendUp : PhosphorIcons.trendDown,
                    color: isProfit ? const Color(0xFF00E676) : Colors.red,
                    size: 32,
                  ),
                  title: Text(item['symbol'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Sold Date: ${item['sell_date']}"),
                      Text("Sell Price: ${fmt.format(sellPrice)}"),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "${isProfit ? '+' : ''}${fmt.format(profit)}",
                        style: TextStyle(
                          color: isProfit ? const Color(0xFF00E676) : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 16
                        ),
                      ),
                      Text(isProfit ? "PROFIT" : "LOSS", style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
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
}