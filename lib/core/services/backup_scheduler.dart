import 'package:workmanager/workmanager.dart';
import 'local_backup_service.dart';

const String dailySnapshotTaskName = 'dailyLocalSnapshotTask';
const String dailySnapshotTaskTag = 'daily_local_snapshot';

const String localSnapshotTaskName = 'localSnapshotTask';
const String localSnapshotTaskTag = 'local_snapshot';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == dailySnapshotTaskName) {
      // نسخة احتياطية محلية مؤرخة، مجدولة يومياً (بلا تلغرام)
      try {
        await LocalBackupService().saveTimestampedSnapshot();
        return Future.value(true);
      } catch (_) { return Future.value(false); }
    }

    if (task == localSnapshotTaskName) {
      // مهمة شبكة أمان: تُنفَّذ في عملية خلفية مستقلة عن التطبيق،
      // حتى لو كان التطبيق قد أُغلق بالكامل (force-close) قبل أن
      // يكمل الحفظ الفوري داخل العملية الأساسية
      try {
        await LocalBackupService().saveLatestSnapshot();
        return Future.value(true);
      } catch (_) { return Future.value(false); }
    }

    return Future.value(true);
  });
}

class BackupScheduler {
  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  }

  static Future<void> scheduleDailyLocalSnapshot(int hour) async {
    await Workmanager().cancelByTag(dailySnapshotTaskTag);
    final now = DateTime.now();
    var scheduledTime = DateTime(now.year, now.month, now.day, hour);
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }
    await Workmanager().registerPeriodicTask(
      dailySnapshotTaskName, dailySnapshotTaskName,
      frequency: const Duration(hours: 24),
      initialDelay: scheduledTime.difference(now),
      tag: dailySnapshotTaskTag,
    );
  }

  static Future<void> cancelDailyLocalSnapshot() async {
    await Workmanager().cancelByTag(dailySnapshotTaskTag);
  }

  /// جدولة "شبكة أمان": مهمة فورية (one-off) تُنفَّذ خلال ثوانٍ قليلة
  /// من جدولتها، حتى لو أُغلق التطبيق تماماً بعدها مباشرة.
  /// تُستدعى بعد كل تعديل كطبقة حماية إضافية فوق الحفظ داخل العملية.
  static Future<void> scheduleImmediateLocalSnapshot() async {
    await Workmanager().registerOneOffTask(
      '$localSnapshotTaskName-${DateTime.now().millisecondsSinceEpoch}',
      localSnapshotTaskName,
      initialDelay: Duration.zero,
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }
}
