import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  ThemeMode _themeMode;
  Locale _locale = const Locale('en');

  AppProvider(this._prefs)
    : _themeMode = _prefs.getBool('isDark') == true
          ? ThemeMode.dark
          : ThemeMode.light,
      _isDetailed = _prefs.getBool('isDetailed') ?? false;

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;

  bool _isDetailed;
  bool get isDetailed => _isDetailed;

  void toggleTheme(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    _prefs.setBool('isDark', isDark);
    notifyListeners();
  }

  void setDetailedMode(bool isDetailed) {
    _isDetailed = isDetailed;
    _prefs.setBool('isDetailed', isDetailed);
    notifyListeners();
  }

  void setLocale(Locale locale) {
    _locale = locale;
    notifyListeners();
  }
}
