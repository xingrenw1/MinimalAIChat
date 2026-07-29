import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

class ApiService {
  static Future<String> complete({
    required AppSettings settings,
    required List<ChatMessage> messages,
  }) async {
    final base = settings.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/chat/completions');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (settings.apiKey.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${settings.apiKey.trim()}';
    }
    if (base.contains('openrouter.ai')) {
      headers['HTTP-Referer'] = 'https://github.com/xingrenw1/MinimalAIChat';
      headers['X-Title'] = 'MinimalAIChat Android';
    }

    final system = StringBuffer(settings.systemPrompt.trim());
    system.write('\n用户的名字是“${settings.userName}”，你的名字是“${settings.assistantName}”。默认使用简体中文。');
    if (settings.roleplayPrompt.trim().isNotEmpty) {
      system.write('\n\n【角色扮演设定】\n${settings.roleplayPrompt.trim()}');
    }

    final apiMessages = <Map<String, dynamic>>[
      {'role': 'system', 'content': system.toString()},
      for (final message in messages) _encodeMessage(message),
    ];

    final toolsEnabled = settings.webSearch && settings.tavilyKey.trim().isNotEmpty;
    var body = await _postCompletion(
      uri: uri,
      headers: headers,
      model: settings.model.trim(),
      messages: apiMessages,
      toolsEnabled: toolsEnabled,
    );
    var responseMessage = _responseMessage(body);
    final toolCalls = responseMessage['tool_calls'] as List<dynamic>? ?? [];

    if (toolsEnabled && toolCalls.isNotEmpty) {
      apiMessages.add(responseMessage);
      for (final rawCall in toolCalls.whereType<Map<String, dynamic>>()) {
        final function = rawCall['function'] as Map<String, dynamic>? ?? {};
        if (function['name'] != 'web_search') continue;
        final query = _toolQuery(function['arguments']);
        final result = query.isEmpty
            ? '搜索词为空，无法执行。'
            : await _search(settings.tavilyKey, query);
        apiMessages.add({
          'role': 'tool',
          'tool_call_id': rawCall['id'] as String? ?? '',
          'content': result.isEmpty ? '没有找到可用的网页结果。' : result,
        });
      }
      body = await _postCompletion(
        uri: uri,
        headers: headers,
        model: settings.model.trim(),
        messages: apiMessages,
        toolsEnabled: false,
      );
      responseMessage = _responseMessage(body);
    }

    final content = responseMessage['content'];
    if (content is String && content.trim().isNotEmpty) return content.trim();
    if (content is List) {
      final text = content
          .whereType<Map<String, dynamic>>()
          .map((part) => part['text'])
          .whereType<String>()
          .join('\n')
          .trim();
      if (text.isNotEmpty) return text;
    }
    throw Exception('模型没有返回文本');
  }

  static Future<Map<String, dynamic>> _postCompletion({
    required Uri uri,
    required Map<String, String> headers,
    required String model,
    required List<Map<String, dynamic>> messages,
    required bool toolsEnabled,
  }) async {
    final request = <String, dynamic>{
      'model': model,
      'messages': messages,
      'temperature': 0.95,
      'stream': false,
    };
    if (toolsEnabled) {
      request['tools'] = [
        {
          'type': 'function',
          'function': {
            'name': 'web_search',
            'description': '当问题需要最新、实时或可核实的网络资料时搜索互联网。不需要最新资料时不要调用。',
            'parameters': {
              'type': 'object',
              'properties': {
                'query': {
                  'type': 'string',
                  'description': '简洁明确的搜索关键词',
                },
              },
              'required': ['query'],
            },
          },
        },
      ];
      request['tool_choice'] = 'auto';
    }
    final response = await http
        .post(uri, headers: headers, body: jsonEncode(request))
        .timeout(const Duration(seconds: 150));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}: ${_serverMessage(response.body)}');
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  static Map<String, dynamic> _responseMessage(Map<String, dynamic> body) {
    final choices = body['choices'] as List<dynamic>? ?? [];
    if (choices.isEmpty) throw Exception('服务器返回了空响应');
    final message = (choices.first as Map<String, dynamic>)['message'] as Map<String, dynamic>?;
    if (message == null) throw Exception('服务器响应缺少 message');
    return Map<String, dynamic>.from(message);
  }

  static String _toolQuery(dynamic arguments) {
    try {
      final decoded = arguments is String ? jsonDecode(arguments) : arguments;
      if (decoded is Map<String, dynamic>) {
        return (decoded['query'] as String? ?? '').trim();
      }
      if (decoded is Map) {
        return '${decoded['query'] ?? ''}'.trim();
      }
    } catch (_) {
      if (arguments is String) return arguments.trim();
    }
    return '';
  }

  static Map<String, dynamic> _encodeMessage(ChatMessage message) {
    final text = message.content;
    if (message.role != MessageRole.user || message.attachments.isEmpty) {
      return {'role': message.role.name, 'content': text};
    }

    final parts = <Map<String, dynamic>>[];
    if (text.trim().isNotEmpty) parts.add({'type': 'text', 'text': text});
    for (final attachment in message.attachments) {
      final dataUrl = 'data:${attachment.mimeType};base64,${attachment.base64Data}';
      if (attachment.kind == 'image') {
        parts.add({
          'type': 'image_url',
          'image_url': {'url': dataUrl},
        });
      } else if (attachment.kind == 'text') {
        final decoded = utf8.decode(base64Decode(attachment.base64Data), allowMalformed: true);
        parts.add({'type': 'text', 'text': '【附件：${attachment.name}】\n$decoded'});
      } else {
        parts.add({
          'type': 'file',
          'file': {'filename': attachment.name, 'file_data': dataUrl},
        });
      }
    }
    return {'role': message.role.name, 'content': parts};
  }

  static Future<String> _search(String apiKey, String query) async {
    try {
      final response = await http
          .post(
            Uri.parse('https://api.tavily.com/search'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'api_key': apiKey.trim(),
              'query': query,
              'search_depth': 'basic',
              'max_results': 5,
            }),
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) return '';
      final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final results = body['results'] as List<dynamic>? ?? [];
      return results.take(5).map((item) {
        final map = item as Map<String, dynamic>;
        return '来源：${map['title'] ?? ''}\n${map['content'] ?? ''}\n${map['url'] ?? ''}';
      }).join('\n\n');
    } catch (_) {
      return '';
    }
  }

  static String _serverMessage(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final error = json['error'];
      if (error is Map<String, dynamic>) return '${error['message'] ?? raw}';
    } catch (_) {}
    return raw.length > 300 ? raw.substring(0, 300) : raw;
  }

  static Future<List<SavedModel>> fetchOpenRouterModels() async {
    final response = await http
        .get(Uri.parse('https://openrouter.ai/api/v1/models'))
        .timeout(const Duration(seconds: 45));
    if (response.statusCode != 200) {
      throw Exception('获取模型失败：HTTP ${response.statusCode}');
    }
    final root = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final data = root['data'] as List<dynamic>? ?? [];
    return data.whereType<Map<String, dynamic>>().map((item) {
      final id = item['id'] as String? ?? '';
      final architecture = item['architecture'] as Map<String, dynamic>? ?? {};
      final topProvider = item['top_provider'] as Map<String, dynamic>? ?? {};
      final tags = <String>[];
      final modalities = architecture['input_modalities'] as List<dynamic>? ?? [];
      if (modalities.contains('image')) tags.add('图片');
      if (modalities.contains('file')) tags.add('文件');
      if (topProvider['is_moderated'] == false) tags.add('未标记审查');
      return SavedModel(
        id: id,
        name: item['name'] as String? ?? id,
        provider: id.contains('/') ? id.split('/').first : 'OpenRouter',
        description: item['description'] as String? ?? '',
        tags: tags,
      );
    }).where((model) => model.id.isNotEmpty).toList();
  }
}
