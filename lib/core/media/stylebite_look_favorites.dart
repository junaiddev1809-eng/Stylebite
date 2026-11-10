import 'package:shared_preferences/shared_preferences.dart';

/// Persists favorite StyleBite look names (free personalization).
class StyleBiteLookFavorites {
  StyleBiteLookFavorites._();

  static const _key = 'stylebite_look_favorites_v1';

  static Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? const <String>[];
    return list.toSet();
  }

  static Future<Set<String>> toggle(String name) async {
    if (name == 'Original' || name.isEmpty) {
      return load();
    }
    final prefs = await SharedPreferences.getInstance();
    final next = (prefs.getStringList(_key) ?? <String>[]).toSet();
    if (next.contains(name)) {
      next.remove(name);
    } else {
      next.add(name);
    }
    await prefs.setStringList(_key, next.toList(growable: false));
    return next;
  }
}
