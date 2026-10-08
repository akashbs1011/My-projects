class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.preferredLanguage,
    this.createdAt,
  });

  final String id;
  final String name;
  final String email;
  final String preferredLanguage;
  final DateTime? createdAt;

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        preferredLanguage: json['preferred_language'] as String? ?? 'en',
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      );

  User copyWith({String? name, String? preferredLanguage}) => User(
        id: id,
        name: name ?? this.name,
        email: email,
        preferredLanguage: preferredLanguage ?? this.preferredLanguage,
        createdAt: createdAt,
      );

  String get initial => name.isEmpty ? '?' : name[0].toUpperCase();
}
