import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefs {
  static const String _isLoggedInKey = 'isLoggedIn';
  static const String _userEmailKey = 'userEmail';
  static const String _tokenKey = 'token';
  static const String _nameKey = 'name';
  static const String _ageKey = 'age';
  static const String _phoneKey = 'phone';
  static const String _specializationKey = 'specialization';
  static const String _hospitalKey = 'hospital';

  static Future<SharedPreferences> _getPrefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (e) {
      throw Exception('Failed to initialize SharedPreferences: $e');
    }
  }

  static Future<void> saveLoginState(String email, String token) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_isLoggedInKey, true);
    await prefs.setString(_userEmailKey, email);
    await prefs.setString(_tokenKey, token);
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await _getPrefs();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  static Future<void> clearLoginState() async {
    final prefs = await _getPrefs();
    await prefs.remove(_isLoggedInKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_tokenKey);
  }

  static Future<String?> getUserEmail() async {
    final prefs = await _getPrefs();
    return prefs.getString(_userEmailKey);
  }

  static Future<String?> getToken() async {
    final prefs = await _getPrefs();
    return prefs.getString(_tokenKey);
  }

  static Future<void> setName(String name) async {
    final prefs = await _getPrefs();
    await prefs.setString(_nameKey, name);
  }

  static Future<String?> getName() async {
    final prefs = await _getPrefs();
    return prefs.getString(_nameKey);
  }

  static Future<void> setProfileData({
    required String name,
    required String email,
    required String age,
    required String phone,
    required String specialization,
    required String hospital,
  }) async {
    final prefs = await _getPrefs();
    await prefs.setString(_nameKey, name);
    await prefs.setString(_userEmailKey, email);
    await prefs.setString(_ageKey, age);
    await prefs.setString(_phoneKey, phone);
    await prefs.setString(_specializationKey, specialization);
    await prefs.setString(_hospitalKey, hospital);
  }

  static Future<Map<String, String>> getProfileData() async {
    final prefs = await _getPrefs();
    return {
      'name': prefs.getString(_nameKey) ?? '',
      'email': prefs.getString(_userEmailKey) ?? '',
      'age': prefs.getString(_ageKey) ?? '',
      'phone': prefs.getString(_phoneKey) ?? '',
      'specialization': prefs.getString(_specializationKey) ?? '',
      'hospital': prefs.getString(_hospitalKey) ?? '',
    };
  }

  static Future<void> logout() async {
    final prefs = await _getPrefs();
    await prefs.clear();
  }
}