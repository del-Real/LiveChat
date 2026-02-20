
typedef UserId = String;

class User {
  final UserId id;
  final String username;
  final String email;
  final String? displayName;
  final String? profilePicture;
  final bool? isVerified;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.displayName,
    this.profilePicture,
    this.isVerified,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? 'Unknown',
      email: json['email']?.toString() ?? '',
      displayName: json['displayName']?.toString(),
      profilePicture: json['profilePicture']?.toString(),
      isVerified: json['isVerified'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'username': username,
      'email': email,
      'displayName': displayName,
      'profilePicture': profilePicture,
      if (isVerified != null) 'isVerified': isVerified,
    };
  }

  
  // Safe helpers & getters
  

  /// Returns displayName if exists, otherwise username
  String get resolvedName =>
      (displayName != null && displayName!.isNotEmpty)
          ? displayName!
          : username;

  /// Check if user has a profile picture
  bool get hasProfilePicture =>
      profilePicture != null && profilePicture!.isNotEmpty;

  /// Verification helpers
  bool get isAccountVerified => isVerified == true;
  bool get isAccountUnverified => isVerified == false;

  /// Simple computed helpers
  bool get hasEmail => email.isNotEmpty;
  bool get hasUsername => username.isNotEmpty;

  User copyWith({
    UserId? id,
    String? username,
    String? email,
    String? displayName,
    String? profilePicture,
    bool? isVerified,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      profilePicture: profilePicture ?? this.profilePicture,
      isVerified: isVerified ?? this.isVerified,
    );
  }

  
  // Factories & utilities
  

  factory User.empty() {
    return User(
      id: '',
      username: '',
      email: '',
      displayName: null,
      profilePicture: null,
      isVerified: null,
    );
  }

  @override
  String toString() {
    return 'User(id: $id, username: $username, verified: $isVerified)';
  }

  

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Extensions 

extension UserExtensions on User {
  bool get canChat => isVerified == true;
  bool get isGuest => id.isEmpty;
}
