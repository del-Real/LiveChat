import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../theme/app_colors.dart';

class MessageBubble extends StatelessWidget {
  final bool isMe;
  final String message;
  final String? senderName;
  final String? imageUrl;
  final String? audioUrl; // Add audioUrl
  final String time;
  final String status;
  final VoidCallback? onLongPress;
  final bool isSystemMessage;
  final bool isEdited;
  final bool isPinned;

  const MessageBubble({
    super.key,
    required this.isMe,
    required this.message,
    this.senderName,
    this.imageUrl,
    this.audioUrl, // Add to constructor
    required this.time,
    required this.status,
    this.onLongPress,
    this.isSystemMessage = false,
    this.isEdited = false,
    this.isPinned = false,
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
    if (isSystemMessage) {
       // ... (existing system message logic)
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
            
            // Audio Message
            if (audioUrl != null && audioUrl!.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                 constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75),
                decoration: BoxDecoration(
                  color: isMe
                      ? AppPrimaryColor
                      : (Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[800]
                          : Colors.grey[200]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: VoiceMessageBubble(audioUrl: audioUrl!, isMe: isMe),
              ),

            // Image Message
            if (imageUrl != null && imageUrl!.isNotEmpty)
              // ... (existing image logic)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7),
                child: Stack(
                  children: [
                    ClipRRect(
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
                          child: const Icon(Icons.broken_image,
                              color: Colors.white54),
                        ),
                      ),
                    ),
                    if (isPinned)
                      const Positioned(
                        right: 8,
                        top: 8,
                        child: Icon(Icons.push_pin,
                            color: Colors.orange, size: 20),
                      ),
                  ],
                ),
              ),


            // Text Message
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
                  border: isPinned
                      ? Border.all(
                          color: Colors.orange.withOpacity(0.5), width: 1.5)
                      : null,
                  boxShadow: isPinned
                      ? [
                          BoxShadow(
                              color: Colors.orange.withOpacity(0.1),
                              blurRadius: 4,
                              spreadRadius: 1)
                        ]
                      : null,
                ),
                child: Stack(
                  children: [
                    Padding(
                      padding: EdgeInsets.only(
                          right: isPinned ? 24 : 0, bottom: 4),
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
                    if (isPinned)
                      const Positioned(
                        right: 0,
                        top: 0,
                        child: Icon(Icons.push_pin,
                            color: Colors.orange, size: 14),
                      ),
                  ],
                ),
              ),
            
            // Time and Status
             Padding(
              padding: EdgeInsets.only(
                  left: isMe ? 0 : 20, right: isMe ? 20 : 0, bottom: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isPinned) ...[
                    const Icon(Icons.push_pin, color: Colors.orange, size: 14),
                    const SizedBox(width: 4),
                  ],
                  if (isEdited) ...[
                    const Text('edited ',
                        style: TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                            fontStyle: FontStyle.italic)),
                  ],
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

class VoiceMessageBubble extends StatefulWidget {
  final String audioUrl;
  final bool isMe;

  const VoiceMessageBubble(
      {super.key, required this.audioUrl, required this.isMe});

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();

    // Listen to state changes
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    // Listen to duration changes
    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) {
        setState(() {
          _duration = newDuration;
        });
      }
    });

    // Listen to position changes
    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) {
        setState(() {
          _position = newPosition;
        });
      }
    });
    
    // Set source
    _audioPlayer.setSource(UrlSource(widget.audioUrl));

  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}:${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
    }
    return '${d.inMinutes}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isMe ? Colors.white : Theme.of(context).primaryColor;
    
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
              color: color,
              size: 30,
            ),
            onPressed: () async {
              if (_isPlaying) {
                await _audioPlayer.pause();
              } else {
                 await _audioPlayer.play(UrlSource(widget.audioUrl));
              }
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Slider(
                    min: 0,
                    max: _duration.inSeconds.toDouble(),
                    value: _position.inSeconds.toDouble().clamp(0, _duration.inSeconds.toDouble()),
                    activeColor: color,
                    inactiveColor: color.withOpacity(0.3),
                    onChanged: (value) async {
                      final position = Duration(seconds: value.toInt());
                      await _audioPlayer.seek(position);
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 12.0),
                    child: Text(
                       '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                       style: TextStyle(color: color.withOpacity(0.7), fontSize: 10),
                    ),
                  ),
              ],
            ),
          ),

        ],
      ),
    );
  }
}

// ... (existing TypingIndicatorBubble)
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

