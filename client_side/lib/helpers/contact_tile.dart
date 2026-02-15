import 'package:flutter/material.dart';
import '../models/contact.dart';
import '../theme/app_colors.dart';

class ContactTile extends StatelessWidget {
  final ContactModel contact;
  final VoidCallback onChat;
  final VoidCallback onToggleFavorite;
  final VoidCallback onDelete;
  final VoidCallback onMore;
  final VoidCallback? onLongPress;

  const ContactTile({
    super.key,
    required this.contact,
    required this.onChat,
    required this.onToggleFavorite,
    required this.onDelete,
    required this.onMore,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final bool isLargeScreen = MediaQuery.of(context).size.width > 500;

    return Dismissible(
      key: Key(contact.id),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onToggleFavorite();
          return false;
        } else {
          onDelete();
          return false;
        }
      },
      background: _buildSwipeBackground(
        color: Colors.yellow.withOpacity(0.8),
        icon: contact.isFavorite ? Icons.star_border : Icons.star,
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _buildSwipeBackground(
        color: AppErrorColor,
        icon: Icons.delete,
        alignment: Alignment.centerRight,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          onTap: onChat,
          onLongPress: onLongPress,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            radius: 24, 
            backgroundColor: AppPrimaryColor,
            backgroundImage: (contact.contact.profilePicture != null && 
                              contact.contact.profilePicture!.isNotEmpty)
                ? NetworkImage(contact.contact.profilePicture!)
                : null,
            child: (contact.contact.profilePicture == null || 
                    contact.contact.profilePicture!.isEmpty)
                ? Text(
                    contact.contact.username[0].toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white, 
                        fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          title: Row(
            children: [
              Text(
                contact.contact.displayName ?? contact.contact.username,
                style: TextStyle(
                  color: Theme.of(context).textTheme.titleMedium?.color,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (contact.isFavorite) ...[
                const SizedBox(width: 6),
                const Icon(Icons.star, color: Colors.yellow, size: 16),
              ],
            ],
          ),
          subtitle: Text(
            contact.contact.displayName != null 
                ? "@${contact.contact.username} • ${contact.contact.email}"
                : contact.contact.email,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
              fontSize: 12,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: onChat,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPrimaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Chat'),
              ),
              if (isLargeScreen) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    contact.isFavorite ? Icons.star : Icons.star_border,
                    color: contact.isFavorite ? Colors.yellow : Colors.grey,
                  ),
                  onPressed: onToggleFavorite,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppErrorColor),
                  onPressed: onDelete,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwipeBackground(
      {required Color color,
      required IconData icon,
      required Alignment alignment}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: alignment,
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: Colors.white),
    );
  }
}