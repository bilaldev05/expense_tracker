// lib/utils/shared_prefs_helper.dart
import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsHelper {
  static const String _keyFamilyId = 'family_id';
  static const String _keyUserId = 'user_id';

  static Future<void> saveFamilyId(String familyId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFamilyId, familyId);
  }

  static Future<String?> getFamilyId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyFamilyId);
  }

  static Future<void> clearFamilyId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyFamilyId);
  }

  static Future<void> saveUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserId, userId);
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
