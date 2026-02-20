import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../services/chat_service.dart';
import '../theme/app_colors.dart';
import '../helpers/chat_widgets.dart';
import '../helpers/live_typing_panel.dart';
import '../models/chat.dart';
import 'add_members_screen.dart';
import 'group_info_screen.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  const ChatScreen({super.key, required this.chatId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  ChatService? _chatService;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = context.read<ChatService>();
      service.joinRoom(widget.chatId);
      service.fetchMessages(widget.chatId);
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 20) {
      final service = Provider.of<ChatService>(context, listen: false);
      if (service.hasMore && !service.isLoading) {
        service.fetchMessages(widget.chatId, isLoadMore: true);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chatService = Provider.of<ChatService>(context, listen: false);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _chatService?.leaveChat(widget.chatId);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessageAction(ChatService chatService) {
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      chatService.sendMessage(widget.chatId, text);
      _messageController.clear();
      chatService.sendTypingUpdate(widget.chatId, "");

      if (_scrollController.hasClients) {
        _scrollController.animateTo(0.0,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    }
  }

  Future<void> _pickAndSendImage(ChatService chatService) async {
    final picker = ImagePicker();
    final XFile? pickedFile =
        await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final imageUrl = await chatService.uploadImage(XFile(pickedFile.path));

      if (imageUrl != null) {
        chatService.sendMessage(widget.chatId, "", imageUrl: imageUrl);
      }
    }
  }

  void _showDeleteDialog(BuildContext context, String messageId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text("Delete message?",
            style: TextStyle(
                color: Theme.of(context).textTheme.titleLarge?.color)),
        content: Text("This message will be deleted for everyone.",
            style: TextStyle(
                color: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withOpacity(0.7))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text("Cancel", style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () {
              context
                  .read<ChatService>()
                  .deleteMessage(messageId, widget.chatId);
              Navigator.pop(context);
            },
            child: const Text("Delete", style: TextStyle(color: AppErrorColor)),
          ),
        ],
      ),
    );
  }

  void _showLeaveGroupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(
          "Leave Group?",
          style:
              TextStyle(color: Theme.of(context).textTheme.titleLarge?.color),
        ),
        content: Text(
          "Are you sure you want to leave this group? You can only rejoin if someone adds you back and this action also removes the group from your chats.",
          style: TextStyle(
              color: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.color
                  ?.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              final chatService = context.read<ChatService>();
              final success = await chatService.leaveGroup(widget.chatId);

              if (mounted) {
                if (success) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Left group successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to leave group'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text(
              "Leave",
              style:
                  TextStyle(color: AppErrorColor, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatService = context.watch<ChatService>();
    final isConnected = chatService.socket?.connected == true;
    final messages = chatService.messages;
    final String myId = chatService.userId ?? '';

    final chat = chatService.chats.firstWhere(
      (c) => c.id == widget.chatId,
      orElse: () {
        return ChatModel(
          id: widget.chatId,
          name: 'Chat',
          isGroup: false,
          members: [],
          isFavorite: false,
          isArchived: false,
        );
      },
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        iconTheme:
            IconThemeData(color: Theme.of(context).appBarTheme.foregroundColor),
        title: _ChatAppBarTitle(isConnected: isConnected, chat: chat),
        actions: [
          if (chat.isGroup)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              iconColor: Theme.of(context).appBarTheme.foregroundColor,
              color: Theme.of(context).cardColor,
              onSelected: (value) {
                if (value == 'add_members') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddMembersScreen(chat: chat),
                    ),
                  );
                } else if (value == 'leave_group') {
                  _showLeaveGroupDialog(context);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'add_members',
                  child: Row(
                    children: [
                      Icon(Icons.person_add_alt_1,
                          color: Theme.of(context)
                              .iconTheme
                              .color
                              ?.withOpacity(0.7)),
                      const SizedBox(width: 12),
                      Text('Add Members',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.color)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'leave_group',
                  child: Row(
                    children: [
                      Icon(Icons.exit_to_app, color: AppErrorColor),
                      SizedBox(width: 12),
                      Text('Leave Group',
                          style: TextStyle(color: AppErrorColor)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              reverse: true,
              itemCount: messages.length + (chatService.hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == messages.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                }
                final msg = messages[index];
                final bool isMe = msg.senderId == myId;

                // Detect system messages
                final bool isSystemMessage =
                    msg.text.contains('left the group') ||
                        msg.text.contains('added to the group') ||
                        msg.text.contains('was added to the group') ||
                        msg.text.contains('were added to the group');

                return MessageBubble(
                  isMe: isMe,
                  message: msg.text,
                  senderName: chat.isGroup
                      ? (msg.senderName ?? _getMemberName(chat, msg.senderId))
                      : null,
                  imageUrl: msg.imageUrl,
                  time: msg.timestamp,
                  status: msg.status,
                  isSystemMessage: isSystemMessage,
                  onLongPress:
                      isMe ? () => _showDeleteDialog(context, msg.id) : null,
                );
              },
            ),
          ),
          LiveTypingPanel(typingUsers: chatService.typingUsers),
          if (chat.isMessagingDisabled)
            _buildDisabledBanner(context)
          else
            _ChatInputBar(
              controller: _messageController,
              onChanged: (text) =>
                  chatService.sendTypingUpdate(widget.chatId, text),
              onSend: () => _sendMessageAction(chatService),
              onAdd: () => _pickAndSendImage(chatService),
            ),
        ],
      ),
    );
  }

  String _getMemberName(ChatModel chat, String senderId) {
    try {
      final member = chat.members.firstWhere((m) => m.id == senderId);
      return member.displayName ?? member.username;
    } catch (e) {
      return "User";
    }
  }
}

Widget _buildDisabledBanner(BuildContext context) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
    ),
    child: Column(
      children: [
        Icon(Icons.lock_outline,
            color:
                Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.5),
            size: 20),
        const SizedBox(height: 8),
        Text(
          "Messaging is disabled for this chat",
          style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontSize: 14),
        ),
        Text(
          "You must be contacts to send messages.",
          style: TextStyle(
              color: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.color
                  ?.withOpacity(0.6),
              fontSize: 12),
        ),
      ],
    ),
  );
}

class _ChatAppBarTitle extends StatelessWidget {
  final bool isConnected;
  final ChatModel chat;
  const _ChatAppBarTitle({required this.isConnected, required this.chat});

  void _showProfilePicture(
      BuildContext context, String? imageUrl, String name) {
    if (imageUrl == null || imageUrl.isEmpty) return;

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Close button
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            // Profile picture
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: 300,
                          height: 300,
                          alignment: Alignment.center,
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            color: AppPrimaryColor,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 300,
                        height: 300,
                        alignment: Alignment.center,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image,
                                size: 64, color: Colors.white54),
                            SizedBox(height: 16),
                            Text(
                              'Failed to load image',
                              style: TextStyle(color: Colors.white54),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatService = context.watch<ChatService>();
    final myId = chatService.userId ?? '';
    final bool isGroup = chat.isGroup;
    final partner = isGroup ? null : chat.getChatPartner(myId);

    final bool isPartnerOnline = !isGroup &&
        partner != null &&
        (chatService.userPresence[partner.id] ?? false);

    final bool isConnecting = !isConnected;

    String statusText = '';
    Color statusColor = Colors.transparent;

    if (isConnecting) {
      statusText = 'Connecting...';
      statusColor = AppErrorColor;
    } else if (!isGroup) {
      statusText = isPartnerOnline ? 'Online' : 'Offline';
      statusColor = isPartnerOnline ? AppSuccessColor : Colors.grey;
    } else {
      statusText = '${chat.members.length} members';
      statusColor = Colors.grey;
    }

    final String? profilePictureUrl =
        chat.isGroup ? chat.profilePicture : partner?.profilePicture;

    return Row(
      children: [
        // Avatar - tappable to show profile picture
        GestureDetector(
          onTap: () {
            if (profilePictureUrl != null && profilePictureUrl.isNotEmpty) {
              _showProfilePicture(context, profilePictureUrl, chat.name);
            } else if (chat.isGroup) {
              // If no profile picture but is group, go to group info
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GroupInfoScreen(chat: chat),
                ),
              );
            }
          },
          child: CircleAvatar(
            radius: 18,
            backgroundColor: AppPrimaryColor,
            backgroundImage:
                (profilePictureUrl != null && profilePictureUrl.isNotEmpty)
                    ? NetworkImage(profilePictureUrl)
                    : null,
            child: (profilePictureUrl == null || profilePictureUrl.isEmpty)
                ? Text(
                    chat.name.isNotEmpty ? chat.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                  )
                : null,
          ),
        ),
        const SizedBox(width: 12),
        // Name and status - tappable only for groups to go to group info
        Expanded(
          child: GestureDetector(
            onTap: () {
              if (chat.isGroup) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GroupInfoScreen(chat: chat),
                  ),
                );
              }
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chat.name,
                  style: TextStyle(
                      color: Theme.of(context).appBarTheme.foregroundColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle, color: statusColor),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onChanged;
  final VoidCallback onSend;
  final VoidCallback onAdd;

  const _ChatInputBar({
    required this.controller,
    required this.onChanged,
    required this.onSend,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      color: Theme.of(context).appBarTheme.backgroundColor,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline,
                color: AppPrimaryColor, size: 28),
            onPressed: onAdd,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: controller,
              style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color),
              onChanged: onChanged,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(color: Theme.of(context).hintColor),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: AppPrimaryColor,
            radius: 22,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: onSend,
            ),
          ),
        ],
      ),
    );
  }
}
