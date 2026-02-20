import 'package:flutter/material.dart';
import 'package:namer_app/theme/app_colors.dart';

class MessageBubble extends StatelessWidget {
  final bool isMe;
  final String message;
  final String? senderName;
  final String? imageUrl;
  final String time;
  final String status;
  final VoidCallback? onLongPress;
  final bool isSystemMessage;

  const MessageBubble({
    super.key,
    required this.isMe,
    required this.message,
    this.senderName,
    this.imageUrl,
    required this.time,
    required this.status,
    this.onLongPress,
    this.isSystemMessage = false,
  });

  Widget _buildStatusIcon(String status) {
    switch (status) {
      case 'sent':
        return const Icon(Icons.done, size: 14, color: Colors.grey);
      case 'delivered':
        return const Icon(Icons.done_all, size: 14, color: Colors.grey);
      case 'seen':
        return const Icon(Icons.done_all, size: 14, color: AppPrimaryColor);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Special rendering for system messages
    if (isSystemMessage) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message,
            style: TextStyle(
              color: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.color
                  ?.withOpacity(0.7),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Regular message rendering
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe && senderName != null)
              Padding(
                padding: const EdgeInsets.only(left: 18, bottom: 2),
                child: Text(
                  senderName!,
                  style: const TextStyle(
                    color: AppPrimaryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (imageUrl != null && imageUrl!.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      padding: const EdgeInsets.all(20),
                      color: Colors.grey[800],
                      child:
                          const Icon(Icons.broken_image, color: Colors.white54),
                    ),
                  ),
                ),
              ),
            if (message.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                padding: const EdgeInsets.all(12),
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75),
                decoration: BoxDecoration(
                  color: isMe
                      ? AppPrimaryColor
                      : (Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[800]
                          : Colors.grey[200]),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                    bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                  ),
                ),
                child: Text(
                  message,
                  style: TextStyle(
                      color: isMe
                          ? Colors.white
                          : Theme.of(context).textTheme.bodyLarge?.color,
                      fontSize: 15,
                      height: 1.3),
                ),
              ),
            Padding(
              padding: EdgeInsets.only(
                  left: isMe ? 0 : 20, right: isMe ? 20 : 0, bottom: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(time,
                      style: const TextStyle(color: Colors.grey, fontSize: 10)),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    _buildStatusIcon(status),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TypingIndicatorBubble extends StatelessWidget {
  final String draft;
  final String sender;

  const TypingIndicatorBubble(
      {super.key, required this.draft, required this.sender});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20, bottom: 4),
            child: Text(
              '$sender is typing...',
              style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                  fontStyle: FontStyle.italic),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(left: 14, right: 80, bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.zero,
              ),
              border: Border.all(color: Colors.white10),
            ),
            child: Text(
              draft,
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
