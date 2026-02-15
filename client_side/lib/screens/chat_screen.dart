import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../services/chat_service.dart';
import '../theme/app_colors.dart';
import '../helpers/chat_widgets.dart';
import '../helpers/live_typing_panel.dart';
import '../models/chat.dart';
import '../models/user.dart';
import '../models/message.dart';
import 'add_members_screen.dart';
import 'group_info_screen.dart';
import '../helpers/voice_recorder.dart';


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
  Timer? _statusRefreshTimer;
  bool _showRecorder = false;


  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // Refresh last seen status every 60 seconds
    _statusRefreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });

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
    _statusRefreshTimer?.cancel();
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

  void _showOptionsSheet(BuildContext context, MessageModel msg) {
    final bool isMe =
        msg.senderId == context.read<ChatService>().userId;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                  msg.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  color: Colors.orange),
              title: Text(msg.isPinned ? "Unpin Message" : "Pin Message"),
              onTap: () {
                Navigator.pop(context);
                final wasPinned = msg.isPinned;
                context
                    .read<ChatService>()
                    .togglePinnedMessage(widget.chatId, msg.id);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(wasPinned
                        ? "Message unpinned"
                        : "Message pinned to top"),
                    duration: const Duration(seconds: 2),
                    backgroundColor: Colors.orange,
                  ),
                );
              },
            ),
            if (isMe) ...[
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text("Edit Message"),
                onTap: () {
                  Navigator.pop(context);
                  _showEditDialog(context, msg);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppErrorColor),
                title: const Text("Delete Message",
                    style: TextStyle(color: AppErrorColor)),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteDialog(context, msg.id);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, MessageModel msg) {
    final TextEditingController editController =
        TextEditingController(text: msg.text);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: const Text("Edit Message"),
        content: TextField(
          controller: editController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "Enter new message...",
          ),
          maxLines: null,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              final newText = editController.text.trim();
              if (newText.isNotEmpty && newText != msg.text) {
                context
                    .read<ChatService>()
                    .editMessage(msg.id, widget.chatId, newText);
              }
              Navigator.pop(context);
            },
            child: const Text("Save",
                style: TextStyle(
                    color: AppPrimaryColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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

    final partner = chat.isGroup ? null : chat.getChatPartner(myId);
    final isBlocked =
        partner != null && chatService.blockedUsers.contains(partner.id);

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
          if (chatService.pinnedMessages.isNotEmpty)
            InkWell(
              onTap: () {
                final msg = chatService.pinnedMessages.first;
                final index =
                    chatService.messages.indexWhere((m) => m.id == msg.id);
                if (index != -1) {
                  _scrollController.animateTo(
                    index * 100.0, // Fixed height estimate for simplicity
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  border: Border(
                    bottom: BorderSide(
                        color: Theme.of(context).dividerColor.withOpacity(0.1)),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.push_pin, color: Colors.orange, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Pinned Message",
                              style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                          Text(
                            chatService.pinnedMessages.first.text.isEmpty
                                ? "Photo"
                                : chatService.pinnedMessages.first.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.color
                                    ?.withOpacity(0.7),
                                fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () {
                        chatService.togglePinnedMessage(
                            widget.chatId, chatService.pinnedMessages.first.id);
                      },
                    ),
                  ],
                ),
              ),
            ),
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
                  audioUrl: msg.audioUrl,
                  time: msg.timestamp,

                  status: msg.status,
                  isSystemMessage: isSystemMessage,
                  isEdited: msg.isEdited,
                  isPinned: msg.isPinned,
                  onLongPress: () => _showOptionsSheet(context, msg),
                );
              },
            ),
          ),
          LiveTypingPanel(typingUsers: chatService.typingUsers),
          if (chat.isMessagingDisabled)
            _buildDisabledBanner(context)
          else if (isBlocked)
            _buildBlockedBanner(context, partner, chatService)
          else if (_showRecorder)
            VoiceRecorder(
              onStop: (path) async {
                setState(() => _showRecorder = false);
                final audioUrl = await chatService.uploadAudio(path);
                if (audioUrl != null) {
                  chatService.sendMessage(widget.chatId, "",
                      audioUrl: audioUrl);
                }
              },
              onCancel: () => setState(() => _showRecorder = false),
            )
          else
            _ChatInputBar(
              controller: _messageController,
              onChanged: (text) =>
                  chatService.sendTypingUpdate(widget.chatId, text),
              onSend: () => _sendMessageAction(chatService),
              onAdd: () => _pickAndSendImage(chatService),
              onRecordStart: () => setState(() => _showRecorder = true),
            ),

        ],
      ),
    );
  }

  Widget _buildBlockedBanner(
      BuildContext context, User partner, ChatService chatService) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        children: [
          const Icon(Icons.block, color: Colors.red, size: 24),
          const SizedBox(height: 12),
          Text(
            "You have blocked this user",
            style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: FontWeight.bold,
                fontSize: 14),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => chatService.unblockUser(partner.id),
            child: const Text("Unblock to send messages"),
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

      if (!isPartnerOnline && partner != null) {
        var lastSeen = chatService.userLastSeen[partner.id];
        if (lastSeen != null) {
          // Ensure we are comparing local time to local time
          if (lastSeen.isUtc) {
            lastSeen = lastSeen.toLocal();
          }
          final now = DateTime.now();
          final diff = now.difference(lastSeen);

          if (diff.inMinutes < 1) {
            statusText = 'Last seen just now';
          } else if (diff.inMinutes < 60) {
            statusText = 'Last seen ${diff.inMinutes}m ago';
          } else if (diff.inHours < 24) {
            statusText = 'Last seen ${diff.inHours}h ago';
          } else {
            statusText = 'Last seen ${DateFormat('MMM d, HH:mm').format(lastSeen)}';
          }
        }
      }
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
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GroupInfoScreen(chat: chat),
                ),
              );
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
  final VoidCallback onRecordStart;


  const _ChatInputBar({
    required this.controller,
    required this.onChanged,
    required this.onSend,
    required this.onAdd,
    required this.onRecordStart,
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
                suffixIcon: IconButton(
                  icon: const Icon(Icons.mic_none_rounded, color: AppPrimaryColor),
                  onPressed: onRecordStart,
                ),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, child) {
              final isTextEmpty = value.text.trim().isEmpty;
              if (isTextEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: CircleAvatar(
                  backgroundColor: AppPrimaryColor,
                  radius: 22,
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    onPressed: onSend,
                  ),
                ),
              );
            },
          ),




        ],
      ),
    );
  }
}
