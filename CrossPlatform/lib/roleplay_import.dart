import 'dart:convert';
import 'dart:typed_data';

class ImportedRoleplay {
  const ImportedRoleplay({
    required this.name,
    required this.prompt,
    required this.firstMessage,
    this.avatarBase64 = '',
  });

  final String name;
  final String prompt;
  final String firstMessage;
  final String avatarBase64;
}

class RoleplayImporter {
  static ImportedRoleplay parse(String fileName, Uint8List bytes) {
    final ext = fileName.split('.').last.toLowerCase();
    Uint8List jsonBytes;
    var avatar = '';
    if (ext == 'json') {
      jsonBytes = bytes;
    } else if (ext == 'png') {
      jsonBytes = _extractPngCard(bytes);
      avatar = base64Encode(bytes);
    } else {
      throw const FormatException('仅支持 SillyTavern JSON 或 PNG 角色卡');
    }

    final root = jsonDecode(utf8.decode(jsonBytes, allowMalformed: true));
    if (root is! Map<String, dynamic>) {
      throw const FormatException('角色卡 JSON 无效');
    }
    final dynamic dataNode = root['data'];
    final data = dataNode is Map<String, dynamic> ? dataNode : root;
    final name = _text(data['name']);
    if (name.isEmpty) throw const FormatException('角色卡缺少角色名称');

    final sections = <String>[];
    void add(String title, dynamic value) {
      final text = _text(value);
      if (text.isNotEmpty) sections.add('【$title】\n$text');
    }

    add('角色说明', data['description'] ?? data['char_persona']);
    add('性格', data['personality']);
    add('场景', data['scenario']);
    add('系统提示', data['system_prompt']);
    add('示例对话', data['mes_example'] ?? data['example_dialogue']);
    add('后置指令', data['post_history_instructions']);

    return ImportedRoleplay(
      name: name,
      prompt: '你必须始终扮演“$name”，不要跳出角色，不要替用户决定行动。除非设定要求其他语言，否则使用简体中文。\n\n${sections.join('\n\n')}',
      firstMessage: _text(data['first_mes'] ?? data['first_message'] ?? data['greeting']),
      avatarBase64: avatar,
    );
  }

  static Uint8List _extractPngCard(Uint8List bytes) {
    const signature = [137, 80, 78, 71, 13, 10, 26, 10];
    var signatureMatches = bytes.length >= 8;
    for (var i = 0; i < 8 && signatureMatches; i++) {
      signatureMatches = bytes[i] == signature[i];
    }
    if (!signatureMatches) {
      throw const FormatException('PNG 文件无效');
    }

    var offset = 8;
    final data = ByteData.sublistView(bytes);
    while (offset + 12 <= bytes.length) {
      final length = data.getUint32(offset);
      final type = ascii.decode(bytes.sublist(offset + 4, offset + 8));
      final start = offset + 8;
      final end = start + length;
      if (end + 4 > bytes.length) break;
      final chunk = bytes.sublist(start, end);
      String? embedded;
      if (type == 'tEXt') embedded = _textChunk(chunk);
      if (type == 'iTXt') embedded = _internationalTextChunk(chunk);
      if (embedded != null) return _decodeEmbedded(embedded);
      if (type == 'IEND') break;
      offset = end + 4;
    }
    throw const FormatException('PNG 中没有找到 chara/ccv3 角色数据');
  }

  static String? _textChunk(List<int> chunk) {
    final zero = chunk.indexOf(0);
    if (zero < 0) return null;
    final key = latin1.decode(chunk.sublist(0, zero)).toLowerCase();
    if (key != 'chara' && key != 'ccv3') return null;
    return utf8.decode(chunk.sublist(zero + 1), allowMalformed: true).trim();
  }

  static String? _internationalTextChunk(List<int> chunk) {
    final zero = chunk.indexOf(0);
    if (zero < 0) return null;
    final key = utf8.decode(chunk.sublist(0, zero), allowMalformed: true).toLowerCase();
    if (key != 'chara' && key != 'ccv3') return null;
    var cursor = zero + 1;
    if (cursor + 2 > chunk.length || chunk[cursor] != 0) return null;
    cursor += 2;
    for (var i = 0; i < 2; i++) {
      final next = chunk.indexOf(0, cursor);
      if (next < 0) return null;
      cursor = next + 1;
    }
    return utf8.decode(chunk.sublist(cursor), allowMalformed: true).trim();
  }

  static Uint8List _decodeEmbedded(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('{')) return Uint8List.fromList(utf8.encode(trimmed));
    try {
      return base64Decode(trimmed);
    } catch (_) {
      throw const FormatException('角色卡内嵌数据无法解码');
    }
  }

  static String _text(dynamic value) => value is String ? value.trim() : '';
}
