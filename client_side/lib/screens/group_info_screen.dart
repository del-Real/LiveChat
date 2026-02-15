import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/chat.dart';
import '../services/chat_service.dart';
import '../theme/app_colors.dart';

class GroupInfoScreen extends StatefulWidget {
  final ChatModel chat;
  const GroupInfoScreen({super.key, required this.chat});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  bool _isUpdating = false;
  late ChatModel _currentChat;

  @override
  void initState() {
    super.initState();
    _currentChat = widget.chat;
  }

  Future<void> _updatePhoto() async {
    final picker = ImagePicker();

    // Pick the image
    final XFile? pickedFile =
        await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      //Set loading state
      if (mounted) setState(() => _isUpdating = true);

      try {
        final chatService = context.read<ChatService>();

        // Upload the file
        final imageUrl = await chatService.uploadImage(pickedFile);

        if (imageUrl != null) {
          //Update the group information on the server
          final updated = await chatService.updateGroupInfo(
            _currentChat.id,
            profilePicture: imageUrl,
          );

          if (mounted) {
            if (updated != null) {
              setState(() {
                _currentChat = updated;
                _isUpdating = false;
              });

              // Success Feedback
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 10),
                      Text('Group profile picture updated'),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 3),
                ),
              );
            } else {
              // Server update failed
              setState(() => _isUpdating = false);
              _showErrorSnackBar("Failed to update group info.");
            }
          }
        } else {
          // Upload failed
          if (mounted) {
            setState(() => _isUpdating = false);
            _showErrorSnackBar("Upload failed. Verify server is running.");
          }
        }
      } catch (e) {
        // Catch any unexpected errors (network issues, etc.)
        if (mounted) {
          setState(() => _isUpdating = false);
          _showErrorSnackBar("An unexpected error occurred.");
        }
      }
    }
  }

// Helper method to keep code clean
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatService = context.watch<ChatService>();
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final secondaryTextColor = textColor?.withOpacity(0.6);
    final myId = chatService.userId ?? '';
    final partner = _currentChat.isGroup ? null : _currentChat.getChatPartner(myId);
    final isBlocked = partner != null && chatService.blockedUsers.contains(partner.id);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_currentChat.isGroup ? 'Group Info' : 'User Info',
            style: TextStyle(
                color: Theme.of(context).appBarTheme.foregroundColor)),
        iconTheme:
            IconThemeData(color: Theme.of(context).appBarTheme.foregroundColor),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 70,
                  backgroundColor: AppPrimaryColor,
                  backgroundImage: (_currentChat.profilePicture != null &&
                          _currentChat.profilePicture!.isNotEmpty)
                      ? NetworkImage(_currentChat.profilePicture!)
                      : (partner?.profilePicture != null && partner!.profilePicture!.isNotEmpty)
                        ? NetworkImage(partner.profilePicture!)
                        : null,
                  child: (_currentChat.profilePicture == null ||
                          _currentChat.profilePicture!.isEmpty) && (partner?.profilePicture == null || partner!.profilePicture!.isEmpty)
                      ? Icon(_currentChat.isGroup ? Icons.group : Icons.person, size: 70, color: Colors.white)
                      : null,
                ),
                if (_currentChat.isGroup)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      backgroundColor: AppPrimaryColor,
                      radius: 20,
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt,
                            color: Colors.white, size: 20),
                        onPressed: _updatePhoto,
                      ),
                    ),
                  ),
                if (_isUpdating)
                  const Positioned.fill(
                      child: Center(
                          child:
                              CircularProgressIndicator(color: Colors.white))),
              ],
            ),
          ),
          const SizedBox(height: 25),
          Center(
            child: Text(
              _currentChat.isGroup ? _currentChat.name : (partner?.resolvedName ?? 'Unknown'),
              style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.bold, color: textColor),
            ),
          ),
          if (!_currentChat.isGroup && partner != null)
            Center(
              child: Text(
                partner.email,
                style: TextStyle(color: secondaryTextColor, fontSize: 16),
              ),
            ),
          const SizedBox(height: 40),
          if (_currentChat.isGroup) ...[
            Text('MEMBERS (${_currentChat.members.length})',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: secondaryTextColor,
                    fontSize: 13)),
            const Divider(),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _currentChat.members.length,
              itemBuilder: (context, index) {
                final member = _currentChat.members[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppPrimaryColor,
                    backgroundImage: (member.profilePicture != null &&
                            member.profilePicture!.isNotEmpty)
                        ? NetworkImage(member.profilePicture!)
                        : null,
                    child: (member.profilePicture == null ||
                            member.profilePicture!.isEmpty)
                        ? Text(member.username[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white))
                        : null,
                  ),
                  title: Text(member.displayName ?? member.username,
                      style: TextStyle(
                          color: textColor, fontWeight: FontWeight.w600)),
                  subtitle: Text(member.email,
                      style: TextStyle(color: secondaryTextColor, fontSize: 12)),
                );
              },
            ),
          ] else if (partner != null) ...[
            const Divider(),
            ListTile(
              leading: Icon(isBlocked ? Icons.check_circle : Icons.block, 
                           color: isBlocked ? Colors.green : Colors.red),
              title: Text(isBlocked ? 'Unblock User' : 'Block User',
                         style: TextStyle(color: isBlocked ? Colors.green : Colors.red)),
              onTap: () async {
                if (isBlocked) {
                  await chatService.unblockUser(partner.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User unblocked')),
                  );
                } else {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Block User?'),
                      content: const Text('Blocked users cannot send you messages or see your status.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Block', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await chatService.blockUser(partner.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('User blocked')),
                    );
                  }
                }
              },
            ),
            const Divider(),
          ],
        ],
      ),
    );
  }
}
