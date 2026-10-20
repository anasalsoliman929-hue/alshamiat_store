import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/services/backup_scheduler.dart';
import 'core/services/local_backup_service.dart';
import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';
import 'providers/all_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BackupScheduler.initialize();
  // طلب صلاحية التخزين مبكراً لتفعيل الحفظ المحلي التلقائي
  await LocalBackupService().requestPermission();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return MaterialApp(
      title: 'متجر الشاميات',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ar')],
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.flutterThemeMode,
      home: const HomeScreen(),
    );
  }
}
