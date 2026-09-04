import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

// URL Cloudflare Production AI Trader
final baseUrlProvider = StateProvider<String>((ref) => "https://api.satriasangga.my.id");

final dioProvider = Provider((ref) {
  final url = ref.watch(baseUrlProvider);
  final authState = ref.watch(authProvider); // <--- PANTAU STATE LOGIN

  final dio = Dio(BaseOptions(
    baseUrl: url,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'Content-Type': 'application/json',
      // SISIPKAN TOKEN OTOMATIS (Support Header x-secret-token & Authorization Bearer)
      if (authState.token != null) ...{
        'x-secret-token': authState.token,
        'Authorization': 'Bearer ${authState.token}',
      },
    },
  ));

  // [BARU] PENGAMAN: Jika Token Salah/Expired (401), Logout Otomatis
  dio.interceptors.add(InterceptorsWrapper(
    onError: (DioException e, handler) async {
      if (e.response?.statusCode == 401) {
        await ref.read(authProvider.notifier).logout();
      }
      return handler.next(e);
    },
  ));

  return dio;
});


final apiProvider = Provider((ref) => ApiService(ref.watch(dioProvider)));

class ApiService {
  final Dio _dio;
  ApiService(this._dio);

  // --- KEUANGAN & PORTOFOLIO ---

  // [BARU] FUNGSI LOGIN PASSWORD
  Future<Map<String, dynamic>> loginUser(String username, String password) async {
    try {
      // Kita kirim username & password ke Backend Python
      final res = await _dio.post('/api/auth/login', data: {
        "username": username,
        "password": password
      });
      // Backend akan membalas: { "success": true, "token": "...", ... }
      return res.data; 
    } on DioException catch (e) {
      throw e.response?.data['detail'] ?? "Gagal Login (Cek Username/Password)";
    }
  }

  Future<Map<String, dynamic>> getCapital() async {
    final res = await _dio.get('/api/capital');
    return res.data['data'];
  }

  Future<List<dynamic>> getPortfolio() async {
    final res = await _dio.get('/api/portfolio/active');
    return res.data['data'];
  }

  // BARU: Ambil History Penjualan
  Future<List<dynamic>> getSoldPortfolio() async {
    try {
      final res = await _dio.get('/api/portfolio/sold');
      return res.data['data'];
    } catch (e) {
      return [];
    }
  }

  Future<void> adjustCapital(double amount, String desc) async {
    await _dio.post('/api/capital/adjust', data: {
      "amount": amount,
      "description": desc
    });
  }

  // --- TRANSAKSI ---

  Future<void> addPortfolioPosition({
    required String symbol,
    required double price,
    required int lot,
  }) async {
    final shares = lot * 100;
    final cost = (shares * price) * 1.0015; // Fee Beli

    try {
      await _dio.post('/api/portfolio/add', data: {
        "symbol": symbol.toUpperCase(),
        "avg_price": price,
        "lot": lot,
        "shares": shares,
        "buy_date": DateTime.now().toIso8601String().split('T')[0],
        "buy_price": price,
        "cost": cost,
        "target_price": 0, "stop_loss": 0,
        "target_peak_initial": 0, "target_floor_initial": 0, "predicted_days_initial": 0
      });
    } on DioException catch (e) {
      throw e.response?.data['detail'] ?? "Gagal beli saham";
    }
  }

  Future<void> sellPortfolioPosition(int id, double price) async {
    await _dio.put('/api/portfolio/$id/sell', data: {
      "sell_price": price,
      "sell_date": DateTime.now().toIso8601String().split('T')[0],
    });
  }

  // --- MARKET & CONTROL ---

  Future<List<dynamic>> getAnalysis() async {
    final res = await _dio.get('/api/analysis/latest');
    return res.data['data'];
  }
  
  Future<void> triggerUpdate() async => await _dio.post('/api/data/update');
  Future<void> triggerTraining() async => await _dio.post('/api/training/run', data: {"force_retrain": true});
  
  // BARU: Ambil Log Training Lama
  Future<List<dynamic>> getTrainingLogs() async {
    final res = await _dio.get('/api/training/logs?limit=10');
    return res.data['data'];
  }

  // BARU: Restore Model Lama
  Future<void> activateModel(int logId) async {
    await _dio.post('/api/models/activate/$logId');
  }
  
  Future<Map<String, dynamic>> getStockConfig() async {
    final res = await _dio.get('/api/config/stocks');
    return res.data['data'];
  }
  
  Future<void> addStockConfig(String symbol, int sectorId) async {
    await _dio.post('/api/config/stocks', data: {"symbol": symbol, "sector_id": sectorId});
  }
  
  Future<void> removeStockConfig(String symbol) async {
    await _dio.delete('/api/config/stocks/$symbol');
  }

  // --- FITUR BARU V2.1 (Async & Manual Scan) ---

  // 1. Cek Status Server (Polling Progress Bar)
  Future<Map<String, dynamic>> getSystemStatus() async {
    try {
      final res = await _dio.get('/api/system/status');
      return res.data['data'];
    } catch (e) {
      // Return default idle jika gagal konek
      return {"is_running": false, "progress": 0, "message": "Offline"};
    }
  }

  // 2. Trigger Backtest Only (Tanpa Training)
  Future<void> triggerBacktestOnly() async => await _dio.post('/api/backtest/run');

  // 3. Trigger Manual Market Scan (Analisa Saat Ini Juga)
  Future<void> triggerMarketScan() async => await _dio.post('/api/analysis/run');

  Future<void> deleteTrainingLog(int logId) async {
    await _dio.delete('/api/training/logs/$logId');
  }

  Future<List<dynamic>> getBacktestTrades(int backtestId) async {
    try {
      final res = await _dio.get('/api/backtest/$backtestId/trades');
      return res.data['data'] ?? [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> getPerformanceSummary() async {
    try {
      final res = await _dio.get('/api/performance/summary');
      return res.data['data'] ?? {};
    } catch (e) {
      return {};
    }
  }

  Future<List<dynamic>> getBacktestResults() async {
    try {
      final res = await _dio.get('/api/backtest/results');
      return res.data['data'] ?? [];
    } catch (e) {
      return [];
    }
  }

  // --- NOTIFIKASI ONLINE & TELEGRAM ---

  Future<Map<String, dynamic>> getNotifications({int limit = 50, bool unreadOnly = false}) async {
    try {
      final res = await _dio.get('/api/notifications', queryParameters: {
        'limit': limit,
        'unread_only': unreadOnly,
      });
      return res.data ?? {'unread_count': 0, 'data': []};
    } catch (e) {
      return {'unread_count': 0, 'data': []};
    }
  }

  Future<bool> markNotificationRead(int notifId) async {
    try {
      final res = await _dio.post('/api/notifications/$notifId/read');
      return res.data['success'] ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> markAllNotificationsRead() async {
    try {
      final res = await _dio.post('/api/notifications/read-all');
      return res.data['success'] ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteNotification(int notifId) async {
    try {
      final res = await _dio.delete('/api/notifications/$notifId');
      return res.data['success'] ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteAllNotifications() async {
    try {
      final res = await _dio.delete('/api/notifications/clear-all');
      return res.data['success'] ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> sendTestNotification() async {
    try {
      final res = await _dio.post('/api/notifications/test');
      return res.data['success'] ?? false;
    } catch (e) {
      return false;
    }
  }

  // --- 🤖 COPILOT AI CHAT ---
  Future<String> sendCopilotMessage(String message, {List<Map<String, String>>? history}) async {
    try {
      final res = await _dio.post(
        '/api/copilot/chat',
        data: {
          "message": message,
          "history": history ?? [],
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 45),
          sendTimeout: const Duration(seconds: 20),
        ),
      );
      if (res.data != null && res.data['reply'] != null) {
        return res.data['reply'].toString();
      }
      return "Maaf, tidak ada respon dari Copilot.";
    } on DioException catch (e) {
      if (e.type == DioExceptionType.receiveTimeout || e.type == DioExceptionType.connectionTimeout) {
        return "⏱️ Analisis Copilot memerlukan waktu pemrosesan lebih. Mohon tunggu sejenak atau tanyakan kembali.";
      }
      final detail = e.response?.data?['detail'] ?? e.message ?? "Gagal terhubung ke Copilot";
      throw detail;
    } catch (e) {
      throw "Terjadi kesalahan: $e";
    }
  }
}

// Providers for Notifications
final notificationsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiProvider);
  return api.getNotifications();
});

final systemStatusProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiProvider);
  return api.getSystemStatus();
});