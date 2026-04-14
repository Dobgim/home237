import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

class ThemeNotifier extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  // Separate dark mode settings for each role
  bool? _tenantDarkMode;
  bool? _landlordDarkMode;

  static const String _tenantThemeKey = 'tenant_dark_mode';
  static const String _landlordThemeKey = 'landlord_dark_mode';

  ThemeNotifier() {
    _loadThemeFromPrefs();
  }

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  // Get dark mode status for current user role
  bool? get isDarkModeForCurrentRole {
    final role = authService.userRole;
    if (role == UserRole.tenant) {
      return _tenantDarkMode;
    } else if (role == UserRole.landlord) {
      return _landlordDarkMode;
    }
    return null; // System theme
  }

  // Load all theme preferences from storage
  Future<void> _loadThemeFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(_tenantThemeKey)) {
        _tenantDarkMode = prefs.getBool(_tenantThemeKey);
      }
      if (prefs.containsKey(_landlordThemeKey)) {
        _landlordDarkMode = prefs.getBool(_landlordThemeKey);
      }

      // Set global theme based on current role
      _updateThemeForCurrentRole();
      notifyListeners();
    } catch (e) {
      print('Error loading theme preference: $e');
    }
  }

  // Update global theme based on current user's role
  void _updateThemeForCurrentRole() {
    final isDark = isDarkModeForCurrentRole;
    if (isDark == null) {
      _themeMode = ThemeMode.system;
    } else {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    }
  }

  // Toggle theme for current user role only
  Future<void> toggleTheme(bool isDark) async {
    final role = authService.userRole;

    // Update the specific role's dark mode setting
    if (role == UserRole.tenant) {
      _tenantDarkMode = isDark;
    } else if (role == UserRole.landlord) {
      _landlordDarkMode = isDark;
    }

    // Update global theme
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();

    // Save to storage
    try {
      final prefs = await SharedPreferences.getInstance();
      if (role == UserRole.tenant) {
        await prefs.setBool(_tenantThemeKey, isDark);
      } else if (role == UserRole.landlord) {
        await prefs.setBool(_landlordThemeKey, isDark);
      }
    } catch (e) {
      print('Error saving theme preference: $e');
    }
  }

  // Call this when user role changes (e.g., after login or role selection)
  void updateThemeForRole() {
    _updateThemeForCurrentRole();
    notifyListeners();
  }
}