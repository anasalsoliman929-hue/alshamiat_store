import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class LocalBackupService {
  // اسم الملف الثابت الذي يُستبدل في كل مرة (آخر نسخة دائماً)
  static const String _latestBackupName = 'alshamiat_store_latest_backup.sqlite';

  /// طلب صلاحية الوصول للتخزين (مطلوبة على أندرويد القديم فقط،
  /// على أندرويد 11+ نستخدم مجلد التطبيق الخاص في التخزين العام
  /// الذي لا يحتاج صلاحية خاصة)
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.status;
      if (status.isGranted) return true;
      final result = await Permission.storage.request();
      return result.isGranted;
    }
    return true; // iOS لا يحتاج هذا النوع من الصلاحيات لمجلد التطبيق
  }

  /// المجلد العام الذي يبقى حتى بعد حذف التطبيق
  /// على أندرويد: /storage/emulated/0/Android/data/.../files أو
  /// الأفضل: مجلد عام بالكامل مثل Downloads
  Future<Directory> _getPublicBackupDirectory() async {
    if (Platform.isAndroid) {
      // مجلد التنزيلات العام - يبقى حتى بعد حذف التطبيق
      final downloadsDir = Directory('/storage/emulated/0/Download/AlshamiatStore');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      return downloadsDir;
    } else {
      // iOS: مجلد المستندات القابل للمشاركة عبر Files app
      final dir = await getApplicationDocumentsDirectory();
      final backupDir = Directory(p.join(dir.path, 'Backups'));
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }
      return backupDir;
    }
  }

  /// حفظ نسخة فورية بعد أي تعديل (تستبدل الملف السابق دائماً)
  /// يستخدم كتابة ذرية: ينسخ لملف مؤقت أولاً ثم يستبدل الملف
  /// النهائي دفعة واحدة، لتفادي وجود نسخة تالفة عند مقاطعة العملية
  Future<void> saveLatestSnapshot() async {
    try {
      final dbFolder = await getApplicationDocumentsDirectory();
      final dbFile = File(p.join(dbFolder.path, 'store_db.sqlite'));
      if (!await dbFile.exists()) return;

      final publicDir = await _getPublicBackupDirectory();
      final finalFile = File(p.join(publicDir.path, _latestBackupName));
      final tempFile = File(p.join(publicDir.path, '$_latestBackupName.tmp'));

      // النسخ إلى ملف مؤقت أولاً
      await dbFile.copy(tempFile.path);

      // الاستبدال الذري: rename هو عملية واحدة لا يمكن مقاطعتها جزئياً
      // على معظم أنظمة الملفات (على عكس copy التي تكتب بايت ببايت)
      if (await tempFile.exists()) {
        await tempFile.rename(finalFile.path);
      }
    } catch (e) {
      // لا نريد أن يوقف فشل الحفظ المحلي أي عملية بالتطبيق
    }
  }

  /// حفظ نسخة مؤرخة منفصلة (يدوي أو مجدول يومياً) — يحتفظ فقط بآخر
  /// [keepCount] نسخ ويحذف الأقدم تلقائياً لتفادي امتلاء التخزين.
  Future<File> saveTimestampedSnapshot({int keepCount = 5}) async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final dbFile = File(p.join(dbFolder.path, 'store_db.sqlite'));
    if (!await dbFile.exists()) {
      throw Exception('ملف قاعدة البيانات غير موجود.');
    }

    final publicDir = await _getPublicBackupDirectory();
    final dateStr = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
    final timestampedFile =
        File(p.join(publicDir.path, 'backup_$dateStr.sqlite'));

    await dbFile.copy(timestampedFile.path);
    await _enforceRetentionLimit(publicDir, keepCount);
    return timestampedFile;
  }

  /// يحذف أقدم النسخ المؤرخة (backup_*.sqlite) مبقياً على آخر
  /// [keepCount] نسخ فقط، بحسب تاريخ التعديل.
  Future<void> _enforceRetentionLimit(Directory dir, int keepCount) async {
    try {
      final files = await dir
          .list()
          .where((e) =>
              e is File &&
              p.basename(e.path).startsWith('backup_') &&
              p.basename(e.path).endsWith('.sqlite'))
          .cast<File>()
          .toList();

      if (files.length <= keepCount) return;

      files.sort((a, b) =>
          b.statSync().modified.compareTo(a.statSync().modified));

      for (final old in files.skip(keepCount)) {
        try {
          await old.delete();
        } catch (_) {
          // تجاهل فشل حذف ملف واحد ولا نوقف البقية
        }
      }
    } catch (_) {
      // لا نريد أن يوقف فشل التنظيف أي عملية نسخ احتياطي
    }
  }

  /// التحقق من وجود نسخة محفوظة محلياً (للاسترجاع التلقائي عند إعادة التثبيت)
  Future<File?> getLatestLocalBackup() async {
    try {
      final publicDir = await _getPublicBackupDirectory();
      final file = File(p.join(publicDir.path, _latestBackupName));
      if (await file.exists()) return file;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// مسار المجلد (لعرضه للمستخدم في الواجهة)
  Future<String> getBackupFolderPath() async {
    final dir = await _getPublicBackupDirectory();
    return dir.path;
  }
}
