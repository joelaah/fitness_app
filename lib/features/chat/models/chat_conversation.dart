import 'package:equatable/equatable.dart';
import 'package:fitness_app/features/chat/models/chat_message.dart';

/// Conversation metadata matching PROJECT.md and Supabase `chat_conversations`.
class ChatConversation extends Equatable {
  const ChatConversation({
    required this.id,
    required this.userId,
    required this.trainerId,
    required this.createdAt,
    required this.updatedAt,
    this.trainerUserId,
    this.userName,
    this.trainerName,
    this.lastMessage,
    this.lastMessageText,
    this.unreadCount = 0,
  });

  factory ChatConversation.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    // Resolve user display name
    String? resolvedUserName;
    if (json['user_name'] is String) {
      resolvedUserName = json['user_name'] as String;
    } else if (json['profiles'] is Map) {
      resolvedUserName = (json['profiles'] as Map)['display_name'] as String?;
    } else if (json['user_profile'] is Map) {
      resolvedUserName =
          (json['user_profile'] as Map)['display_name'] as String?;
    }

    // Resolve trainer profile and auth user_id
    String? resolvedTrainerUserId;
    String? resolvedTrainerName;
    if (json['trainer_user_id'] is String) {
      resolvedTrainerUserId = json['trainer_user_id'] as String;
    }

    if (json['trainer_name'] is String) {
      resolvedTrainerName = json['trainer_name'] as String;
    } else if (json['trainer_profiles'] is Map) {
      final tp = json['trainer_profiles'] as Map<String, dynamic>;
      resolvedTrainerUserId ??= tp['user_id'] as String?;
      if (tp['profiles'] is Map) {
        resolvedTrainerName =
            (tp['profiles'] as Map)['display_name'] as String?;
      } else if (tp['display_name'] is String) {
        resolvedTrainerName = tp['display_name'] as String;
      }
    }

    final createdAtStr = json['created_at'] as String?;
    final updatedAtStr = json['updated_at'] as String?;

    ChatMessage? lastMsg;
    if (json['last_message'] is Map<String, dynamic>) {
      lastMsg = ChatMessage.fromJson(
        json['last_message'] as Map<String, dynamic>,
        currentUserId: currentUserId,
      );
    }

    final lastText =
        json['last_message_text'] as String? ??
        (json['last_message'] is String
            ? json['last_message'] as String
            : null);

    return ChatConversation(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      trainerId: json['trainer_id'] as String? ?? '',
      trainerUserId: resolvedTrainerUserId,
      userName: resolvedUserName,
      trainerName: resolvedTrainerName,
      lastMessage: lastMsg,
      lastMessageText: lastText,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      createdAt: createdAtStr != null
          ? (DateTime.tryParse(createdAtStr)?.toUtc() ?? DateTime.now().toUtc())
          : DateTime.now().toUtc(),
      updatedAt: updatedAtStr != null
          ? (DateTime.tryParse(updatedAtStr)?.toUtc() ?? DateTime.now().toUtc())
          : DateTime.now().toUtc(),
    );
  }

  final String id;
  final String userId;
  final String trainerId;

  /// The auth.users(id) for the trainer (used for encryption key lookups).
  final String? trainerUserId;

  final String? userName;
  final String? trainerName;
  final ChatMessage? lastMessage;
  final String? lastMessageText;
  final int unreadCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Returns preview text for conversation tile.
  String? get lastMessagePreview => lastMessageText ?? lastMessage?.plaintext;

  /// Returns the other participant's auth user ID for encryption key queries.
  String getOtherParticipantUserId(String currentUserId) {
    if (currentUserId == userId) {
      return trainerUserId ?? trainerId;
    }
    return userId;
  }

  /// Returns the other participant's display name for chat headers.
  String getOtherParticipantName(String currentUserId) {
    if (currentUserId == userId) {
      return trainerName ?? 'Coach';
    }
    return userName ?? 'Athlete';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'user_id': userId,
    'trainer_id': trainerId,
    if (trainerUserId != null) 'trainer_user_id': trainerUserId,
    if (userName != null) 'user_name': userName,
    if (trainerName != null) 'trainer_name': trainerName,
    if (lastMessage != null) 'last_message': lastMessage!.toJson(),
    if (lastMessageText != null) 'last_message_text': lastMessageText,
    'unread_count': unreadCount,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  ChatConversation copyWith({
    String? id,
    String? userId,
    String? trainerId,
    String? trainerUserId,
    String? userName,
    String? trainerName,
    ChatMessage? lastMessage,
    String? lastMessageText,
    int? unreadCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChatConversation(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      trainerId: trainerId ?? this.trainerId,
      trainerUserId: trainerUserId ?? this.trainerUserId,
      userName: userName ?? this.userName,
      trainerName: trainerName ?? this.trainerName,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      unreadCount: unreadCount ?? this.unreadCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    trainerId,
    trainerUserId,
    userName,
    trainerName,
    lastMessage,
    lastMessageText,
    unreadCount,
    createdAt,
    updatedAt,
  ];
}
