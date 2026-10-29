class UserModel {
  final int id;
  final String name;
  final String username;
  final String role;
  final String? apiToken;
  final bool isActive;
  final String? tokenExpiresAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.username,
    required this.role,
    this.apiToken,
    this.isActive = true,
    this.tokenExpiresAt,
  });

  bool get isKepalaBidang {
    final normalized = role.trim().toLowerCase();
    return normalized.contains('kepala') ||
        normalized.contains('kabid') ||
        normalized.contains('pimpinan') ||
        normalized.contains('manajer');
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      role: json['role']?.toString() ?? 'Teknisi',
      apiToken: json['api_token']?.toString(),
      isActive: json['is_active'] == null
          ? true
          : (json['is_active'] == 1 || json['is_active'] == true),
      tokenExpiresAt: json['token_expires_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'role': role,
      'api_token': apiToken,
      'is_active': isActive ? 1 : 0,
      'token_expires_at': tokenExpiresAt,
    };
  }

  /// Serialisasi profil pengguna tanpa menyertakan kredensial sensitif (api_token)
  Map<String, dynamic> toSafeCacheJson() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'role': role,
      'is_active': isActive ? 1 : 0,
      'token_expires_at': tokenExpiresAt,
    };
  }
}
