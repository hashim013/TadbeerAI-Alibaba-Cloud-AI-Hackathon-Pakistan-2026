/// A locally-authenticated Tadbeer user.
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.photoUrl,
  });

  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? photoUrl;

  bool get isGuest =>
      email == 'guest@tadbeer.ai' ||
      id.startsWith('guest') ||
      name.toLowerCase().contains('guest');

  AppUser copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? photoUrl,
  }) =>
      AppUser(
        id: id ?? this.id,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        photoUrl: photoUrl ?? this.photoUrl,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        if (phone != null) 'phone': phone,
        if (photoUrl != null) 'photoUrl': photoUrl,
      };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String?,
        photoUrl: json['photoUrl'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser &&
          other.id == id &&
          other.email == email &&
          other.phone == phone;

  @override
  int get hashCode => Object.hash(id, email, phone);

  @override
  String toString() => 'AppUser($email)';
}

