import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/chat.dart';
import '../theme/app_colors.dart';
import '../services/chat_service.dart';

class ChatTile extends StatelessWidget {
  final ChatModel chat;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final VoidCallback onToggleArchive;
  final VoidCallback onDelete;
  final VoidCallback onMore;
  final VoidCallback? onLongPress;

  const ChatTile({
    super.key,
    required this.chat,
    required this.onTap,
    required this.onToggleFavorite,
    required this.onToggleArchive,
    required this.onDelete,
    required this.onMore,
    this.onLongPress,
  });

  String _formatMessageTime(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);
    final difference = today.difference(messageDate).inDays;

    if (difference == 0) {
      return DateFormat('hh:mm a').format(date);
    } else if (difference < 7) {
      return DateFormat('EEEE').format(date);
    } else {
      return DateFormat('yyyy-MM-dd').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLargeScreen = MediaQuery.of(context).size.width > 500;
    final lastMsg = chat.lastMessage;

    final chatService = context.watch<ChatService>();
    final myId = chatService.userId ?? '';
    bool isOnline = false;

    if (!chat.isGroup) {
      final partner = chat.getChatPartner(myId);
      if (partner != null) {
        isOnline = chatService.userPresence[partner.id] ?? false;
      }
    }

    return Dismissible(
      key: Key('chat_tile_${chat.id}'),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onToggleFavorite();
        } else {
          onToggleArchive();
        }
        return false;
      },
      background: _buildSwipeBackground(
        color: Colors.teal.withOpacity(0.8),
        icon: chat.isFavorite ? Icons.push_pin_outlined : Icons.push_pin,
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _buildSwipeBackground(
        color: Colors.blue.withOpacity(0.8),
        icon: chat.isArchived ? Icons.unarchive : Icons.archive,
        alignment: Alignment.centerRight,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: chat.unreadCount > 0
              ? AppPrimaryColor.withOpacity(0.1)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          onTap: onTap,
          onLongPress: onLongPress,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: _buildAvatar(context, isOnline),
          title: _buildTitle(context, lastMsg),
          subtitle: _buildSubtitle(context, lastMsg),
          trailing: _buildTrailing(context, isLargeScreen),
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, bool isOnline) {
  final myId = context.read<ChatService>().userId ?? '';
  final partner = chat.getChatPartner(myId);

  String? imageUrl;
  if (chat.isGroup) {
    imageUrl = chat.profilePicture; 
  } else {
    imageUrl = partner?.profilePicture; 
  }

  return Stack(
    children: [
      CircleAvatar(
        radius: 28,
        backgroundColor: AppPrimaryColor,
        backgroundImage: (imageUrl != null && imageUrl.isNotEmpty)
            ? NetworkImage(imageUrl)
            : null,
        child: (imageUrl == null || imageUrl.isEmpty)
            ? Text(chat.name[0].toUpperCase(),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold))
            : null,
      ),
      if (!chat.isGroup)
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: isOnline ? AppSuccessColor : Colors.grey,
              shape: BoxShape.circle,
              border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor, width: 2),
            ),
          ),
        ),
    ],
  );
}

  Widget _buildTitle(BuildContext context, LastMessage? lastMsg) {
    return Row(
      children: [
        Expanded(
          child: Text(chat.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: Theme.of(context).textTheme.titleMedium?.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
        ),
        if (lastMsg != null)
          Text(
            _formatMessageTime(lastMsg.createdAt),
            style: TextStyle(
                color: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.color
                    ?.withOpacity(0.5),
                fontSize: 12),
          ),
      ],
    );
  }

  Widget _buildSubtitle(BuildContext context, LastMessage? lastMsg) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Row(
        children: [
          if (chat.isTyping)
            const Text('typing...',
                style: TextStyle(
                    color: AppPrimaryColor,
                    fontStyle: FontStyle.italic,
                    fontSize: 14))
          else
            Expanded(
              child: Text(
                lastMsg?.text ?? 'No messages yet',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.color
                        ?.withOpacity(0.6),
                    fontSize: 14),
              ),
            ),
          if (chat.isFavorite)
            const Icon(Icons.push_pin, color: Colors.tealAccent, size: 14),
          if (chat.isArchived)
            const Icon(Icons.archive, color: Colors.blue, size: 14),
        ],
      ),
    );
  }

  Widget _buildTrailing(BuildContext context, bool isLargeScreen) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (isLargeScreen)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                  icon: Icon(
                      chat.isFavorite ? Icons.push_pin : Icons.push_pin_outlined,
                      color: Colors.tealAccent),
                  onPressed: onToggleFavorite),
              IconButton(
                  icon: Icon(chat.isArchived ? Icons.unarchive : Icons.archive,
                      color: Colors.blue),
                  onPressed: onToggleArchive),
              IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppErrorColor),
                  onPressed: onDelete),
            ],
          ),
        if (chat.unreadCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppPrimaryColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${chat.unreadCount}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }

  Widget _buildSwipeBackground(
      {required Color color,
      required IconData icon,
      required Alignment alignment}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: alignment,
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
      child: Icon(icon, color: Colors.white, size: 28),
    );
  }
}