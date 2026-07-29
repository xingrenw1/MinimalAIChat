import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mime/mime.dart';
import 'api_service.dart';
import 'app_state.dart';
import 'models.dart';
import 'roleplay_import.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  await state.load();
  runApp(MinimalAIChatApp(state: state));
}

class MinimalAIChatApp extends StatelessWidget {
  const MinimalAIChatApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final mode = switch (state.settings.themeMode) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        };
        final seed = Color(state.settings.seedColor);
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'MinimalAIChat',
          themeMode: mode,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: seed),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
          ),
          home: HomePage(state: state),
        );
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.state});
  final AppState state;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  AppState get state => widget.state;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) {
            _scroll.animateTo(
              _scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
            );
          }
        });
        return Scaffold(
          drawer: _buildDrawer(),
          appBar: AppBar(
            titleSpacing: 0,
            title: Row(
              children: [
                _Avatar(base64Data: state.settings.assistantAvatar, name: state.settings.assistantName, size: 34),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(state.settings.assistantName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      Text(_modelName(state.settings.model), style: Theme.of(context).textTheme.labelSmall),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: '设置',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SettingsPage(state: state)),
                ),
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              if (state.settings.backgroundImage.isNotEmpty)
                Opacity(
                  opacity: .22,
                  child: Image.memory(base64Decode(state.settings.backgroundImage), fit: BoxFit.cover),
                ),
              Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      itemCount: state.activeSession.messages.length + (state.isSending ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == state.activeSession.messages.length) {
                          return const Padding(
                            padding: EdgeInsets.all(18),
                            child: Row(children: [SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 10), Text('正在回复…')]),
                          );
                        }
                        return MessageBubble(message: state.activeSession.messages[index], settings: state.settings);
                      },
                    ),
                  ),
                  Composer(
                    state: state,
                    controller: _input,
                    onPickFiles: _pickAttachments,
                    onChooseModel: _showModelLibrary,
                    onSend: () {
                      final text = _input.text;
                      _input.clear();
                      state.send(text);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Drawer _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.auto_awesome)),
              title: const Text('MinimalAIChat', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Android'),
              trailing: IconButton(icon: const Icon(Icons.add_comment_outlined), onPressed: state.newChat),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                children: state.sessions.map((session) {
                  return ListTile(
                    selected: session.id == state.activeSessionId,
                    leading: const Icon(Icons.chat_bubble_outline, size: 20),
                    title: Text(session.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () {
                      state.selectChat(session.id);
                      Navigator.pop(context);
                    },
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'rename') _renameSession(session);
                        if (value == 'delete') state.deleteChat(session);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'rename', child: Text('重命名')),
                        PopupMenuItem(value: 'delete', child: Text('删除')),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(),
            ListTile(
              leading: _Avatar(base64Data: state.settings.userAvatar, name: state.settings.userName, size: 38),
              title: Text(state.settings.userName),
              subtitle: const Text('双方身份与应用设置'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsPage(state: state))),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _renameSession(ChatSession session) async {
    final controller = TextEditingController(text: session.title);
    final value = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('重命名话题'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('保存')),
        ],
      ),
    );
    if (value != null) state.renameChat(session, value);
  }

  Future<void> _pickAttachments() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true, withData: true);
    if (result == null) return;
    for (final file in result.files.take(6)) {
      final bytes = file.bytes;
      if (bytes == null) continue;
      if (bytes.length > 12 * 1024 * 1024) {
        _snack('附件 ${file.name} 超过 12 MB');
        continue;
      }
      final mime = lookupMimeType(file.name, headerBytes: bytes) ?? 'application/octet-stream';
      final kind = mime.startsWith('image/')
          ? 'image'
          : mime == 'application/pdf'
              ? 'pdf'
              : (mime.startsWith('text/') || RegExp(r'\.(json|md|csv|xml|ya?ml)$', caseSensitive: false).hasMatch(file.name))
                  ? 'text'
                  : 'file';
      state.addAttachment(ChatAttachment(name: file.name, mimeType: mime, base64Data: base64Encode(bytes), kind: kind));
    }
  }

  Future<void> _showModelLibrary() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: .82,
        child: ModelLibrarySheet(state: state),
      ),
    );
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class Composer extends StatelessWidget {
  const Composer({
    super.key,
    required this.state,
    required this.controller,
    required this.onPickFiles,
    required this.onChooseModel,
    required this.onSend,
  });

  final AppState state;
  final TextEditingController controller;
  final VoidCallback onPickFiles;
  final VoidCallback onChooseModel;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 10,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.pendingAttachments.isNotEmpty)
                SizedBox(
                  height: 72,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: state.pendingAttachments.map((attachment) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InputAttachmentChip(
                          attachment: attachment,
                          onRemove: () => state.removeAttachment(attachment),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              Row(
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.memory, size: 17),
                    label: Text(_modelName(state.settings.model)),
                    onPressed: onChooseModel,
                  ),
                  const SizedBox(width: 7),
                  FilterChip(
                    avatar: const Icon(Icons.public, size: 17),
                    label: const Text('联网'),
                    selected: state.settings.webSearch,
                    onSelected: (_) => state.updateSettings((s) => s.webSearch = !s.webSearch),
                  ),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(onPressed: onPickFiles, icon: const Icon(Icons.attach_file)),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 5,
                      decoration: const InputDecoration(hintText: '输入消息', border: OutlineInputBorder()),
                      onSubmitted: (_) => onSend(),
                    ),
                  ),
                  const SizedBox(width: 7),
                  IconButton.filled(
                    onPressed: state.isSending ? null : onSend,
                    icon: const Icon(Icons.arrow_upward),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InputAttachmentChip extends StatelessWidget {
  const InputAttachmentChip({super.key, required this.attachment, required this.onRemove});
  final ChatAttachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: attachment.kind == 'image' ? 68 : 128,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            image: attachment.kind == 'image'
                ? DecorationImage(image: MemoryImage(base64Decode(attachment.base64Data)), fit: BoxFit.cover)
                : null,
          ),
          padding: const EdgeInsets.all(8),
          child: attachment.kind == 'image'
              ? null
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.description_outlined, size: 20),
                    Text(attachment.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                  ],
                ),
        ),
        Positioned(
          right: 2,
          top: 2,
          child: InkWell(
            onTap: onRemove,
            child: const CircleAvatar(radius: 10, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 13, color: Colors.white)),
          ),
        ),
      ],
    );
  }
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message, required this.settings});
  final ChatMessage message;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final user = message.role == MessageRole.user;
    final avatar = user ? settings.userAvatar : settings.assistantAvatar;
    final name = user ? settings.userName : settings.assistantName;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: user ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!user) ...[_Avatar(base64Data: avatar, name: name, size: 32), const SizedBox(width: 9)],
          Flexible(
            child: Column(
              crossAxisAlignment: user ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.labelSmall),
                if (message.attachments.isNotEmpty)
                  Wrap(
                    alignment: user ? WrapAlignment.end : WrapAlignment.start,
                    spacing: 6,
                    runSpacing: 6,
                    children: message.attachments.map((attachment) {
                      if (attachment.kind == 'image') {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(base64Decode(attachment.base64Data), width: 220, height: 180, fit: BoxFit.cover),
                        );
                      }
                      return Chip(avatar: const Icon(Icons.description, size: 18), label: Text(attachment.name));
                    }).toList(),
                  ),
                if (message.content.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 3),
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                    decoration: BoxDecoration(
                      color: user
                          ? Theme.of(context).colorScheme.primary
                          : message.isError
                              ? Theme.of(context).colorScheme.errorContainer
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SelectableText(
                      message.content,
                      style: TextStyle(color: user ? Theme.of(context).colorScheme.onPrimary : null, height: 1.35),
                    ),
                  ),
              ],
            ),
          ),
          if (user) ...[const SizedBox(width: 9), _Avatar(base64Data: avatar, name: name, size: 32)],
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.base64Data, required this.name, required this.size});
  final String base64Data;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size / 2,
      foregroundImage: base64Data.isEmpty ? null : MemoryImage(base64Decode(base64Data)),
      child: base64Data.isEmpty ? Text(name.isEmpty ? '?' : name.substring(0, 1)) : null,
    );
  }
}

class ModelLibrarySheet extends StatefulWidget {
  const ModelLibrarySheet({super.key, required this.state});
  final AppState state;

  @override
  State<ModelLibrarySheet> createState() => _ModelLibrarySheetState();
}

class _ModelLibrarySheetState extends State<ModelLibrarySheet> {
  String query = '';
  bool loading = false;
  List<SavedModel>? online;

  @override
  Widget build(BuildContext context) {
    final source = online ?? widget.state.models;
    final filtered = source.where((model) {
      final value = query.toLowerCase();
      return model.name.toLowerCase().contains(value) ||
          model.id.toLowerCase().contains(value) ||
          model.tags.join(' ').toLowerCase().contains(value);
    }).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Expanded(child: Text('选择模型', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
              TextButton.icon(
                onPressed: loading
                    ? null
                    : () async {
                        setState(() => loading = true);
                        try {
                          online = await ApiService.fetchOpenRouterModels();
                        } catch (error) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
                        }
                        if (mounted) setState(() => loading = false);
                      },
                icon: loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.cloud_download_outlined),
                label: const Text('在线列表'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            onChanged: (value) => setState(() => query = value),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: '搜索名称、ID、能力或审查标记', border: OutlineInputBorder()),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (_, index) {
              final model = filtered[index];
              return ListTile(
                selected: widget.state.settings.model == model.id,
                title: Text(model.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(model.id, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (model.tags.isNotEmpty) Text(model.tags.join(' · ')),
                  ],
                ),
                trailing: model.recommended ? const Chip(label: Text('推荐')) : null,
                onTap: () {
                  widget.state.addModel(model);
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: _addCustomModel,
            icon: const Icon(Icons.add),
            label: const Text('添加自定义模型 ID'),
          ),
        ),
      ],
    );
  }

  Future<void> _addCustomModel() async {
    final controller = TextEditingController();
    final id = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('自定义模型'),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'provider/model-name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('添加')),
        ],
      ),
    );
    if (id != null && id.isNotEmpty) {
      widget.state.addModel(SavedModel(id: id, name: id.split('/').last, provider: id.split('/').first, tags: const ['自定义']));
      if (mounted) Navigator.pop(context);
    }
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.state});
  final AppState state;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  AppState get state => widget.state;

  @override
  Widget build(BuildContext context) {
    final settings = state.settings;
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _title('双方身份'),
          _identityRow(
            title: '我的身份',
            name: settings.userName,
            avatar: settings.userAvatar,
            onName: (value) => state.updateSettings((s) => s.userName = value),
            onAvatar: () => _pickImage((value) => state.updateSettings((s) => s.userAvatar = value)),
          ),
          _identityRow(
            title: '对方身份',
            name: settings.assistantName,
            avatar: settings.assistantAvatar,
            onName: (value) => state.updateSettings((s) => s.assistantName = value),
            onAvatar: () => _pickImage((value) => state.updateSettings((s) => s.assistantAvatar = value)),
          ),
          _title('模型提供方与 API'),
          _field('API 基础地址', settings.baseUrl, (value) => state.updateSettings((s) => s.baseUrl = value)),
          _field('API Key', settings.apiKey, (value) => state.updateSettings((s) => s.apiKey = value), secret: true),
          _field('模型 ID', settings.model, (value) => state.updateSettings((s) => s.model = value)),
          _title('联网搜索'),
          SwitchListTile(
            title: const Text('启用联网搜索'),
            subtitle: const Text('使用 Tavily 获取资料后交给当前模型回答'),
            value: settings.webSearch,
            onChanged: (value) => state.updateSettings((s) => s.webSearch = value),
          ),
          _field('Tavily API Key', settings.tavilyKey, (value) => state.updateSettings((s) => s.tavilyKey = value), secret: true),
          _title('角色扮演与提示词'),
          _multiline('系统提示词', settings.systemPrompt, (value) => state.updateSettings((s) => s.systemPrompt = value)),
          _multiline('角色扮演设定', settings.roleplayPrompt, (value) => state.updateSettings((s) => s.roleplayPrompt = value)),
          ListTile(
            leading: const Icon(Icons.theater_comedy_outlined),
            title: const Text('导入酒馆 JSON / PNG 角色卡'),
            subtitle: const Text('自动读取角色名称、提示词、开场白和头像'),
            onTap: _importRoleplay,
          ),
          _title('外观'),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'system', label: Text('跟随系统')),
              ButtonSegment(value: 'light', label: Text('浅色')),
              ButtonSegment(value: 'dark', label: Text('深色')),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (value) => state.updateSettings((s) => s.themeMode = value.first),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            children: [0xff3f7cff, 0xff8e5af7, 0xff00a884, 0xffff7a45, 0xffe94b78, 0xff455a64].map((value) {
              return InkWell(
                onTap: () => state.updateSettings((s) => s.seedColor = value),
                child: CircleAvatar(backgroundColor: Color(value), child: settings.seedColor == value ? const Icon(Icons.check, color: Colors.white) : null),
              );
            }).toList(),
          ),
          ListTile(
            leading: const Icon(Icons.wallpaper_outlined),
            title: const Text('自定义聊天背景'),
            subtitle: Text(settings.backgroundImage.isEmpty ? '未设置' : '已设置'),
            trailing: settings.backgroundImage.isEmpty
                ? null
                : IconButton(onPressed: () => state.updateSettings((s) => s.backgroundImage = ''), icon: const Icon(Icons.delete_outline)),
            onTap: () => _pickImage((value) => state.updateSettings((s) => s.backgroundImage = value)),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _title(String text) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      );

  Widget _field(String label, String initial, ValueChanged<String> onChanged, {bool secret = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        key: ValueKey('$label-$initial'),
        initialValue: initial,
        obscureText: secret,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        onChanged: onChanged,
      ),
    );
  }

  Widget _multiline(String label, String initial, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        key: ValueKey('$label-${initial.hashCode}'),
        initialValue: initial,
        minLines: 4,
        maxLines: 12,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        onChanged: onChanged,
      ),
    );
  }

  Widget _identityRow({
    required String title,
    required String name,
    required String avatar,
    required ValueChanged<String> onName,
    required VoidCallback onAvatar,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            InkWell(onTap: onAvatar, child: _Avatar(base64Data: avatar, name: name, size: 64)),
            const SizedBox(width: 14),
            Expanded(
              child: TextFormField(
                key: ValueKey('$title-$name'),
                initialValue: name,
                decoration: InputDecoration(labelText: title, helperText: '点击头像可随时更换'),
                onChanged: onName,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ValueChanged<String> onPicked) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    final bytes = result?.files.single.bytes;
    if (bytes != null) onPicked(base64Encode(bytes));
  }

  Future<void> _importRoleplay() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json', 'png'],
      withData: true,
    );
    final file = result?.files.single;
    if (file?.bytes == null) return;
    try {
      final imported = RoleplayImporter.parse(file!.name, Uint8List.fromList(file.bytes!));
      state.updateSettings((s) {
        s.assistantName = imported.name;
        s.roleplayPrompt = imported.prompt;
        if (imported.avatarBase64.isNotEmpty) s.assistantAvatar = imported.avatarBase64;
      });
      if (imported.firstMessage.isNotEmpty) {
        state.newChat();
        state.activeSession.messages
          ..clear()
          ..add(ChatMessage(role: MessageRole.assistant, content: imported.firstMessage));
        state.save();
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已导入角色：${imported.name}')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }
}

String _modelName(String id) {
  final value = id.split('/').last;
  return value.length > 24 ? '${value.substring(0, 24)}…' : value;
}
