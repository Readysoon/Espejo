import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/entry_provider.dart';
class ReflectionScreen extends StatefulWidget {
  final String? entryId;
  final String? preview;

  const ReflectionScreen({super.key, this.entryId, this.preview});

  @override
  State<ReflectionScreen> createState() => _ReflectionScreenState();
}

class _ReflectionScreenState extends State<ReflectionScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  // Lokaler Chat-Verlauf für diese Session
  // Jede Nachricht: {'role': 'user'|'assistant', 'content': '...'}
  final List<Map<String, String>> _localMessages = [];

  @override
  void initState() {
    super.initState();
    if (widget.entryId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context
            .read<EntryProvider>()
            .loadReflections(widget.entryId!)
            .then((_) => _buildLocalMessagesFromHistory());
      });
    }
  }

  void _buildLocalMessagesFromHistory() {
    final reflections = context.read<EntryProvider>().reflections;
    setState(() {
      _localMessages.clear();
      for (final r in reflections) {
        _localMessages.add({'role': 'assistant', 'content': r.content});
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    context.read<EntryProvider>().clearReflections();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();

    setState(() {
      _localMessages.add({'role': 'user', 'content': text});
    });
    _scrollToBottom();

    if (!mounted) return;
    final provider = context.read<EntryProvider>();
    await provider.sendMessage(text);

    if (!mounted) return;
    if (provider.reflections.isNotEmpty) {
      final lastReflection = provider.reflections.last;
      setState(() {
        _localMessages.add({
          'role': 'assistant',
          'content': lastReflection.content,
        });
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.preview != null
              ? widget.preview!.length > 30
                  ? '${widget.preview!.substring(0, 30)}...'
                  : widget.preview!
              : 'Neues Gespräch',
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<EntryProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading && _localMessages.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (_localMessages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome,
                            size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Schreibe eine Nachricht,\num ein Gespräch zu starten',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  itemCount: _localMessages.length +
                      (provider.isSending ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _localMessages.length && provider.isSending) {
                      return _TypingIndicator();
                    }
                    final msg = _localMessages[index];
                    final isUser = msg['role'] == 'user';
                    return _ChatBubble(
                      content: msg['content']!,
                      isUser: isUser,
                      colorScheme: colorScheme,
                    );
                  },
                );
              },
            ),
          ),
          _InputBar(
            controller: _controller,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String content;
  final bool isUser;
  final ColorScheme colorScheme;

  const _ChatBubble({
    required this.content,
    required this.isUser,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Text(
          content,
          style: TextStyle(
            color: isUser ? colorScheme.onPrimary : colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            const Text('Mistral denkt nach...'),
          ],
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _InputBar({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Consumer<EntryProvider>(
      builder: (context, provider, _) {
        return Container(
          padding: EdgeInsets.fromLTRB(
              16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 16),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(
              top: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: 'Nachricht eingeben...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: provider.isSending ? null : onSend,
                icon: provider.isSending
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
              ),
            ],
          ),
        );
      },
    );
  }
}
