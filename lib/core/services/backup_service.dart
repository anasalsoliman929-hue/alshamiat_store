import 'dart:io';
import 'package:alshamiat_store/data/database/app_database.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// خدمة استرجاع قاعدة البيانات من ملف نسخة احتياطية محلي.
/// الحفظ نفسه (التلقائي والمؤرخ) تتولاه LocalBackupService.
class BackupService {
  String get _dbFileName => 'store_db.sqlite';

  Future<File?> pickBackupFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      dialogTitle: 'اختر ملف النسخة الاحتياطية (.sqlite)',
    );
    if (result == null || result.files.isEmpty) return null;
    final path = result.files.single.path;
    if (path == null) return null;
    final file = File(path);
    if (!await _isSQLiteFile(file)) {
      throw Exception('الملف ليس قاعدة بيانات SQLite صالحة.');
    }
    return file;
  }

  Future<bool> _isSQLiteFile(File file) async {
    try {
      final bytes = await file.openRead(0, 16).first;
      const sqliteHeader = [83,81,76,105,116,101,32,102,111,114,109,97,116,32,51,0];
      if (bytes.length < 16) return false;
      for (int i = 0; i < 16; i++) {
        if (bytes[i] != sqliteHeader[i]) return false;
      }
      return true;
    } catch (_) { return false; }
  }

  Future<void> restoreDatabase({
    required AppDatabase db,
    required File backupFile,
  }) async {
    await db.close();
    try {
      final dbFolder = await getApplicationDocumentsDirectory();
      final dbPath = p.join(dbFolder.path, _dbFileName);
      final currentDbFile = File(dbPath);
      if (await currentDbFile.exists()) {
        final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final emergency = File(p.join(dbFolder.path, 'store_db_emergency_$dateStr.sqlite'));
        await currentDbFile.copy(emergency.path);
      }
      await backupFile.copy(dbPath);
    } catch (e) {
      throw Exception('فشل الاسترجاع: $e');
    }
  }
}
