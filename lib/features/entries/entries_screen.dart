import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../state/entry_provider.dart';
import '../../models/conversation.dart';
import '../../services/supabase_service.dart';
import '../reflection/reflection_screen.dart';

class EntriesScreen extends StatefulWidget {
  const EntriesScreen({super.key});

  @override
  State<EntriesScreen> createState() => _EntriesScreenState();
}

class _EntriesScreenState extends State<EntriesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EntryProvider>().loadConversations();
    });
  }

  void _openNewDay(BuildContext context) {
    final provider = context.read<EntryProvider>();
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => const ReflectionScreen(isNewDay: true),
        ))
        .then((_) => provider.loadConversations());
  }

  void _openEntry(BuildContext context, Conversation conversation) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _EntryDetailScreen(conversation: conversation),
      ),
    );
  }

  Future<void> _deleteConversation(
      BuildContext context, String conversationId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eintrag löschen?'),
        content: const Text('Dieser Tagebucheintrag wird dauerhaft gelöscht.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<EntryProvider>().deleteConversation(conversationId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Espejo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Abmelden',
            onPressed: () async => await SupabaseService().signOut(),
          ),
        ],
      ),
      body: Consumer<EntryProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Fehler: ${provider.error}'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: provider.loadConversations,
                    child: const Text('Erneut versuchen'),
                  ),
                ],
              ),
            );
          }

          if (provider.conversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.book_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Noch keine Einträge',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tippe auf + um deinen Tag zu reflektieren',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: provider.loadConversations,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: provider.conversations.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final c = provider.conversations[index];
                final dateStr = DateFormat('EEEE, dd. MMMM yyyy', 'de')
                    .format(c.date.toLocal());
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    title: Text(
                      c.title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        if (c.subtitle != null && c.subtitle!.isNotEmpty)
                          Text(
                            c.subtitle!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.calendar_today,
                                size: 11, color: Colors.grey[400]),
                            const SizedBox(width: 4),
                            Text(
                              dateStr,
                              style: TextStyle(
                                  color: Colors.grey[400], fontSize: 11),
                            ),
                            if (c.steps != null) ...[
                              const SizedBox(width: 12),
                              Icon(Icons.directions_walk,
                                  size: 11, color: Colors.grey[400]),
                              const SizedBox(width: 4),
                              Text(
                                '${c.steps} Schritte',
                                style: TextStyle(
                                    color: Colors.grey[400], fontSize: 11),
                              ),
                            ],
                            if (c.location != null) ...[
                              const SizedBox(width: 12),
                              Icon(Icons.location_on,
                                  size: 11, color: Colors.grey[400]),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  c.location!,
                                  style: TextStyle(
                                      color: Colors.grey[400], fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () =>
                          _deleteConversation(context, c.id),
                    ),
                    onTap: () => _openEntry(context, c),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openNewDay(context),
        icon: const Icon(Icons.add),
        label: const Text('Tag reflektieren'),
      ),
    );
  }
}

class _EntryDetailScreen extends StatefulWidget {
  final Conversation conversation;
  const _EntryDetailScreen({required this.conversation});

  @override
  State<_EntryDetailScreen> createState() => _EntryDetailScreenState();
}

class _EntryDetailScreenState extends State<_EntryDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<EntryProvider>()
          .openExistingConversation(widget.conversation.id);
    });
  }

  @override
  void dispose() {
    context.read<EntryProvider>().clearMessages();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.conversation;
    final colorScheme = Theme.of(context).colorScheme;
    final dateStr =
        DateFormat('EEEE, dd. MMMM yyyy', 'de').format(c.date.toLocal());

    return Scaffold(
      appBar: AppBar(title: Text(c.title)),
      body: Consumer<EntryProvider>(
        builder: (context, provider, _) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Datum + Metadaten
              Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Text(dateStr,
                      style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                  if (c.weather != null) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.wb_sunny_outlined,
                        size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(c.weather!,
                        style:
                            TextStyle(color: Colors.grey[500], fontSize: 13)),
                  ],
                ],
              ),
              if (c.steps != null || c.location != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (c.steps != null) ...[
                      Icon(Icons.directions_walk,
                          size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text('${c.steps} Schritte',
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 13)),
                      const SizedBox(width: 12),
                    ],
                    if (c.location != null) ...[
                      Icon(Icons.location_on,
                          size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(c.location!,
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 13)),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: 16),

              // Unterüberschrift
              if (c.subtitle != null && c.subtitle!.isNotEmpty) ...[
                Text(
                  c.subtitle!,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 16),
              ],

              // Zusammenfassung
              if (c.summary != null && c.summary!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    c.summary!,
                    style: const TextStyle(height: 1.6),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Trennlinie zum Chat
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('Gesprächsverlauf',
                        style: TextStyle(
                            color: Colors.grey[500], fontSize: 12)),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),

              // Chat-Verlauf
              if (provider.isLoading)
                const Center(child: CircularProgressIndicator())
              else
                ...provider.messages.map((msg) {
                  final isUser = msg.role == 'user';
                  return Align(
                    alignment: isUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      constraints: BoxConstraints(
                        maxWidth:
                            MediaQuery.of(context).size.width * 0.75,
                      ),
                      decoration: BoxDecoration(
                        color: isUser
                            ? colorScheme.primary
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(14),
                          topRight: const Radius.circular(14),
                          bottomLeft: Radius.circular(isUser ? 14 : 4),
                          bottomRight: Radius.circular(isUser ? 4 : 14),
                        ),
                      ),
                      child: Text(
                        msg.content,
                        style: TextStyle(
                          color: isUser
                              ? colorScheme.onPrimary
                              : colorScheme.onSurface,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}
