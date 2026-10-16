import 'package:bloc_test/bloc_test.dart';
import 'package:fitness_app/features/chat/bloc/chat_bloc.dart';
import 'package:fitness_app/features/chat/bloc/chat_event.dart';
import 'package:fitness_app/features/chat/bloc/chat_state.dart';
import 'package:fitness_app/features/chat/models/chat_conversation.dart';
import 'package:fitness_app/features/chat/models/chat_message.dart';
import 'package:fitness_app/features/chat/models/encryption_key.dart';
import 'package:fitness_app/features/chat/services/chat_realtime_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('E2EE Chat Data Models Tests', () {
    test(
      'ChatMessage zero-knowledge invariant: toJson NEVER leaks plaintext',
      () {
        final msg = ChatMessage(
          id: 'msg-123',
          conversationId: 'conv-456',
          senderId: 'user-789',
          clientUuid: 'uuid-1011',
          ciphertext: 'ZW5jcnlwdGVkLXdvcmtvdXQtcGxhbi1jaXBoZXI=',
          nonce: 'AQIDBAUGBwgJCgsM',
          mac: 'dGFnMTIzNDU2Nzg5MDEyMw==',
          plaintext: 'Confidential workout routine: Bench 100kg x 5 reps',
          isRead: false,
          createdAt: DateTime.utc(2026, 10, 14, 12, 0),
          isOutgoing: true,
          deliveryStatus: MessageDeliveryStatus.sent,
        );

        final jsonMap = msg.toJson();

        // STRICT VERIFICATION: Plaintext is omitted entirely from DB serialization
        expect(jsonMap.containsKey('plaintext'), isFalse);
        expect(
          jsonMap.toString().contains('Confidential workout routine'),
          isFalse,
        );
        expect(
          jsonMap['ciphertext'],
          'ZW5jcnlwdGVkLXdvcmtvdXQtcGxhbi1jaXBoZXI=',
        );
        expect(jsonMap['nonce'], 'AQIDBAUGBwgJCgsM');
        expect(jsonMap['client_uuid'], 'uuid-1011');
      },
    );

    test('ChatMessage optimistic creation assigns correct sending status', () {
      final msg = ChatMessage.createOptimistic(
        conversationId: 'conv-1',
        senderId: 'user-1',
        clientUuid: 'client-uuid-999',
        plaintext: 'Hello coach!',
        ciphertext: '',
        nonce: '',
      );

      expect(msg.deliveryStatus, MessageDeliveryStatus.sending);
      expect(msg.isOutgoing, isTrue);
      expect(msg.id, 'client-uuid-999');
      expect(msg.plaintext, 'Hello coach!');
    });

    test(
      'ChatConversation deserializes joined PostgREST structure properly',
      () {
        final rawPostgrest = <String, dynamic>{
          'id': 'conv-uuid-1',
          'user_id': 'user-uuid-1',
          'trainer_id': 'trainer-profile-uuid-1',
          'created_at': '2026-10-14T10:00:00Z',
          'updated_at': '2026-10-14T11:00:00Z',
          'profiles': <String, dynamic>{'display_name': 'Joel Athlete'},
          'trainer_profiles': <String, dynamic>{
            'id': 'trainer-profile-uuid-1',
            'user_id': 'user-coach-bob-auth-uuid',
            'profiles': <String, dynamic>{'display_name': 'Coach Bob'},
          },
        };

        final conv = ChatConversation.fromJson(
          rawPostgrest,
          currentUserId: 'user-uuid-1',
        );

        expect(conv.id, 'conv-uuid-1');
        expect(conv.userId, 'user-uuid-1');
        expect(conv.trainerId, 'trainer-profile-uuid-1');
        expect(conv.trainerUserId, 'user-coach-bob-auth-uuid');
        expect(conv.userName, 'Joel Athlete');
        expect(conv.trainerName, 'Coach Bob');
        expect(conv.getOtherParticipantName('user-uuid-1'), 'Coach Bob');
        expect(
          conv.getOtherParticipantUserId('user-uuid-1'),
          'user-coach-bob-auth-uuid',
        );
      },
    );

    test('UserEncryptionKey validates 32-byte X25519 public key format', () {
      const validKey =
          '3q2+796tvu/erb7v3q2+796tvu/erb7v3q2+796tvu8='; // 44 chars, 32 bytes
      const shortKey = 'dG9vc2hvcnQ='; // too short

      const valid = UserEncryptionKey(
        userId: 'user-1',
        publicKey: validKey,
      );
      const invalid = UserEncryptionKey(
        userId: 'user-2',
        publicKey: shortKey,
      );

      expect(valid.isValid, isTrue);
      expect(invalid.isValid, isFalse);
    });
  });

  group('ChatBloc State Machine & Deduplication Tests', () {
    late ChatRealtimeService chatService;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      ChatRealtimeService.resetMockData();
      chatService = ChatRealtimeService();
    });

    blocTest<ChatBloc, ChatState>(
      'LoadConversations transitions from loading to loaded',
      build: () => ChatBloc(chatService: chatService),
      act: (bloc) => bloc.add(const LoadConversations()),
      expect: () => [
        isA<ChatConversationsLoading>(),
        isA<ChatConversationsLoaded>(),
      ],
    );

    blocTest<ChatBloc, ChatState>(
      'SendMessage emits optimistic sending status, followed by server confirmation',
      build: () => ChatBloc(chatService: chatService),
      seed: () => ChatRoomActive(
        conversation: ChatConversation(
          id: 'conv-test-1',
          userId: 'user-athlete-1',
          trainerId: 'trainer-1',
          trainerUserId: 'user-coach-bob',
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        ),
        messages: const <ChatMessage>[],
      ),
      act: (bloc) => bloc.add(
        SendMessage(
          conversationId: 'conv-test-1',
          plaintext: 'Are we doing legs today?',
          recipientUserId: 'user-coach-bob',
          clientUuid: 'client-test-uuid-42',
        ),
      ),
      expect: () => [
        // 1. Optimistic update with MessageDeliveryStatus.sending
        isA<ChatRoomActive>().having(
          (s) => s.messages.last.deliveryStatus,
          'status',
          MessageDeliveryStatus.sending,
        ),
        // 2. Confirmed update with MessageDeliveryStatus.sent
        isA<ChatRoomActive>().having(
          (s) => s.messages.last.deliveryStatus,
          'status',
          MessageDeliveryStatus.sent,
        ),
      ],
    );

    blocTest<ChatBloc, ChatState>(
      'MessageReceived with existing clientUuid deduplicates without duplicating message count',
      build: () => ChatBloc(chatService: chatService),
      seed: () => ChatRoomActive(
        conversation: ChatConversation(
          id: 'conv-test-1',
          userId: 'user-athlete-1',
          trainerId: 'trainer-1',
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        ),
        messages: [
          ChatMessage.createOptimistic(
            conversationId: 'conv-test-1',
            senderId: 'user-athlete-1',
            clientUuid: 'client-uuid-dedup-1',
            plaintext: 'Original plaintext',
            ciphertext: 'cipher',
            nonce: 'nonce',
          ),
        ],
      ),
      act: (bloc) => bloc.add(
        MessageReceived(
          ChatMessage(
            id: 'server-confirmed-db-id',
            conversationId: 'conv-test-1',
            senderId: 'user-athlete-1',
            clientUuid: 'client-uuid-dedup-1',
            ciphertext: 'cipher',
            nonce: 'nonce',
            isRead: false,
            createdAt: DateTime.now().toUtc(),
            deliveryStatus: MessageDeliveryStatus.sent,
          ),
        ),
      ),
      expect: () => [
        isA<ChatRoomActive>()
            .having((s) => s.messages.length, 'length', 1)
            .having((s) => s.messages.first.id, 'id', 'server-confirmed-db-id')
            .having(
              (s) => s.messages.first.deliveryStatus,
              'status',
              MessageDeliveryStatus.sent,
            ),
      ],
    );

    blocTest<ChatBloc, ChatState>(
      'MessageUpdated marks message as delivered when isRead is true',
      build: () => ChatBloc(chatService: chatService),
      seed: () => ChatRoomActive(
        conversation: ChatConversation(
          id: 'conv-test-1',
          userId: 'user-athlete-1',
          trainerId: 'trainer-1',
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        ),
        messages: [
          ChatMessage(
            id: 'msg-read-check-1',
            conversationId: 'conv-test-1',
            senderId: 'user-athlete-1',
            clientUuid: 'uuid-1',
            ciphertext: 'c',
            nonce: 'n',
            isRead: false,
            createdAt: DateTime.now().toUtc(),
            deliveryStatus: MessageDeliveryStatus.sent,
          ),
        ],
      ),
      act: (bloc) => bloc.add(
        MessageUpdated(
          ChatMessage(
            id: 'msg-read-check-1',
            conversationId: 'conv-test-1',
            senderId: 'user-athlete-1',
            clientUuid: 'uuid-1',
            ciphertext: 'c',
            nonce: 'n',
            isRead: true,
            readAt: DateTime.now().toUtc(),
            createdAt: DateTime.now().toUtc(),
            deliveryStatus: MessageDeliveryStatus.delivered,
          ),
        ),
      ),
      expect: () => [
        isA<ChatRoomActive>()
            .having((s) => s.messages.first.isRead, 'isRead', true)
            .having(
              (s) => s.messages.first.deliveryStatus,
              'status',
              MessageDeliveryStatus.delivered,
            ),
      ],
    );
  });
}
