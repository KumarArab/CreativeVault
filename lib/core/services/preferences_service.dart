import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const String _lastDirectoryKey = 'last_selected_directory';

  Future<void> saveLastDirectory(String directoryPath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastDirectoryKey, directoryPath);
  }

  Future<String?> getLastDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastDirectoryKey);
  }

  Future<void> clearLastDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastDirectoryKey);
  }
}