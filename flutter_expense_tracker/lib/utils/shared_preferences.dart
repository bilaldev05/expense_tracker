import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsHelper {
  // 🔹 Save user ID
  static Future<void> saveUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', userId);
  }

  // 🔹 Get user ID
  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId');
  }

  // 🔹 Save family ID
  static Future<void> saveFamilyId(String familyId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('familyId', familyId);
  }

  // 🔹 Get family ID
  static Future<String?> getFamilyId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('familyId');
  }

  // 🔹 Clear all data on logout
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
