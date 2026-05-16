class User {
  final String uid;
  final String fullName;
  final String username;
  final String email;
  final String phoneNumber;
  final String? photoUrl;
  final DateTime createdAt;
  final int reportCount;
  final int upvoteCount;

  User({
    required this.uid,
    required this.fullName,
    required this.username,
    required this.email,
    required this.phoneNumber,
    this.photoUrl,
    required this.createdAt,
    this.reportCount = 0,
    this.upvoteCount = 0,
  });

  // Convert User to JSON (untuk Firebase)
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'fullName': fullName,
      'username': username,
      'email': email,
      'phoneNumber': phoneNumber,
      'photoUrl': photoUrl,
      'createdAt': createdAt.toIso8601String(),
      'reportCount': reportCount,
      'upvoteCount': upvoteCount,
    };
  }

  // Create User from JSON (dari Firebase)
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      uid: json['uid'] as String,
      fullName: json['fullName'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      phoneNumber: json['phoneNumber'] as String,
      photoUrl: json['photoUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      reportCount: json['reportCount'] as int? ?? 0,
      upvoteCount: json['upvoteCount'] as int? ?? 0,
    );
  }

  // Copy with method untuk update user
  User copyWith({
    String? uid,
    String? fullName,
    String? username,
    String? email,
    String? phoneNumber,
    String? photoUrl,
    DateTime? createdAt,
    int? reportCount,
    int? upvoteCount,
  }) {
    return User(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      reportCount: reportCount ?? this.reportCount,
      upvoteCount: upvoteCount ?? this.upvoteCount,
    );
  }
}
