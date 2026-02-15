
import 'package:namer_app/models/user.dart';

typedef ContactId = String;
typedef UserId = String;

class ContactModel {
  final ContactId id;
  final UserId userId;
  final User contact;
  final String status; // 'pending', 'accepted', 'blocked'
  final UserId requesterId;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime updatedAt;

  ContactModel({
    required this.id,
    required this.userId,
    required this.contact,
    required this.status,
    required this.requesterId,
    this.isFavorite = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    var userData = json['contactId'] ?? json['contact'] ?? json['requester'];

    return ContactModel(
      id: json['_id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      contact: User.fromJson(
        userData is Map<String, dynamic>
            ? userData
            : {
                '_id': userData?.toString() ?? '',
                'username': 'Loading...',
                'email': '',
              },
      ),
      status: json['status']?.toString() ?? 'pending',
      requesterId: json['requester']?.toString() ?? '',
      isFavorite: json['isFavorite'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'userId': userId,
      'contactId': contact.toJson(),
      'status': status,
      'requester': requesterId,
      'isFavorite': isFavorite,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  

  /// Check if current user sent the request
  bool didISendRequest(UserId currentUserId) {
    return requesterId == currentUserId;
  }

  /// Check if this is an incoming request
  bool isIncomingRequest(UserId currentUserId) {
    return requesterId != currentUserId && status == 'pending';
  }

  /// Computed helpers (safe)
  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isBlocked => status == 'blocked';

  bool get isActive => status == 'accepted';
  bool get wasRequestedByMe => requesterId == userId;

  Duration get age => DateTime.now().difference(createdAt);

  ContactModel copyWith({
    ContactId? id,
    UserId? userId,
    User? contact,
    String? status,
    UserId? requesterId,
    bool? isFavorite,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ContactModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      contact: contact ?? this.contact,
      status: status ?? this.status,
      requesterId: requesterId ?? this.requesterId,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory ContactModel.empty() {
    return ContactModel(
      id: '',
      userId: '',
      contact: User.fromJson({
        '_id': '',
        'username': '',
        'email': '',
      }),
      status: 'pending',
      requesterId: '',
      isFavorite: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'ContactModel(id: $id, status: $status, contact: ${contact.username})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ContactModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}


extension ContactModelExtensions on ContactModel {
  bool get canChat => isAccepted && !isBlocked;
  bool get canFavorite => isAccepted;
}
