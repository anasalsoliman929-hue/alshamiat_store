import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/all_providers.dart';
import '../../shared/widgets/backup_restore_widget.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _rateCtrl;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _rateCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _rateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final rateAsync = ref.watch(currentExchangeRateProvider);

    if (settings.isLoaded && !_initialized) {
      _rateCtrl.text = settings.manualExchangeRate > 0
          ? settings.manualExchangeRate.toString()
          : '';
      _initialized = true;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: !settings.isLoaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [

                // ===== مظهر التطبيق =====
                _SectionTitle(title: 'مظهر التطبيق', icon: Icons.palette),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('اختر الثيم',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                            child: _ThemeOption(
                              label: 'النظام',
                              icon: Icons.brightness_auto,
                              value: 'system',
                              selected: settings.themeMode == 'system',
                              onTap: () => notifier.setThemeMode('system'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ThemeOption(
                              label: 'فاتح',
                              icon: Icons.light_mode,
                              value: 'light',
                              selected: settings.themeMode == 'light',
                              onTap: () => notifier.setThemeMode('light'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ThemeOption(
                              label: 'داكن',
                              icon: Icons.dark_mode,
                              value: 'dark',
                              selected: settings.themeMode == 'dark',
                              onTap: () => notifier.setThemeMode('dark'),
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ===== سعر الصرف =====
                _SectionTitle(title: 'سعر الصرف', icon: Icons.currency_exchange),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('السعر الحالي:'),
                      rateAsync.when(
                        data: (rate) => Text(
                          rate > 0 ? '${rate.toStringAsFixed(0)} ل.س' : 'غير متوفر',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        loading: () => const SizedBox(
                            height: 16, width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                        error: (_, __) => const Text('خطأ'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _rateCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'سعر الدولار بالليرة السورية',
                      hintText: 'مثال: 14500',
                      border: OutlineInputBorder(),
                      suffixText: 'ل.س'),
                  onChanged: (v) {
                    final rate = double.tryParse(v);
                    if (rate != null && rate > 0) {
                      notifier.setManualExchangeRate(rate);
                    }
                  },
                ),

                const SizedBox(height: 24),

                // ===== النسخ والاسترجاع =====
                const BackupRestoreWidget(),

                const SizedBox(height: 24),

                // ===== الجدولة التلقائية =====
                _SectionTitle(title: 'الجدولة التلقائية', icon: Icons.schedule),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('تفعيل نسخة احتياطية مؤرخة يومياً'),
                  subtitle: Text(settings.autoBackupEnabled
                      ? 'سيتم حفظ نسخة محلية مؤرخة يومياً في الساعة ${settings.autoBackupHour}:00'
                      : 'معطّل حالياً'),
                  value: settings.autoBackupEnabled,
                  onChanged: notifier.setAutoBackupEnabled,
                ),
                if (settings.autoBackupEnabled)
                  ListTile(
                    title: const Text('وقت النسخ الاحتياطي'),
                    trailing: Text('${settings.autoBackupHour}:00',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime:
                            TimeOfDay(hour: settings.autoBackupHour, minute: 0),
                      );
                      if (picked != null) notifier.setAutoBackupHour(picked.hour);
                    },
                  ),

                const SizedBox(height: 32),

                // ===== منطقة الخطر =====
                _SectionTitle(title: 'منطقة الخطر', icon: Icons.dangerous),
                const SizedBox(height: 8),
                Card(
                  color: Colors.red.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.red.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'تفريغ قاعدة البيانات يحذف كل المنتجات، الزبائن، الموردين، الفواتير، والدفعات نهائياً. هذا الإجراء لا يمكن التراجع عنه.',
                          style: TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.delete_forever, color: Colors.red),
                          label: const Text('تفريغ قاعدة البيانات',
                              style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => _confirmClearDatabase(context, ref),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
    );
  }

  void _confirmClearDatabase(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.warning, color: Colors.red),
          SizedBox(width: 8),
          Text('تأكيد التفريغ'),
        ]),
        content: const Text(
          'سيتم حذف جميع البيانات نهائياً:\n'
          '• كل المنتجات\n'
          '• كل الزبائن وفواتيرهم ودفعاتهم\n'
          '• كل الموردين وفواتيرهم ودفعاتهم\n\n'
          'يُنصح بأخذ نسخة احتياطية محلية مؤرخة أولاً.\n\n'
          'هل أنت متأكد تماماً؟',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => _showFinalConfirmation(context, ctx, ref),
            child: const Text('متابعة'),
          ),
        ],
      ),
    );
  }

  void _showFinalConfirmation(
      BuildContext context, BuildContext firstDialogCtx, WidgetRef ref) {
    Navigator.pop(firstDialogCtx);
    final confirmCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('التأكيد النهائي'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('اكتب كلمة "تأكيد" للمتابعة:'),
            const SizedBox(height: 12),
            TextField(
              controller: confirmCtrl,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'تأكيد',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (confirmCtrl.text.trim() != 'تأكيد') {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('يرجى كتابة "تأكيد" بشكل صحيح'),
                  backgroundColor: Colors.orange,
                ));
                return;
              }
              await ref.read(clearDatabaseProvider)();
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('✅ تم تفريغ قاعدة البيانات بالكامل'),
                  backgroundColor: Colors.green,
                ));
              }
            },
            child: const Text('حذف نهائياً'),
          ),
        ],
      ),
    );
  }
}

// ===== Theme Option Widget =====
class _ThemeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : Colors.transparent,
          border: Border.all(
            color: selected ? color : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: selected ? color : Colors.grey, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? color : Colors.grey,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
      const SizedBox(width: 8),
      Text(title,
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary)),
    ]);
  }
}
