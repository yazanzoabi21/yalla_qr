import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeOption { system, light, dark }

class ThemeService {
  ThemeService._privateConstructor();

  static final ThemeService instance = ThemeService._privateConstructor();

  static const _prefsKey = 'app_theme_mode';

  final ValueNotifier<ThemeMode> modeNotifier = ValueNotifier(ThemeMode.system);

  AppThemeOption _currentOption = AppThemeOption.system;

  AppThemeOption get currentOption => _currentOption;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    switch (stored) {
      case 'light':
        _currentOption = AppThemeOption.light;
        modeNotifier.value = ThemeMode.light;
        break;
      case 'dark':
        _currentOption = AppThemeOption.dark;
        modeNotifier.value = ThemeMode.dark;
        break;
      default:
        _currentOption = AppThemeOption.system;
        modeNotifier.value = ThemeMode.system;
    }
  }

  Future<void> setTheme(AppThemeOption option) async {
    _currentOption = option;
    final prefs = await SharedPreferences.getInstance();
    switch (option) {
      case AppThemeOption.light:
        await prefs.setString(_prefsKey, 'light');
        modeNotifier.value = ThemeMode.light;
        break;
      case AppThemeOption.dark:
        await prefs.setString(_prefsKey, 'dark');
        modeNotifier.value = ThemeMode.dark;
        break;
      case AppThemeOption.system:
        await prefs.remove(_prefsKey);
        modeNotifier.value = ThemeMode.system;
        break;
    }
  }

  ThemeMode get themeMode => modeNotifier.value;
}
