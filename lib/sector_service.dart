import 'package:cloud_firestore/cloud_firestore.dart';

class SectorService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. Ambil Data Realtime (Stream)
  Stream<List<Map<String, dynamic>>> getUserSectors(String username) {
    return _db
        .collection('user_preferences')
        .doc(username)
        .collection('sectors')
        .orderBy('id')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  // 2. Tambah / Edit Sektor
  Future<void> addOrUpdateSector(String username, int id, String name) async {
    await _db
        .collection('user_preferences')
        .doc(username)
        .collection('sectors')
        .doc(id.toString()) // ID jadi nama dokumen
        .set({
      'id': id,
      'name': name,
    });
  }

  // 3. Hapus Sektor
  Future<void> deleteSector(String username, int id) async {
    await _db
        .collection('user_preferences')
        .doc(username)
        .collection('sectors')
        .doc(id.toString())
        .delete();
  }
  
  // 4. Buat Default Data (Kalau user baru)
  Future<void> initDefaultSectors(String username) async {
    final doc = await _db.collection('user_preferences').doc(username).collection('sectors').get();
    if (doc.docs.isEmpty) {
      await addOrUpdateSector(username, 0, "Finance (Perbankan)");
      await addOrUpdateSector(username, 1, "Energy (Minyak, Gas, Coal)");
      await addOrUpdateSector(username, 2, "Mining (Emas, Nikel, Mineral)");
      await addOrUpdateSector(username, 3, "Consumer & Retail");
      await addOrUpdateSector(username, 4, "Infra, Telco & Others");
    }
  }
}