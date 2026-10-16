import 'dart:convert';
import 'package:equatable/equatable.dart';

/// User Encryption Key record matching Supabase `encryption_keys` table.
class UserEncryptionKey extends Equatable {
  const UserEncryptionKey({
    required this.userId,
    required this.publicKey,
    this.id,
    this.createdAt,
    this.updatedAt,
  });

  factory UserEncryptionKey.fromJson(Map<String, dynamic> json) {
    return UserEncryptionKey(
      id: json['id'] as String?,
      userId: (json['user_id'] as String?) ?? '',
      publicKey: (json['public_key'] as String?) ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  final String? id;
  final String userId;

  /// 32-byte X25519 public key encoded as Base64 string (44 characters).
  final String publicKey;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Validates key format against Postgres check constraint:
  /// `CONSTRAINT ck_encryption_keys_format`
  /// `CHECK (char_length(public_key) >= 40)`
  bool get isValid {
    if (publicKey.length < 40) return false;
    try {
      final bytes = base64.decode(publicKey);
      return bytes.length == 32;
    } on Object catch (_) {
      return false;
    }
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (id != null) 'id': id,
    'user_id': userId,
    'public_key': publicKey,
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
  };

  UserEncryptionKey copyWith({
    String? id,
    String? userId,
    String? publicKey,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserEncryptionKey(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      publicKey: publicKey ?? this.publicKey,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, userId, publicKey, createdAt, updatedAt];
}
