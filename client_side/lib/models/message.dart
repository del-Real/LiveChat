
typedef MessageId = String;
typedef UserId = String;

class MessageModel {
  final MessageId id;
  final UserId senderId;
  final String? senderName;
  String text;
  final String imageUrl;
  final String audioUrl;
  final String timestamp; // For display
  final String rawTimestamp; // For pagination
  String status;
  bool isEdited;
  bool isPinned;

  MessageModel({
    required this.id,
    required this.senderId,
    this.senderName,
    required this.text,
    required this.imageUrl,
    this.audioUrl = '',
    required this.timestamp,
    required this.rawTimestamp,
    required this.status,
    this.isEdited = false,
    this.isPinned = false,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final rawDate = json['createdAt'] ?? '';

    String? name;
    if (json['sender'] is Map) {
      name = json['sender']['displayName'] ??
          json['sender']['username'];
    }

    return MessageModel(
      id: (json['_id'] ?? '').toString(),
      senderId: json['sender'] is Map
          ? json['sender']['_id'].toString()
          : (json['sender'] ??
                  json['senderId'] ??
                  '')
              .toString(),
      senderName: name,
      text: (json['text'] ?? '').toString(),
      imageUrl: (json['imageUrl'] ?? '').toString(),
      audioUrl: (json['audioUrl'] ?? '').toString(),
      status: (json['status'] ?? 'sent').toString(),
      isEdited: json['isEdited'] ?? false,
      isPinned: json['isPinned'] ?? false,
      rawTimestamp: rawDate,
      timestamp: rawDate.isNotEmpty
          ? DateTime.parse(rawDate)
              .toLocal()
              .toString()
              .substring(11, 16)
          : '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'imageUrl': imageUrl,
      'audioUrl': audioUrl,
      'timestamp': timestamp,
      'rawTimestamp': rawTimestamp,
      'status': status,
      'isEdited': isEdited,
      'isPinned': isPinned,
    };
  }

  bool get hasText => text.isNotEmpty;
  bool get hasImage => imageUrl.isNotEmpty;
  bool get hasAudio => audioUrl.isNotEmpty;

  bool get isSent => status == 'sent';
  bool get isDelivered => status == 'delivered';
  bool get isRead => status == 'read';

  bool get isEmptyMessage => text.isEmpty && imageUrl.isEmpty && audioUrl.isEmpty;

  DateTime? get parsedDate {
    if (rawTimestamp.isEmpty) return null;
    try {
      return DateTime.parse(rawTimestamp).toLocal();
    } catch (_) {
      return null;
    }
  }

  bool get isRecent {
    final date = parsedDate;
    if (date == null) return false;
    return DateTime.now().difference(date).inMinutes < 5;
  }

  MessageModel copyWith({
    MessageId? id,
    UserId? senderId,
    String? senderName,
    String? text,
    String? imageUrl,
    String? audioUrl,
    String? timestamp,
    String? rawTimestamp,
    String? status,
    bool? isEdited,
    bool? isPinned,
  }) {
    return MessageModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      text: text ?? this.text,
      imageUrl: imageUrl ?? this.imageUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      timestamp: timestamp ?? this.timestamp,
      rawTimestamp: rawTimestamp ?? this.rawTimestamp,
      status: status ?? this.status,
      isEdited: isEdited ?? this.isEdited,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  factory MessageModel.empty() {
    return MessageModel(
      id: '',
      senderId: '',
      senderName: null,
      text: '',
      imageUrl: '',
      audioUrl: '',
      timestamp: '',
      rawTimestamp: '',
      status: 'sent',
      isEdited: false,
      isPinned: false,
    );
  }

  @override
  String toString() {
    return 'MessageModel(id: $id, senderId: $senderId, status: $status, isEdited: $isEdited, isPinned: $isPinned)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MessageModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

extension MessageModelExtensions on MessageModel {
  bool get canRetrySending => status == 'failed';
  bool get isSystemMessage => senderId == 'system';
}
