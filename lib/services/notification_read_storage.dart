import 'package:shared_preferences/shared_preferences.dart';

class NotificationReadStorage {
  static String _key(String memberId) => 'read_messages_$memberId';

  static Future<Set<String>> load(String memberId) async {
    if (memberId.isEmpty) return {};
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key(memberId)) ?? const <String>[];
    return list.where((e) => e.isNotEmpty).toSet();
  }

  static Future<void> save(String memberId, Set<String> ids) async {
    if (memberId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = ids.where((e) => e.isNotEmpty).toSet().toList()..sort();
    await prefs.setStringList(_key(memberId), list);
  }

  static Future<Set<String>> markRead(String memberId, String messageId) async {
    if (memberId.isEmpty || messageId.isEmpty) return {};
    final ids = await load(memberId);
    ids.add(messageId);
    await save(memberId, ids);
    return ids;
  }
}
