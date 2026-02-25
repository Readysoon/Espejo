import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../state/entry_provider.dart';

class ReflectionScreen extends StatefulWidget {
  final String? conversationId;
  final String? title;
  final bool isNewDay;

  const ReflectionScreen({
    super.key,
    this.conversationId,
    this.title,
    this.isNewDay = false,
  });

  @override
  State<ReflectionScreen> createState() => _ReflectionScreenState();
}

class _ReflectionScreenState extends State<ReflectionScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.isNewDay) {
        context.read<EntryProvider>().startNewDay().then((_) => _scrollToBottom());
      } else if (widget.conversationId != null) {
        context
            .read<EntryProvider>()
            .openExistingConversation(widget.conversationId!)
            .then((_) => _scrollToBottom());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    context.read<EntryProvider>().clearMessages();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    await context.read<EntryProvider>().sendMessage(text);
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final provider = context.read<EntryProvider>();
        final nav = Navigator.of(context);
        if (widget.isNewDay) {
          await provider.finalizeConversation();
        }
        nav.pop();
      },
      child: SelectionArea(
        child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title ?? 'Wie war dein Tag?'),
          actions: [
            Consumer<EntryProvider>(
              builder: (context, provider, _) {
                if (provider.messages.isEmpty) return const SizedBox();
                return IconButton(
                  icon: const Icon(Icons.copy),
                  tooltip: 'Chat kopieren',
                  onPressed: () {
                    final text = provider.messages
                        .map((m) =>
                            '${m.role == 'user' ? 'Du' : 'Espejo'}: ${m.content}')
                        .join('\n\n');
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Chat kopiert!')),
                    );
                  },
                );
              },
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Consumer<EntryProvider>(
                builder: (context, provider, _) {
                  if (provider.error != null && provider.messages.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 48, color: Colors.red),
                            const SizedBox(height: 16),
                            const Text('Fehler beim Starten:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            SelectableText(
                              provider.error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontFamily: 'monospace', fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (provider.isCollectingData) {
                    return const _LoadingState(
                      message: 'Tagesdaten werden gesammelt...',
                    );
                  }

                  if (provider.isFinalizing) {
                    return const _LoadingState(
                      message: 'Tagebucheintrag wird erstellt...',
                    );
                  }

                  if (provider.isLoading && provider.messages.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (provider.messages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome,
                              size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'Einen Moment...',
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
                    itemCount: provider.messages.length +
                        (provider.isSending ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == provider.messages.length &&
                          provider.isSending) {
                        return _TypingIndicator();
                      }
                      final msg = provider.messages[index];
                      return _ChatBubble(
                        content: msg.content,
                        isUser: msg.role == 'user',
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
      ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  final String message;
  const _LoadingState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.grey[600])),
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
        child: SelectableText(
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
            const Text('Espejo denkt nach...'),
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
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => provider.isSending ? null : onSend(),
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
