import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:namer_app/helpers/action_button.dart';
import 'package:namer_app/helpers/search_bar.dart';
import 'package:namer_app/helpers/home_widgets.dart';
import 'package:namer_app/models/chat.dart';
import 'package:namer_app/services/homepage_service.dart';
import 'package:namer_app/services/chat_service.dart';
import 'package:namer_app/theme/app_colors.dart';
import 'create_group.dart';
import 'archived_chats_screen.dart';
import '../helpers/chat_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final HomepageService _homepageService = HomepageService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatService>().init();
      _loadChats();
    });
  }

  Future<void> _loadChats() async {
    setState(() => _isLoading = true);
    try {
      final chats = await _homepageService.getUserChats();
      if (mounted) {
        context.read<ChatService>().setInitialChats(chats);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Failed to load chats: $e', isError: true);
      }
    }
  }

  void _showChatOptions(BuildContext context, ChatModel chat) {
    final chatService = context.read<ChatService>();

    final bool isGroup = chat.isGroup;
    final String actionText = isGroup ? 'Leave Group' : 'Delete Chat';
    final IconData actionIcon =
        isGroup ? Icons.exit_to_app : Icons.delete_outline;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                  chat.isFavorite ? Icons.push_pin : Icons.push_pin_outlined,
                  color: Colors.tealAccent),
              title: Text(chat.isFavorite ? 'Unpin Chat' : 'Pin Chat',
                  style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color)),
              onTap: () {
                chatService.updateChatStatus(
                    chat.id, {'isFavorite': !chat.isFavorite});
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(
                  chat.isArchived ? Icons.unarchive : Icons.archive_outlined,
                  color: Colors.blue),
              title: Text(
                chat.isArchived ? 'Unarchive Chat' : 'Archive Chat',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              onTap: () {
                chatService.updateChatStatus(
                    chat.id, {'isArchived': !chat.isArchived});
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(actionIcon, color: AppErrorColor),
              title: Text(actionText,
                  style: const TextStyle(color: AppErrorColor)),
              onTap: () {
                Navigator.pop(context); // Close bottom sheet
                _confirmAction(context, chat); // Show confirmation dialog
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmAction(BuildContext context, ChatModel chat) {
    final bool isGroup = chat.isGroup;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(
          isGroup ? "Leave Group" : "Delete Chat",
          style:
              TextStyle(color: Theme.of(context).textTheme.titleLarge?.color),
        ),
        content: Text(
          isGroup
              ? "Are you sure you want to leave '${chat.name}'? this action also removes the group from your chats."
              : "Delete conversation with ${chat.name}? This action cannot be undone.",
          style: TextStyle(
            color:
                Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              final chatService = context.read<ChatService>();

              if (isGroup) {
                await chatService.leaveGroup(chat.id);
              } else {
                await chatService.deleteChat(chat.id);
              }

              if (context.mounted) {
                Navigator.pop(context); // Close dialog
              }
            },
            child: Text(
              isGroup ? "Leave" : "Delete",
              style: const TextStyle(
                  color: AppErrorColor, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  List<ChatModel> _getSortedChats(List<ChatModel> chats) {
    final favorites = chats.where((c) => c.isFavorite).toList();
    final regular = chats.where((c) => !c.isFavorite).toList();

    void sortByDate(List<ChatModel> list) {
      list.sort((a, b) {
        // Use lastMessage date, or updatedAt, or current time for new chats
        DateTime dateA =
            a.lastMessage?.createdAt ?? a.updatedAt ?? DateTime.now();
        DateTime dateB =
            b.lastMessage?.createdAt ?? b.updatedAt ?? DateTime.now();
        return dateB.compareTo(dateA);
      });
    }

    sortByDate(favorites);
    sortByDate(regular);
    return [...favorites, ...regular];
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppErrorColor : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check updates from ChatService
    final chatService = context.watch<ChatService>();
    final allServiceChats = chatService.chats;

    // Filter based on search
    final searchQuery = _searchController.text.toLowerCase();
    final filteredChats = searchQuery.isEmpty
        ? allServiceChats
        : allServiceChats
            .where((chat) => chat.name.toLowerCase().contains(searchQuery))
            .toList();

    // Separate archived and active chats
    final archivedCount = filteredChats.where((c) => c.isArchived).length;
    final activeChats = filteredChats.where((c) => !c.isArchived).toList();
    final displayChats = _getSortedChats(activeChats);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              ActionButton(
                  text: 'Create a group',
                  icon: Icons.group_add_outlined,
                  color: AppPrimaryColor,
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const NewGroupScreen()))),
              const SizedBox(height: 15),
              CustomSearchBar(
                controller: _searchController,
                onChanged: (value) => setState(() {}),
                hintText: 'Search chats...',
              ),
              const SizedBox(height: 30),
              const SectionHeader(title: 'Chats'),
              const SizedBox(height: 20),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: AppPrimaryColor))
                    : RefreshIndicator(
                        onRefresh: _loadChats,
                        color: AppPrimaryColor,
                        child: displayChats.isEmpty && archivedCount == 0
                            ? _buildEmptyState()
                            : CustomScrollView(
                                slivers: [
                                  if (archivedCount > 0 &&
                                      _searchController.text.isEmpty)
                                    SliverToBoxAdapter(
                                      child:
                                          _buildArchivedButton(archivedCount),
                                    ),
                                  if (displayChats.isEmpty &&
                                      _searchController.text.isNotEmpty)
                                    _buildNoResultsState()
                                  else
                                    SliverList(
                                      delegate: SliverChildBuilderDelegate(
                                        (context, index) {
                                          final chat = displayChats[index];
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 12.0),
                                            child: ChatTile(
                                              chat: chat,
                                              onTap: () => context.push(
                                                  '/home/chat/${chat.id}'),
                                              onLongPress: () =>
                                                  _showChatOptions(
                                                      context, chat),
                                              onToggleFavorite: () =>
                                                  chatService.updateChatStatus(
                                                      chat.id, {
                                                'isFavorite': !chat.isFavorite
                                              }),
                                              onToggleArchive: () => chatService
                                                  .updateChatStatus(chat.id, {
                                                'isArchived': !chat.isArchived
                                              }),
                                              onDelete: () =>
                                                  _confirmAction(context, chat),
                                              onMore: () => _showChatOptions(
                                                  context, chat),
                                            ),
                                          );
                                        },
                                        childCount: displayChats.length,
                                      ),
                                    ),
                                ],
                              ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArchivedButton(int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: ListTile(
        leading: const Icon(Icons.archive_outlined, color: Colors.grey),
        title: const Text('Archived',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppPrimaryColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('$count',
              style: const TextStyle(
                  color: AppPrimaryColor, fontWeight: FontWeight.bold)),
        ),
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const ArchivedChatsScreen())),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return SliverToBoxAdapter(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            children: [
              Icon(Icons.search_off,
                  size: 64, color: Colors.white.withOpacity(0.3)),
              const SizedBox(height: 16),
              Text('No chats found',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.5), fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        const SizedBox(height: 60),
        Icon(Icons.chat_bubble_outline,
            size: 80, color: Colors.white.withOpacity(0.3)),
        const SizedBox(height: 24),
        Text('No chats yet',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 20,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Text(
              'Start a conversation by creating a group or connecting with friends',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.4), fontSize: 14)),
        ),
      ],
    );
  }
}
