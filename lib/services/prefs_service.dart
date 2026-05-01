import 'package:shared_preferences/shared_preferences.dart';

class PrefsService {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static String get systemPrompt =>
      _prefs.getString('system_prompt') ?? 'You are a helpful AI assistant.';

  static Future<void> setSystemPrompt(String v) =>
      _prefs.setString('system_prompt', v);

  static String? get modelPath => _prefs.getString('model_path');

  static Future<void> setModelPath(String v) =>
      _prefs.setString('model_path', v);

  static int get maxTokens => _prefs.getInt('max_tokens') ?? 0;

  static Future<void> setMaxTokens(int v) =>
      _prefs.setInt('max_tokens', v);

  static int get threads => _prefs.getInt('threads') ?? 4;

  static Future<void> setThreads(int v) =>
      _prefs.setInt('threads', v);

  static int get contextSize => _prefs.getInt('context_size') ?? 4096;

  static Future<void> setContextSize(int v) =>
      _prefs.setInt('context_size', v);
}
