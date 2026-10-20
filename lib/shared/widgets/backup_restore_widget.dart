import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/all_providers.dart';

class BackupRestoreWidget extends ConsumerWidget {
  final bool showTitle;
  const BackupRestoreWidget({super.key, this.showTitle = true});

  void _handleResult(BuildContext context, WidgetRef ref, BackupState state) {
    if (state.status == BackupStatus.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(state.successMessage ?? '✅ تمت العملية بنجاح'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
      ));
      if (state.successMessage?.contains('أعد تشغيل') ?? false) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('تم الاسترجاع بنجاح'),
            content: const Text('يجب إعادة تشغيل التطبيق لتطبيق التغييرات.'),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('موافق'),
              ),
            ],
          ),
        );
      }
    } else if (state.status == BackupStatus.error) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(state.errorMessage ?? '❌ حدث خطأ'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ));
    }
    ref.read(backupProvider.notifier).reset();
  }

  void _confirmRestore(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.warning, color: Colors.orange),
          SizedBox(width: 8),
          Text('تأكيد الاسترجاع'),
        ]),
        content: const Text(
          'سيتم استبدال جميع البيانات الحالية.\n\n'
          'سيتم حفظ نسخة طارئة تلقائياً قبل الاستبدال.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(backupProvider.notifier).restoreBackup();
              if (context.mounted) {
                _handleResult(context, ref, ref.read(backupProvider));
              }
            },
            child: const Text('نعم، استرجع'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backupState = ref.watch(backupProvider);
    final folderPathAsync = ref.watch(backupFolderPathProvider);
    final isLoading = backupState.status == BackupStatus.loading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTitle) ...[
          const Row(children: [
            Icon(Icons.backup, color: Colors.teal),
            SizedBox(width: 8),
            Text('النسخ الاحتياطي والاسترجاع',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal)),
          ]),
          const SizedBox(height: 12),
        ],

        // ===== الحفظ المحلي التلقائي =====
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.save, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                const Text('الحفظ المحلي التلقائي',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.green)),
              ]),
              const SizedBox(height: 6),
              const Text(
                'تُحفظ نسخة تلقائياً بعد أي إضافة أو تعديل في مجلد '
                'Download/AlshamiatStore، وتبقى حتى لو حُذف التطبيق.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 6),
              folderPathAsync.when(
                data: (path) => Text('المسار: $path',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.grey, fontFamily: 'monospace')),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.save_alt, color: Colors.green, size: 18),
                label: const Text('حفظ نسخة مؤرخة الآن',
                    style: TextStyle(color: Colors.green, fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.green),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onPressed: isLoading
                    ? null
                    : () async {
                        await ref
                            .read(backupProvider.notifier)
                            .saveTimestampedLocalBackup();
                        if (context.mounted) {
                          _handleResult(context, ref, ref.read(backupProvider));
                        }
                      },
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        OutlinedButton.icon(
          icon: isLoading
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.restore, color: Colors.orange),
          label: const Text('استرجاع نسخة احتياطية',
              style: TextStyle(color: Colors.orange)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.orange),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: isLoading ? null : () => _confirmRestore(context, ref),
        ),
        const SizedBox(height: 4),
        const Text(
          '* اختر ملف .sqlite من مجلد Download/AlshamiatStore أو أي مكان آخر',
          style: TextStyle(fontSize: 11, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
