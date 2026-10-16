import 'package:equatable/equatable.dart';

/// Lifecycle delivery status for a chat message.
enum MessageDeliveryStatus {
  sending,
  sent,
  delivered,
  failed,
  read;

  static MessageDeliveryStatus fromString(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'sending':
      case 'pending':
        return MessageDeliveryStatus.sending;
      case 'read':
        return MessageDeliveryStatus.read;
      case 'delivered':
        return MessageDeliveryStatus.delivered;
      case 'failed':
      case 'error':
        return MessageDeliveryStatus.failed;
      case 'sent':
      default:
        return MessageDeliveryStatus.sent;
    }
  }

  String get dbValue => name;
}

/// ChatMessage model matching PROJECT.md and Supabase `chat_messages` schema.
///
/// CRITICAL ZERO-KNOWLEDGE INVARIANT:
/// [plaintext] is DECRYPTED IN MEMORY ONLY.
/// [toJson()] and [toInsertPayload()] NEVER serialize [plaintext] to
/// disk or wire.
class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.clientUuid,
    required this.ciphertext,
    required this.nonce,
    required this.createdAt,
    this.mac = '',
    this.plaintext,
    this.isRead = false,
    this.readAt,
    this.isOutgoing = false,
    this.deliveryStatus = MessageDeliveryStatus.sent,
  });

  /// Optimistic constructor for instantaneous local UI rendering before
  /// network ack.
  factory ChatMessage.createOptimistic({
    required String conversationId,
    required String senderId,
    required String clientUuid,
    required String plaintext,
    required String ciphertext,
    required String nonce,
    String mac = '',
  }) {
    final now = DateTime.now().toUtc();
    return ChatMessage(
      id: clientUuid, // Temporary ID matching clientUuid until server confirms
      conversationId: conversationId,
      senderId: senderId,
      clientUuid: clientUuid,
      ciphertext: ciphertext,
      nonce: nonce,
      createdAt: now,
      mac: mac,
      plaintext: plaintext,
      isOutgoing: true,
      deliveryStatus: MessageDeliveryStatus.sending,
    );
  }

  /// Deserializes a database row from Supabase `chat_messages`.
  factory ChatMessage.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
    String? decryptedPlaintext,
  }) {
    final sender = (json['sender_id'] as String?) ?? '';
    final isOut = currentUserId != null && currentUserId.isNotEmpty
        ? sender == currentUserId
        : (json['is_outgoing'] as bool? ?? false);

    final isReadVal = json['is_read'] as bool? ?? false;
    final readAtStr = json['read_at'] as String?;
    final readAtVal = readAtStr != null ? DateTime.tryParse(readAtStr) : null;

    final createdAtStr = json['created_at'] as String?;
    final createdAtVal = createdAtStr != null
        ? (DateTime.tryParse(createdAtStr)?.toUtc() ?? DateTime.now().toUtc())
        : DateTime.now().toUtc();

    final statusVal = isReadVal
        ? MessageDeliveryStatus.delivered
        : MessageDeliveryStatus.sent;

    return ChatMessage(
      id: json['id'] as String? ?? json['client_uuid'] as String? ?? '',
      conversationId: json['conversation_id'] as String? ?? '',
      senderId: sender,
      clientUuid: json['client_uuid'] as String? ?? '',
      ciphertext: json['ciphertext'] as String? ?? '',
      nonce: json['nonce'] as String? ?? '',
      mac: json['mac'] as String? ?? '',
      plaintext: decryptedPlaintext,
      isRead: isReadVal,
      readAt: readAtVal,
      createdAt: createdAtVal,
      isOutgoing: isOut,
      deliveryStatus: statusVal,
    );
  }

  final String id;
  final String conversationId;
  final String senderId;
  final String clientUuid;

  /// Plaintext decrypted in memory ONLY. Never sent to DB or wire.
  final String? plaintext;

  /// Base64 ciphertext + GCM tag
  final String ciphertext;

  /// Base64 12-byte CSPRNG IV
  final String nonce;

  /// Base64 16-byte authentication tag
  final String mac;

  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;
  final bool isOutgoing;
  final MessageDeliveryStatus deliveryStatus;

  /// Database serialization for Supabase `chat_messages`.
  /// ZERO PLAINTEXT TOUCHES THIS PAYLOAD.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'conversation_id': conversationId,
    'sender_id': senderId,
    'client_uuid': clientUuid,
    'ciphertext': ciphertext,
    'nonce': nonce,
    if (mac.isNotEmpty) 'mac': mac,
    'is_read': isRead,
    if (readAt != null) 'read_at': readAt!.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };

  /// Insertion payload for Supabase REST insert.
  Map<String, dynamic> toInsertPayload() => <String, dynamic>{
    'conversation_id': conversationId,
    'sender_id': senderId,
    'client_uuid': clientUuid,
    'ciphertext': ciphertext,
    'nonce': nonce,
    if (mac.isNotEmpty) 'mac': mac,
  };

  ChatMessage copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? clientUuid,
    String? plaintext,
    String? ciphertext,
    String? nonce,
    String? mac,
    bool? isRead,
    DateTime? readAt,
    DateTime? createdAt,
    bool? isOutgoing,
    MessageDeliveryStatus? deliveryStatus,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      clientUuid: clientUuid ?? this.clientUuid,
      plaintext: plaintext ?? this.plaintext,
      ciphertext: ciphertext ?? this.ciphertext,
      nonce: nonce ?? this.nonce,
      mac: mac ?? this.mac,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
      isOutgoing: isOutgoing ?? this.isOutgoing,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
    );
  }

  @override
  List<Object?> get props => [
    id,
    conversationId,
    senderId,
    clientUuid,
    plaintext,
    ciphertext,
    nonce,
    mac,
    isRead,
    readAt,
    createdAt,
    isOutgoing,
    deliveryStatus,
  ];
}
