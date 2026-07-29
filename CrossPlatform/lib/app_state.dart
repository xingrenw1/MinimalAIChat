import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'models.dart';

class AppState extends ChangeNotifier {
  static const _settingsKey = 'minimal_ai_settings_v1';
  static const _sessionsKey = 'minimal_ai_sessions_v1';
  static const _modelsKey = 'minimal_ai_models_v1';

  AppSettings settings = AppSettings();
  List<ChatSession> sessions = [ChatSession()];
  List<SavedModel> models = [...recommendedModels];
  String activeSessionId = '';
  bool isSending = false;
  String? lastError;
  final List<ChatAttachment> pendingAttachments = [];

  ChatSession get activeSession {
    if (sessions.isEmpty) sessions.add(ChatSession());
    return sessions.firstWhere(
      (session) => session.id == activeSessionId,
      orElse: () {
        activeSessionId = sessions.first.id;
        return sessions.first;
      },
    );
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final rawSettings = prefs.getString(_settingsKey);
    final rawSessions = prefs.getString(_sessionsKey);
    final rawModels = prefs.getString(_modelsKey);
    try {
      if (rawSettings != null) {
        settings = AppSettings.fromJson(jsonDecode(rawSettings) as Map<String, dynamic>);
      }
      if (rawSessions != null) {
        sessions = (jsonDecode(rawSessions) as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(ChatSession.fromJson)
            .toList();
      }
      if (rawModels != null) {
        final custom = (jsonDecode(rawModels) as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(SavedModel.fromJson)
            .where((model) => !recommendedModels.any((item) => item.id == model.id))
            .toList();
        models = [...recommendedModels, ...custom];
      }
    } catch (_) {}
    if (sessions.isEmpty) sessions = [ChatSession()];
    activeSessionId = sessions.first.id;
    notifyListeners();
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
    await prefs.setString(_sessionsKey, jsonEncode(sessions.map((e) => e.toJson()).toList()));
    await prefs.setString(_modelsKey, jsonEncode(models.map((e) => e.toJson()).toList()));
  }

  void updateSettings(void Function(AppSettings settings) action) {
    action(settings);
    save();
    notifyListeners();
  }

  void newChat() {
    final session = ChatSession();
    sessions.insert(0, session);
    activeSessionId = session.id;
    pendingAttachments.clear();
    save();
    notifyListeners();
  }

  void selectChat(String id) {
    activeSessionId = id;
    pendingAttachments.clear();
    notifyListeners();
  }

  void renameChat(ChatSession session, String title) {
    final value = title.trim();
    if (value.isEmpty) return;
    session.title = value;
    session.updatedAt = DateTime.now();
    save();
    notifyListeners();
  }

  void deleteChat(ChatSession session) {
    sessions.removeWhere((item) => item.id == session.id);
    if (sessions.isEmpty) sessions.add(ChatSession());
    if (!sessions.any((item) => item.id == activeSessionId)) {
      activeSessionId = sessions.first.id;
    }
    save();
    notifyListeners();
  }

  void addAttachment(ChatAttachment attachment) {
    if (pendingAttachments.length >= 6) {
      lastError = '一条消息最多添加 6 个附件';
      notifyListeners();
      return;
    }
    pendingAttachments.add(attachment);
    notifyListeners();
  }

  void removeAttachment(ChatAttachment attachment) {
    pendingAttachments.remove(attachment);
    notifyListeners();
  }

  void addModel(SavedModel model) {
    if (!models.any((item) => item.id == model.id)) models.add(model);
    settings.model = model.id;
    save();
    notifyListeners();
  }

  void selectModel(String id) {
    settings.model = id;
    save();
    notifyListeners();
  }

  Future<void> send(String rawText) async {
    final text = rawText.trim();
    if (isSending || (text.isEmpty && pendingAttachments.isEmpty)) return;
    final attachments = List<ChatAttachment>.from(pendingAttachments);
    pendingAttachments.clear();
    final userMessage = ChatMessage(
      role: MessageRole.user,
      content: text,
      attachments: attachments,
    );
    activeSession.messages.add(userMessage);
    activeSession.updatedAt = DateTime.now();
    if (activeSession.title == '新对话') {
      activeSession.title = text.isEmpty
          ? attachments.first.name
          : (text.length > 24 ? text.substring(0, 24) : text);
    }
    isSending = true;
    lastError = null;
    await save();
    notifyListeners();

    try {
      final response = await ApiService.complete(
        settings: settings,
        messages: activeSession.messages,
      );
      activeSession.messages.add(
        ChatMessage(role: MessageRole.assistant, content: response),
      );
    } catch (error) {
      lastError = '$error';
      activeSession.messages.add(
        ChatMessage(
          role: MessageRole.assistant,
          content: '请求失败：$error',
          isError: true,
        ),
      );
    } finally {
      isSending = false;
      activeSession.updatedAt = DateTime.now();
      await save();
      notifyListeners();
    }
  }
}
