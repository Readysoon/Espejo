import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../state/entry_provider.dart';
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
      context.read<EntryProvider>().loadEntries();
    });
  }

  void _openNewChat(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ReflectionScreen()),
    );
  }

  void _openExistingChat(BuildContext context, String entryId, String preview) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReflectionScreen(entryId: entryId, preview: preview),
      ),
    );
  }

  Future<void> _deleteEntry(BuildContext context, String entryId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eintrag löschen?'),
        content: const Text('Dieser Eintrag und alle Antworten werden gelöscht.'),
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
      context.read<EntryProvider>().deleteEntry(entryId);
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
            onPressed: () async {
              await SupabaseService().signOut();
            },
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
                    onPressed: () => provider.loadEntries(),
                    child: const Text('Erneut versuchen'),
                  ),
                ],
              ),
            );
          }

          if (provider.entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Noch keine Gespräche',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tippe auf + um ein neues Gespräch zu starten',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: provider.loadEntries,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: provider.entries.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final entry = provider.entries[index];
                final formatted = DateFormat('dd.MM.yyyy – HH:mm').format(entry.createdAt.toLocal());
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(Icons.chat_bubble_outline,
                          color: Theme.of(context).colorScheme.primary),
                    ),
                    title: Text(
                      entry.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      formatted,
                      style: TextStyle(
                          color: Colors.grey[500], fontSize: 12),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () => _deleteEntry(context, entry.id),
                    ),
                    onTap: () =>
                        _openExistingChat(context, entry.id, entry.content),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openNewChat(context),
        icon: const Icon(Icons.add),
        label: const Text('Neues Gespräch'),
      ),
    );
  }
}
