
import 'package:namer_app/models/user.dart';

typedef ChatId = String;
typedef MessageId = String;

class ChatModel {
  final ChatId id;
  final String name;
  final bool isGroup;
  final String? profilePicture;
  bool isMessagingDisabled;
  final List<User> members;
  LastMessage? lastMessage;
  final DateTime? updatedAt;
  bool isTyping;
  int unreadCount;
  bool isFavorite;
  bool isArchived;
  bool isPinned;

  ChatModel({
    required this.id,
    required this.name,
    required this.isGroup,
    this.profilePicture,
    this.isMessagingDisabled = false,
    required this.members,
    this.lastMessage,
    this.updatedAt,
    this.isTyping = false,
    this.unreadCount = 0,
    required this.isFavorite,
    required this.isArchived,
    this.isPinned = false,
  });

  factory ChatModel.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    final membersList = json['members'] != null
        ? (json['members'] as List)
            .map((m) => User.fromJson(m))
            .toList()
        : <User>[];

    String displayName = json['name']?.toString() ?? '';

    if (!json['isGroup'] && displayName.isEmpty && membersList.isNotEmpty) {
      if (currentUserId != null) {
        try {
          final otherMember = membersList.firstWhere(
            (m) => m.id != currentUserId,
            orElse: () => membersList.first,
          );
          displayName =
              (otherMember.displayName != null &&
                      otherMember.displayName!.isNotEmpty)
                  ? otherMember.displayName!
                  : otherMember.username;
        } catch (_) {
          displayName = 'Chat';
        }
      } else {
        displayName = membersList.first.username;
      }
    }

    if (json['isGroup'] && displayName.isEmpty) {
      if (membersList.length <= 3) {
        displayName = membersList.map((m) => m.username).join(', ');
      } else {
        displayName =
            '${membersList.take(2).map((m) => m.username).join(', ')} and ${membersList.length - 2} others';
      }
    }

    return ChatModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: displayName.isEmpty ? 'Unknown Chat' : displayName,
      isGroup: json['isGroup'] ?? false,
      profilePicture: json['profilePicture']?.toString(),
      members: membersList,
      lastMessage: json['lastMessage'] != null
          ? LastMessage.fromJson(json['lastMessage'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
      isTyping: false,
      unreadCount: json['unreadCount'] ?? 0,
      isFavorite: json['isFavorite'] ?? false,
      isArchived: json['isArchived'] ?? false,
      isPinned: json['isPinned'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'isGroup': isGroup,
      'profilePicture': profilePicture,
      'members': members.map((m) => m.toJson()).toList(),
      'lastMessage': lastMessage?.toJson(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isFavorite': isFavorite,
      'isPinned': isPinned,
      'isArchived': isArchived,
    };
  }

  bool get hasUnreadMessages => unreadCount > 0;
  bool get isDirectMessage => !isGroup;
  bool get isActive => !isArchived;
  bool get canSendMessages => !isMessagingDisabled;

  User? getChatPartner(String currentUserId) {
    if (isGroup) return null;
    try {
      return members.firstWhere((m) => m.id != currentUserId);
    } catch (_) {
      return null;
    }
  }

  ChatModel copyWith({
    ChatId? id,
    String? name,
    bool? isGroup,
    String? profilePicture,
    List<User>? members,
    LastMessage? lastMessage,
    DateTime? updatedAt,
    bool? isTyping,
    int? unreadCount,
    bool? isFavorite,
    bool? isArchived,
    bool? isPinned,
  }) {
    return ChatModel(
      id: id ?? this.id,
      name: name ?? this.name,
      isGroup: isGroup ?? this.isGroup,
      profilePicture: profilePicture ?? this.profilePicture,
      members: members ?? this.members,
      lastMessage: lastMessage ?? this.lastMessage,
      updatedAt: updatedAt ?? this.updatedAt,
      isTyping: isTyping ?? this.isTyping,
      unreadCount: unreadCount ?? this.unreadCount,
      isFavorite: isFavorite ?? this.isFavorite,
      isArchived: isArchived ?? this.isArchived,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  factory ChatModel.empty() {
    return ChatModel(
      id: '',
      name: '',
      isGroup: false,
      members: const [],
      isFavorite: false,
      isArchived: false,
      isPinned: false,
    );
  }

  @override
  String toString() {
    return 'ChatModel(id: $id, name: $name, members: ${members.length}, pinned: $isPinned)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatModel && other.id == id && other.isGroup == isGroup;
  }

  @override
  int get hashCode => id.hashCode ^ isGroup.hashCode;
}

class LastMessage {
  final MessageId id;
  final String text;
  final String sender;
  final String status;
  final DateTime createdAt;

  LastMessage({
    required this.id,
    required this.text,
    required this.sender,
    required this.status,
    required this.createdAt,
  });

  LastMessage copyWith({
    MessageId? id,
    String? text,
    String? sender,
    String? status,
    DateTime? createdAt,
  }) {
    return LastMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      sender: sender ?? this.sender,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory LastMessage.fromJson(Map<String, dynamic> json) {
    String textPreview = (json['text'] ?? '').toString();
    if (textPreview.isEmpty) {
      if ((json['imageUrl'] ?? '').toString().isNotEmpty) {
        textPreview = 'Photo';
      } else if ((json['audioUrl'] ?? '').toString().isNotEmpty) {
        textPreview = 'Voice Message';
      }
    }

    return LastMessage(
      id: (json['_id'] ?? '').toString(),
      text: textPreview,
      sender: json['sender'] is Map
          ? (json['sender']['displayName']?.toString() ??
              json['sender']['username']?.toString() ??
              'Unknown')
          : (json['sender']?.toString() ?? 'Unknown'),
      status: (json['status'] ?? 'sent').toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ??
              DateTime.now()
          : DateTime.now(),
    );
  }


  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'text': text,
      'sender': sender,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Safe helpers
  bool get isDelivered => status == 'delivered';
  bool get isRecent =>
      DateTime.now().difference(createdAt).inMinutes < 5;

  @override
  String toString() {
    return 'LastMessage(id: $id, sender: $sender)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LastMessage && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

extension ChatModelExtensions on ChatModel {
  bool get hasMembers => members.isNotEmpty;
}

extension LastMessageExtensions on LastMessage {
  bool get isFromSystem => sender == 'system';
}
