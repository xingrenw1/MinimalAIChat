import 'dart:convert';

enum MessageRole { user, assistant, system }

class ChatAttachment {
  ChatAttachment({
    required this.name,
    required this.mimeType,
    required this.base64Data,
    required this.kind,
  });

  final String name;
  final String mimeType;
  final String base64Data;
  final String kind;

  int get byteLength => base64Data.length * 3 ~/ 4;

  Map<String, dynamic> toJson() => {
        'name': name,
        'mimeType': mimeType,
        'base64Data': base64Data,
        'kind': kind,
      };

  factory ChatAttachment.fromJson(Map<String, dynamic> json) => ChatAttachment(
        name: json['name'] as String? ?? '附件',
        mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
        base64Data: json['base64Data'] as String? ?? '',
        kind: json['kind'] as String? ?? 'file',
      );
}

class ChatMessage {
  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.attachments = const [],
    this.isError = false,
  }) : timestamp = timestamp ?? DateTime.now();

  final MessageRole role;
  String content;
  final DateTime timestamp;
  final List<ChatAttachment> attachments;
  final bool isError;

  Map<String, dynamic> toJson() => {
        'role': role.name,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'attachments': attachments.map((e) => e.toJson()).toList(),
        'isError': isError,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        role: MessageRole.values.firstWhere(
          (e) => e.name == json['role'],
          orElse: () => MessageRole.assistant,
        ),
        content: json['content'] as String? ?? '',
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? ''),
        attachments: (json['attachments'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(ChatAttachment.fromJson)
            .toList(),
        isError: json['isError'] as bool? ?? false,
      );
}

class ChatSession {
  ChatSession({
    String? id,
    this.title = '新对话',
    List<ChatMessage>? messages,
    DateTime? updatedAt,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        messages = messages ??
            [
              ChatMessage(
                role: MessageRole.assistant,
                content: '你好！今天想聊些什么？',
              ),
            ],
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String title;
  final List<ChatMessage> messages;
  DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'messages': messages.map((e) => e.toJson()).toList(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
        id: json['id'] as String?,
        title: json['title'] as String? ?? '新对话',
        messages: (json['messages'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(ChatMessage.fromJson)
            .toList(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      );
}

class SavedModel {
  const SavedModel({
    required this.id,
    required this.name,
    required this.provider,
    required this.tags,
    this.description = '',
    this.recommended = false,
  });

  final String id;
  final String name;
  final String provider;
  final List<String> tags;
  final String description;
  final bool recommended;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'provider': provider,
        'tags': tags,
        'description': description,
        'recommended': recommended,
      };

  factory SavedModel.fromJson(Map<String, dynamic> json) => SavedModel(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        provider: json['provider'] as String? ?? '',
        tags: (json['tags'] as List<dynamic>? ?? []).map((e) => '$e').toList(),
        description: json['description'] as String? ?? '',
        recommended: json['recommended'] as bool? ?? false,
      );
}

const recommendedModels = <SavedModel>[
  SavedModel(id: 'openai/gpt-5.6-sol', name: 'GPT-5.6 SOL', provider: 'OpenAI', tags: ['推理', '多模态', '工具'], recommended: true),
  SavedModel(id: 'anthropic/claude-sonnet-5', name: 'Claude Sonnet 5', provider: 'Anthropic', tags: ['写作', '长文本', '多模态'], recommended: true),
  SavedModel(id: 'google/gemini-3.6-flash', name: 'Gemini 3.6 Flash', provider: 'Google', tags: ['快速', '多模态'], recommended: true),
  SavedModel(id: 'deepseek/deepseek-v4-flash', name: 'DeepSeek V4 Flash', provider: 'DeepSeek', tags: ['中文', '推理', '代码'], recommended: true),
  SavedModel(id: 'x-ai/grok-4.5', name: 'Grok 4.5', provider: 'xAI', tags: ['通用', '工具'], recommended: true),
  SavedModel(id: 'qwen/qwen3.7-plus', name: 'Qwen 3.7 Plus', provider: 'Qwen', tags: ['中文', '写作'], recommended: true),
  SavedModel(id: 'mistralai/mistral-large-2512', name: 'Mistral Large', provider: 'Mistral', tags: ['通用', '长文本'], recommended: true),
  SavedModel(id: 'minimax/minimax-m3', name: 'MiniMax M3', provider: 'MiniMax', tags: ['中文', '角色扮演'], recommended: true),
  SavedModel(id: 'nousresearch/hermes-4-70b', name: 'Hermes 4 70B', provider: 'Nous Research', tags: ['角色扮演', '开放型'], recommended: true),
  SavedModel(id: 'cognitivecomputations/dolphin-mistral-24b-venice-edition', name: 'Venice Uncensored', provider: 'Cognitive Computations', tags: ['角色扮演', '开放型'], recommended: true),
];

class AppSettings {
  AppSettings({
    this.baseUrl = 'https://openrouter.ai/api/v1',
    this.apiKey = '',
    this.model = 'openrouter/auto',
    this.tavilyKey = '',
    this.webSearch = false,
    this.userName = '我',
    this.assistantName = 'AI 助手',
    this.userAvatar = '',
    this.assistantAvatar = '',
    this.backgroundImage = '',
    this.systemPrompt = '你是一位友好、准确且乐于助人的 AI 助手。默认使用简体中文回答。',
    this.roleplayPrompt = '',
    this.themeMode = 'system',
    this.seedColor = 0xff3f7cff,
  });

  String baseUrl;
  String apiKey;
  String model;
  String tavilyKey;
  bool webSearch;
  String userName;
  String assistantName;
  String userAvatar;
  String assistantAvatar;
  String backgroundImage;
  String systemPrompt;
  String roleplayPrompt;
  String themeMode;
  int seedColor;

  Map<String, dynamic> toJson() => {
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'model': model,
        'tavilyKey': tavilyKey,
        'webSearch': webSearch,
        'userName': userName,
        'assistantName': assistantName,
        'userAvatar': userAvatar,
        'assistantAvatar': assistantAvatar,
        'backgroundImage': backgroundImage,
        'systemPrompt': systemPrompt,
        'roleplayPrompt': roleplayPrompt,
        'themeMode': themeMode,
        'seedColor': seedColor,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        baseUrl: json['baseUrl'] as String? ?? 'https://openrouter.ai/api/v1',
        apiKey: json['apiKey'] as String? ?? '',
        model: json['model'] as String? ?? 'openrouter/auto',
        tavilyKey: json['tavilyKey'] as String? ?? '',
        webSearch: json['webSearch'] as bool? ?? false,
        userName: json['userName'] as String? ?? '我',
        assistantName: json['assistantName'] as String? ?? 'AI 助手',
        userAvatar: json['userAvatar'] as String? ?? '',
        assistantAvatar: json['assistantAvatar'] as String? ?? '',
        backgroundImage: json['backgroundImage'] as String? ?? '',
        systemPrompt: json['systemPrompt'] as String? ?? '默认使用简体中文回答。',
        roleplayPrompt: json['roleplayPrompt'] as String? ?? '',
        themeMode: json['themeMode'] as String? ?? 'system',
        seedColor: json['seedColor'] as int? ?? 0xff3f7cff,
      );
}

String encodeJson(Object value) => jsonEncode(value);
