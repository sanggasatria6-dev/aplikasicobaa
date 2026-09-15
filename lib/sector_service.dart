import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class SectorService {
  static final SectorService _instance = SectorService._internal();
  factory SectorService() => _instance;
  SectorService._internal() {
    _refreshFromBackend();
  }

  static final List<Map<String, dynamic>> _defaultSectors = [
    {"id": 0, "name": "Finance (Perbankan)"},
    {"id": 1, "name": "Energy (Minyak, Gas, Coal)"},
    {"id": 2, "name": "Mining (Emas, Nikel, Mineral)"},
    {"id": 3, "name": "Consumer & Retail"},
    {"id": 4, "name": "Infra, Telco & Others"},
  ];

  List<Map<String, dynamic>> _cachedSectors = List.from(_defaultSectors);
  final StreamController<List<Map<String, dynamic>>> _controller =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: "https://api.satriasangga.my.id",
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));

  // 1. Ambil Data Realtime (Stream)
  Stream<List<Map<String, dynamic>>> getUserSectors(String username) async* {
    yield List.unmodifiable(_cachedSectors);
    _refreshFromBackend();
    yield* _controller.stream;
  }

  Future<void> _refreshFromBackend() async {
    try {
      final res = await _dio.get('/api/sectors');
      if (res.statusCode == 200 && res.data != null && res.data['data'] != null) {
        final raw = res.data['data'] as List;
        if (raw.isNotEmpty) {
          _cachedSectors = raw.map((e) => {
            'id': e['id'] as int,
            'name': e['name'].toString(),
          }).toList();
          _cachedSectors.sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
          if (!_controller.isClosed) {
            _controller.add(List.unmodifiable(_cachedSectors));
          }
        }
      }
    } catch (e) {
      debugPrint("[SectorService] Backend fetch fallback to cached: $e");
      if (!_controller.isClosed) {
        _controller.add(List.unmodifiable(_cachedSectors));
      }
    }
  }

  // 2. Tambah / Edit Sektor
  Future<void> addOrUpdateSector(String username, int id, String name) async {
    _cachedSectors.removeWhere((s) => s['id'] == id);
    _cachedSectors.add({'id': id, 'name': name});
    _cachedSectors.sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
    if (!_controller.isClosed) {
      _controller.add(List.unmodifiable(_cachedSectors));
    }

    try {
      await _dio.post('/api/sectors', data: {'id': id, 'name': name});
    } catch (e) {
      debugPrint("[SectorService] Failed saving sector to backend: $e");
    }
  }

  // 3. Hapus Sektor
  Future<void> deleteSector(String username, int id) async {
    _cachedSectors.removeWhere((s) => s['id'] == id);
    if (!_controller.isClosed) {
      _controller.add(List.unmodifiable(_cachedSectors));
    }

    try {
      await _dio.delete('/api/sectors/$id');
    } catch (e) {
      debugPrint("[SectorService] Failed deleting sector from backend: $e");
    }
  }

  // 4. Inisialisasi Data Sektor Default
  Future<void> initDefaultSectors(String username) async {
    if (_cachedSectors.isEmpty) {
      _cachedSectors = List.from(_defaultSectors);
      if (!_controller.isClosed) {
        _controller.add(List.unmodifiable(_cachedSectors));
      }
    }
    await _refreshFromBackend();
  }
}