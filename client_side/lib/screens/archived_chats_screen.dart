
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:namer_app/helpers/home_widgets.dart';
import 'package:namer_app/services/chat_service.dart';
import 'package:namer_app/models/chat.dart';
import 'package:namer_app/helpers/chat_tile.dart';

typedef ChatId = String;

/// Screen that displays archived chats only.
class ArchivedChatsScreen extends StatelessWidget {
  const ArchivedChatsScreen({super.key});
  // Bottom sheet helpers

  void _showArchivedOptions(BuildContext context, ChatModel chat) {
    final chatService = context.read<ChatService>();

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.unarchive_outlined, color: Colors.blue),
              title: Text(
                'Unarchive Chat',
                style: TextStyle(
                  color:
                      Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              onTap: () {
                _unarchiveChat(chatService, chat.id);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(
                chat.isFavorite
                    ? Icons.push_pin
                    : Icons.push_pin_outlined,
                color: Colors.tealAccent,
              ),
              title: Text(
                chat.isFavorite ? 'Unpin Chat' : 'Pin Chat',
                style: TextStyle(
                  color:
                      Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              onTap: () {
                _toggleFavorite(chatService, chat);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // Action helpers (safe)

  void _unarchiveChat(ChatService service, ChatId chatId) {
    service.updateChatStatus(chatId, {'isArchived': false});
  }

  void _toggleFavorite(ChatService service, ChatModel chat) {
    service.updateChatStatus(
      chat.id,
      {'isFavorite': !chat.isFavorite},
    );
  }

  
  // Build
  @override
  Widget build(BuildContext context) {
    final chatService = context.watch<ChatService>();

    final List<ChatModel> archivedChats =
        _filterArchivedChats(chatService.chats);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(
          'Archived',
          style: TextStyle(
            color:
                Theme.of(context).appBarTheme.foregroundColor,
          ),
        ),
        iconTheme: IconThemeData(
          color:
              Theme.of(context).appBarTheme.foregroundColor,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          children: [
            const SizedBox(height: 10),
            const SectionHeader(title: 'Hidden Chats'),
            const SizedBox(height: 20),
            Expanded(
              child: archivedChats.isEmpty
                  ? const Center(
                      child: Text(
                        'Your archive is empty',
                        style:
                            TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: archivedChats.length,
                      itemBuilder: (context, index) {
                        final chat = archivedChats[index];
                        return Padding(
                          padding:
                              const EdgeInsets.only(bottom: 12.0),
                          child: ChatTile(
                            chat: chat,
                            onTap: () => context.push(
                              '/home/chat/${chat.id}',
                            ),
                            onToggleFavorite: () =>
                                _toggleFavorite(chatService, chat),
                            onToggleArchive: () =>
                                _unarchiveChat(
                              chatService,
                              chat.id,
                            ),
                            onDelete: () {
                              // Placeholder for future delete logic
                            },
                            onMore: () =>
                                _showArchivedOptions(context, chat),
                            onLongPress: () =>
                                _showArchivedOptions(context, chat),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Internal utilities

  List<ChatModel> _filterArchivedChats(
    List<ChatModel> chats,
  ) {
    return chats.where((c) => c.isArchived).toList();
  }
}

//Extensions

extension ArchivedChatsScreenExtensions on ArchivedChatsScreen {
  /// Screen identifier (useful for analytics or logging)
  String get screenName => 'ArchivedChatsScreen';
}
