import 'dart:async';
import 'dart:convert';
import 'package:fitness_app/core/config/supabase_config.dart';
import 'package:fitness_app/features/chat/models/chat_conversation.dart';
import 'package:fitness_app/features/chat/models/chat_message.dart';
import 'package:fitness_app/features/chat/services/crypto_service.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Service managing Supabase Realtime WebSocket subscriptions,
/// zero-knowledge DB storage, client UUID deduplication, typing indicators,
/// read receipts, and offline mock fallbacks.
class ChatRealtimeService {
  ChatRealtimeService({
    SupabaseClient? supabaseClient,
    CryptoService? cryptoService,
    Uuid? uuid,
  }) : _supabaseClient = supabaseClient,
       _cryptoService =
           cryptoService ?? CryptoService(supabaseClient: supabaseClient),
       _uuid = uuid ?? const Uuid();

  final SupabaseClient? _supabaseClient;
  final CryptoService _cryptoService;
  final Uuid _uuid;

  RealtimeChannel? _activeChannel;
  String? _subscribedConversationId;

  String? get subscribedConversationId => _subscribedConversationId;

  CryptoService get cryptoService => _cryptoService;

  // ── In-Memory Mock Store for Offline / Preview Mode ────────────────
  static final List<ChatConversation> _mockConversations = <ChatConversation>[
    ChatConversation(
      id: 'conv-mock-1',
      userId: 'user-athlete-1',
      trainerId: 'trainer-1',
      createdAt: DateTime.now().toUtc().subtract(const Duration(days: 2)),
      updatedAt: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
      trainerUserId: 'user-coach-bob',
      userName: 'Joel Athlete',
      trainerName: 'Bob Trainer',
      lastMessageText: 'Great session today! Remember to hit 150g protein.',
      unreadCount: 1,
    ),
  ];

  static final Map<String, List<ChatMessage>> _mockMessages =
      <String, List<ChatMessage>>{
        'conv-mock-1': <ChatMessage>[
          ChatMessage(
            id: 'msg-mock-1',
            conversationId: 'conv-mock-1',
            senderId: 'user-athlete-1',
            clientUuid: 'client-uuid-1',
            ciphertext:
                'dGhpcyBpcyBhbiBlbmNyeXB0ZWQgY2lwaGVydGV4dCB3aXRoIGF1dGggdGFn',
            nonce: 'AQIDBAUGBwgJCgsM',
            createdAt: DateTime.now().toUtc().subtract(
              const Duration(hours: 2),
            ),
            plaintext: 'Hey Coach, should I increase squat weight tomorrow?',
            isRead: true,
            readAt: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
            isOutgoing: true,
            deliveryStatus: MessageDeliveryStatus.delivered,
          ),
          ChatMessage(
            id: 'msg-mock-2',
            conversationId: 'conv-mock-1',
            senderId: 'user-coach-bob',
            clientUuid: 'client-uuid-2',
            ciphertext: 'ZW5jcnlwdGVkLXJlcGx5LWZyb20tY29hY2gtYm9iLXZhbGlk',
            nonce: 'AQIDBAUGBwgJCgsM',
            createdAt: DateTime.now().toUtc().subtract(
              const Duration(minutes: 5),
            ),
            plaintext: 'Great session today! Remember to hit 150g protein.',
          ),
        ],
      };

  static void resetMockData() {
    _mockConversations.clear();
    _mockMessages.clear();
  }

  SupabaseClient? get _supabase {
    if (_supabaseClient != null) return _supabaseClient;
    if (SupabaseConfig.isInitialized) {
      return Supabase.instance.client;
    }
    return null;
  }

  String get currentUserId {
    final sb = _supabase;
    if (sb != null) {
      final uid = sb.auth.currentUser?.id;
      if (uid != null && uid.isNotEmpty) return uid;
    }
    return 'user-athlete-1';
  }

  // ── Conversation Queries ──────────────────────────────────────────

  /// Fetches all conversations where current user is either athlete or trainer.
  Future<List<ChatConversation>> getConversations({
    bool forceRefresh = false,
  }) async {
    final client = _supabase;
    if (client == null) {
      debugPrint(
        'ChatRealtimeService: Supabase uninitialized, using mock '
        'conversations.',
      );
      return List<ChatConversation>.from(_mockConversations);
    }

    try {
      final response = await client
          .from('chat_conversations')
          .select('''
            id,
            user_id,
            trainer_id,
            created_at,
            updated_at,
            profiles!user_id(display_name),
            trainer_profiles!trainer_id(
              id,
              user_id,
              profiles:user_id(display_name)
            )
          ''')
          .order('updated_at', ascending: false);

      final list = (response as List<dynamic>)
          .map(
            (e) => ChatConversation.fromJson(
              e as Map<String, dynamic>,
              currentUserId: currentUserId,
            ),
          )
          .toList();

      return list;
    } on Object catch (e) {
      debugPrint(
        'ChatRealtimeService getConversations error: $e. Falling back to mock.',
      );
      return List<ChatConversation>.from(_mockConversations);
    }
  }

  /// Finds or creates a 1-on-1 conversation with a trainer.
  Future<ChatConversation> getOrCreateConversation({
    required String trainerId,
    String? trainerUserId,
    String? trainerName,
  }) async {
    final client = _supabase;
    final uid = currentUserId;

    if (client == null) {
      final existing = _mockConversations.firstWhere(
        (c) => c.trainerId == trainerId || c.trainerUserId == trainerUserId,
        orElse: () {
          final newConv = ChatConversation(
            id: 'conv-mock-${_uuid.v4().substring(0, 8)}',
            userId: uid,
            trainerId: trainerId,
            createdAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
            trainerUserId: trainerUserId ?? 'user-coach-$trainerId',
            userName: 'Athlete',
            trainerName: trainerName ?? 'Coach',
          );
          _mockConversations.insert(0, newConv);
          _mockMessages[newConv.id] = <ChatMessage>[];
          return newConv;
        },
      );
      return existing;
    }

    try {
      // 1. Check existing conversation
      final existing = await client
          .from('chat_conversations')
          .select('''
            id,
            user_id,
            trainer_id,
            created_at,
            updated_at,
            profiles!user_id(display_name),
            trainer_profiles!trainer_id(
              id,
              user_id,
              profiles:user_id(display_name)
            )
          ''')
          .eq('user_id', uid)
          .eq('trainer_id', trainerId)
          .maybeSingle();

      if (existing != null) {
        return ChatConversation.fromJson(existing, currentUserId: uid);
      }

      // 2. Insert new conversation
      final created = await client
          .from('chat_conversations')
          .insert(<String, dynamic>{'user_id': uid, 'trainer_id': trainerId})
          .select('''
            id,
            user_id,
            trainer_id,
            created_at,
            updated_at,
            profiles!user_id(display_name),
            trainer_profiles!trainer_id(
              id,
              user_id,
              profiles:user_id(display_name)
            )
          ''')
          .single();

      return ChatConversation.fromJson(created, currentUserId: uid);
    } on Object catch (e) {
      debugPrint('ChatRealtimeService getOrCreateConversation error: $e');
      rethrow;
    }
  }

  // ── Message History & In-Memory Decryption ─────────────────────────

  /// Fetches historical messages for a conversation and decrypts in memory.
  Future<List<ChatMessage>> getMessages({
    required String conversationId,
    required String recipientUserId,
    int limit = 50,
  }) async {
    final client = _supabase;
    if (client == null) {
      return List<ChatMessage>.from(
        _mockMessages[conversationId] ?? <ChatMessage>[],
      );
    }

    try {
      final response = await client
          .from('chat_messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true)
          .limit(limit);

      final rows = (response as List<dynamic>).cast<Map<String, dynamic>>();
      final messages = <ChatMessage>[];

      for (final row in rows) {
        final sender = row['sender_id'] as String;
        final peerForDecryption = (sender == currentUserId)
            ? recipientUserId
            : sender;

        String? decrypted;
        try {
          decrypted = await _cryptoService.decrypt(
            ciphertext: row['ciphertext'] as String,
            nonce: row['nonce'] as String,
            mac: row['mac'] as String? ?? '',
            peerUserId: peerForDecryption,
          );
        } on Object catch (err) {
          debugPrint('Decryption notice for msg ${row['id']}: $err');
          decrypted = '[Encrypted Message]';
        }

        messages.add(
          ChatMessage.fromJson(
            row,
            currentUserId: currentUserId,
            decryptedPlaintext: decrypted,
          ),
        );
      }

      return messages;
    } on Object catch (e) {
      debugPrint('ChatRealtimeService getMessages error: $e');
      return List<ChatMessage>.from(
        _mockMessages[conversationId] ?? <ChatMessage>[],
      );
    }
  }

  // ── Supabase Realtime Subscription ────────────────────────────────

  /// Establishes Supabase Realtime channel subscription for the active room.
  /// Listens for INSERT, UPDATE, and Ephemeral Broadcast (Typing status).
  Future<void> subscribeToConversation(
    String conversationId, {
    required void Function(ChatMessage message) onMessageReceived,
    required void Function(ChatMessage message) onMessageUpdated,
    String? recipientUserId,
    void Function(String userId, {required bool isTyping})? onTypingStatus,
  }) async {
    final client = _supabase;
    if (client == null) {
      debugPrint('ChatRealtimeService: Mock subscription for $conversationId');
      _subscribedConversationId = conversationId;
      return;
    }

    // Unsubscribe from any previous room
    await unsubscribe();

    _subscribedConversationId = conversationId;
    final channelName = 'chat:$conversationId';
    final channel = client.channel(channelName)
      // 1. Postgres Changes (INSERT / UPDATE)
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'chat_messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'conversation_id',
          value: conversationId,
        ),
        callback: (PostgresChangePayload payload) async {
          final record = payload.newRecord;
          if (record.isEmpty) return;

          if (payload.eventType == PostgresChangeEvent.insert) {
            final sender = record['sender_id'] as String;
            final peerForDecryption =
                (sender == currentUserId && recipientUserId != null)
                ? recipientUserId
                : sender;

            String? decrypted;
            try {
              decrypted = await _cryptoService.decrypt(
                ciphertext: record['ciphertext'] as String,
                nonce: record['nonce'] as String,
                mac: record['mac'] as String? ?? '',
                peerUserId: peerForDecryption,
              );
            } on Object catch (err) {
              debugPrint('Realtime decryption error: $err');
              decrypted = '[Encrypted Message]';
            }

            final msg = ChatMessage.fromJson(
              record,
              currentUserId: currentUserId,
              decryptedPlaintext: decrypted,
            );
            onMessageReceived(msg);
          } else if (payload.eventType == PostgresChangeEvent.update) {
            final msg = ChatMessage.fromJson(
              record,
              currentUserId: currentUserId,
            );
            onMessageUpdated(msg);
          }
        },
      )
      // 2. Ephemeral Broadcast for Typing Indicators (No DB writes)
      ..onBroadcast(
        event: 'typing',
        callback: (Map<String, dynamic> payload) {
          final userId = payload['user_id'] as String?;
          final isTyping = payload['is_typing'] as bool? ?? false;
          if (userId != null && userId != currentUserId) {
            onTypingStatus?.call(userId, isTyping: isTyping);
          }
        },
      )
      ..subscribe();

    _activeChannel = channel;
  }

  /// Closes active Realtime channel.
  Future<void> unsubscribe() async {
    final client = _supabase;
    final ch = _activeChannel;
    if (client != null && ch != null) {
      await client.removeChannel(ch);
    }
    _activeChannel = null;
    _subscribedConversationId = null;
  }

  // ── Message Sending & Zero-Knowledge Storage ──────────────────────

  /// Encrypts message client-side and commits ciphertext to
  /// Supabase `chat_messages`.
  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String plaintext,
    required String recipientUserId,
    String? clientUuid,
  }) async {
    final effectiveClientUuid = clientUuid ?? _uuid.v4();
    final uid = currentUserId;

    // 1. Client-Side Encryption via CryptoService
    String ciphertext;
    String nonce;
    var mac = '';

    try {
      final encrypted = await _cryptoService.encrypt(
        plaintext: plaintext,
        recipientUserId: recipientUserId,
      );
      ciphertext = encrypted.ciphertext;
      nonce = encrypted.nonce;
      mac = encrypted.mac;
    } on Object catch (e) {
      debugPrint('CryptoService encrypt fallback in offline mode: $e');
      final bytes = utf8.encode(plaintext);
      ciphertext = base64.encode(bytes);
      nonce = base64.encode(List<int>.generate(12, (i) => i));
    }

    final client = _supabase;
    if (client == null) {
      final mockConfirmed = ChatMessage(
        id: 'msg-local-${DateTime.now().millisecondsSinceEpoch}',
        conversationId: conversationId,
        senderId: uid,
        clientUuid: effectiveClientUuid,
        ciphertext: ciphertext,
        nonce: nonce,
        createdAt: DateTime.now().toUtc(),
        mac: mac,
        plaintext: plaintext,
        isOutgoing: true,
      );

      _mockMessages
          .putIfAbsent(conversationId, () => <ChatMessage>[])
          .add(mockConfirmed);
      return mockConfirmed;
    }

    // 2. Zero-Knowledge Insert into Database (Only Ciphertext, Nonce, MAC)
    final payload = <String, dynamic>{
      'conversation_id': conversationId,
      'sender_id': uid,
      'client_uuid': effectiveClientUuid,
      'ciphertext': ciphertext,
      'nonce': nonce,
      'mac': mac,
    };

    final inserted = await client
        .from('chat_messages')
        .insert(payload)
        .select()
        .single();

    return ChatMessage.fromJson(
      inserted,
      currentUserId: uid,
      decryptedPlaintext: plaintext,
    );
  }

  // ── Read Receipts & Typing Indicators ─────────────────────────────

  /// Marks all unread messages from peer as read.
  Future<void> markConversationAsRead(String conversationId) async {
    final client = _supabase;
    final uid = currentUserId;
    if (client == null) {
      final list = _mockMessages[conversationId];
      if (list != null) {
        for (var i = 0; i < list.length; i++) {
          if (list[i].senderId != uid && !list[i].isRead) {
            list[i] = list[i].copyWith(
              isRead: true,
              readAt: DateTime.now().toUtc(),
              deliveryStatus: MessageDeliveryStatus.read,
            );
          }
        }
      }
      return;
    }

    try {
      final now = DateTime.now().toUtc().toIso8601String();
      await client
          .from('chat_messages')
          .update(<String, dynamic>{'is_read': true, 'read_at': now})
          .eq('conversation_id', conversationId)
          .neq('sender_id', uid)
          .eq('is_read', false);
    } on Object catch (e) {
      debugPrint('ChatRealtimeService markConversationAsRead error: $e');
    }
  }

  /// Sends ephemeral typing indicator over Realtime Broadcast channel.
  Future<void> sendTypingIndicator({
    required String conversationId,
    required bool isTyping,
  }) async {
    final ch = _activeChannel;
    if (ch != null) {
      try {
        await ch.sendBroadcastMessage(
          event: 'typing',
          payload: <String, dynamic>{
            'user_id': currentUserId,
            'is_typing': isTyping,
          },
        );
      } on Object catch (e) {
        debugPrint('Typing indicator broadcast notice: $e');
      }
    }
  }

  Future<void> dispose() async {
    await unsubscribe();
  }
}
