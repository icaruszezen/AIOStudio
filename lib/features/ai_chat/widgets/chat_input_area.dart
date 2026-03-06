import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/chat_provider.dart';

class ChatInputArea extends ConsumerStatefulWidget {
  const ChatInputArea({super.key});

  @override
  ConsumerState<ChatInputArea> createState() => _ChatInputAreaState();
}

class _ChatInputAreaState extends ConsumerState<ChatInputArea> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final List<String> _attachedImages = [];

  @override
  void initState() {
    super.initState();
    _focusNode.onKeyEvent = _handleKeyEvent;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.enter &&
        !HardwareKeyboard.instance.isShiftPressed) {
      final chatState = ref.read(chatProvider);
      if (!chatState.isGenerating) {
        _send();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty && _attachedImages.isEmpty) return;

    ref.read(chatProvider.notifier).sendMessage(
          text,
          imageFiles: _attachedImages.isNotEmpty
              ? List.from(_attachedImages)
              : null,
        );
    _controller.clear();
    _attachedImages.clear();
    setState(() {});
    _focusNode.requestFocus();
  }

  void _stop() {
    ref.read(chatProvider.notifier).stopGeneration();
  }

  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result != null) {
      setState(() {
        _attachedImages.addAll(
          result.paths.where((p) => p != null).map((p) => p!),
        );
      });
    }
  }

  void _removeImage(int index) {
    setState(() => _attachedImages.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final chatState = ref.watch(chatProvider);
    final isGenerating = chatState.isGenerating;

    final modelName = chatState.selectedModel ?? '未选择模型';

    return Container(
      decoration: BoxDecoration(
        color: theme.resources.solidBackgroundFillColorBase,
        border: Border(
          top: BorderSide(
            color: theme.resources.cardStrokeColorDefault,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_attachedImages.isNotEmpty) _buildImageBar(theme),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(
                    FluentIcons.attach,
                    size: 18,
                    color: theme.resources.textFillColorSecondary,
                  ),
                  onPressed: isGenerating ? null : _pickImages,
                ),
                const SizedBox(width: 8),
                Expanded(child: _buildTextInput(theme, isGenerating)),
                const SizedBox(width: 8),
                _buildSendButton(theme, isGenerating),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                modelName,
                style: theme.typography.caption?.copyWith(
                  color: theme.resources.textFillColorSecondary,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextInput(FluentThemeData theme, bool isGenerating) {
    return TextBox(
      controller: _controller,
      focusNode: _focusNode,
      placeholder: '输入消息... (Shift+Enter 换行)',
      maxLines: 5,
      minLines: 1,
      enabled: !isGenerating,
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildSendButton(FluentThemeData theme, bool isGenerating) {
    if (isGenerating) {
      return FilledButton(
        onPressed: _stop,
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(Colors.red),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(FluentIcons.stop_solid, size: 12),
            SizedBox(width: 6),
            Text('停止'),
          ],
        ),
      );
    }

    final hasContent =
        _controller.text.trim().isNotEmpty || _attachedImages.isNotEmpty;
    return FilledButton(
      onPressed: hasContent ? _send : null,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(FluentIcons.send, size: 12),
          SizedBox(width: 6),
          Text('发送'),
        ],
      ),
    );
  }

  Widget _buildImageBar(FluentThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: SizedBox(
        height: 72,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _attachedImages.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            return Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(_attachedImages[index]),
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 64,
                      height: 64,
                      color: theme.resources.subtleFillColorSecondary,
                      child: const Icon(FluentIcons.photo2, size: 24),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    icon: Container(
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: const Icon(
                        FluentIcons.cancel,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                    onPressed: () => _removeImage(index),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
