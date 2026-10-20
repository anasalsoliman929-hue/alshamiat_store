import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _keyManualExchangeRate = 'manual_exchange_rate';
  static const _keyAutoBackupEnabled = 'auto_backup_enabled';
  static const _keyAutoBackupHour = 'auto_backup_hour';
  static const _keyThemeMode = 'theme_mode'; // 'system' | 'light' | 'dark'

  Future<void> setManualExchangeRate(double v) async =>
      (await SharedPreferences.getInstance()).setDouble(_keyManualExchangeRate, v);
  Future<double?> getManualExchangeRate() async =>
      (await SharedPreferences.getInstance()).getDouble(_keyManualExchangeRate);

  Future<void> setAutoBackupEnabled(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(_keyAutoBackupEnabled, v);
  Future<bool> getAutoBackupEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_keyAutoBackupEnabled) ?? false;

  Future<void> setAutoBackupHour(int v) async =>
      (await SharedPreferences.getInstance()).setInt(_keyAutoBackupHour, v);
  Future<int> getAutoBackupHour() async =>
      (await SharedPreferences.getInstance()).getInt(_keyAutoBackupHour) ?? 21;

  Future<void> setThemeMode(String v) async =>
      (await SharedPreferences.getInstance()).setString(_keyThemeMode, v);
  Future<String> getThemeMode() async =>
      (await SharedPreferences.getInstance()).getString(_keyThemeMode) ?? 'system';
}
