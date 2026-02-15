import 'package:flutter/material.dart';

class LiveTypingPanel extends StatefulWidget {
  /// The map of users currently typing.
  /// Format: { "userId": { "name": "Andre", "draft": "Hello..." } }
  final Map<String, Map<String, String>> typingUsers;

  /// The background color of the panel, matching your AppDarkBackground
  final Color backgroundColor;

  const LiveTypingPanel({
    super.key,
    required this.typingUsers,
    this.backgroundColor = const Color(0xFF121212),
  });

  @override
  State<LiveTypingPanel> createState() => _LiveTypingPanelState();
}

class _LiveTypingPanelState extends State<LiveTypingPanel> {
  String? selectedUserId;
  final ScrollController _textScrollController = ScrollController();

  @override
  void didUpdateWidget(covariant LiveTypingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If the selected user stopped typing, pick the next available one
    if (selectedUserId != null &&
        !widget.typingUsers.containsKey(selectedUserId)) {
      selectedUserId =
          widget.typingUsers.isNotEmpty ? widget.typingUsers.keys.first : null;
    }
    // If no one was selected but someone started typing, select them
    else if (selectedUserId == null && widget.typingUsers.isNotEmpty) {
      selectedUserId = widget.typingUsers.keys.first;
    }

    // "Push Up" Logic: Auto-scroll to the bottom when text updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_textScrollController.hasClients) {
        _textScrollController.animateTo(
          _textScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _textScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.typingUsers.isEmpty) return const SizedBox.shrink();

    // Safety check for selected user data
    final currentData = widget.typingUsers[selectedUserId];
    final String currentDraft = currentData?['draft'] ?? "";

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05), // Subtle glass effect
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          const Text(
            "Currently typing",
            style: TextStyle(
                color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w500),
          ),

          // Horizontal User Bubbles
          SizedBox(
            height: 70,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: widget.typingUsers.length,
              itemBuilder: (context, index) {
                String uid = widget.typingUsers.keys.elementAt(index);
                String name = widget.typingUsers[uid]!['name']!;
                String? profilePic = widget.typingUsers[uid]!['profilePicture'];
                bool isSelected = selectedUserId == uid;

                return GestureDetector(
                  onTap: () => setState(() => selectedUserId = uid),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey,
                            fontSize: 10,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? Colors.purpleAccent
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: _getUserColor(uid),
                            // Verification: Ensure the URL isn't just an empty string
                            backgroundImage: (profilePic != null &&
                                    profilePic.trim().isNotEmpty)
                                ? NetworkImage(profilePic)
                                : null,
                            child: (profilePic == null ||
                                    profilePic.trim().isEmpty)
                                ? Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : "?",
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold),
                                  )
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          //The Live Preview Area (Vertical Scroll)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.all(12),
            constraints: const BoxConstraints(maxHeight: 85),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: SingleChildScrollView(
              controller: _textScrollController,
              child: Text(
                currentDraft,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Helper to generate a consistent color based on User ID
  Color _getUserColor(String userId) {
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.orange,
      Colors.green,
      Colors.yellow[700]!,
      Colors.pink
    ];
    return colors[userId.hashCode % colors.length];
  }
}
