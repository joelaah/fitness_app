import 'dart:math';
import 'package:fitness_app/features/chat/bloc/chat_bloc.dart';
import 'package:fitness_app/features/chat/bloc/chat_event.dart';
import 'package:fitness_app/features/chat/bloc/chat_state.dart';
import 'package:fitness_app/features/chat/models/chat_conversation.dart';
import 'package:fitness_app/features/chat/models/chat_message.dart';
import 'package:fitness_app/features/chat/services/chat_realtime_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Test harness fake for ChatRealtimeService to precisely control network
/// timing, simulated latency jitter, failures, and Realtime event injection.
class TestableChatRealtimeService extends ChatRealtimeService {
  TestableChatRealtimeService({
    this.sendDelay = Duration.zero,
    this.delayGenerator,
    this.shouldFailSend = false,
    this.failureError,
    this.currentUserIdOverride = 'athlete-user-1',
  });

  Duration sendDelay;
  Duration Function(int index)? delayGenerator;
  bool shouldFailSend;
  Object? failureError;
  final String currentUserIdOverride;

  int sendCount = 0;
  final List<Map<String, dynamic>> recordedSentPayloads = [];

  void Function(ChatMessage)? capturedOnMessageReceived;
  void Function(ChatMessage)? capturedOnMessageUpdated;
  void Function(String, {required bool isTyping})? capturedOnTypingStatus;
  String? activeSubscribedConvId;
  bool wasUnsubscribed = false;

  @override
  String get currentUserId => currentUserIdOverride;

  @override
  Future<ChatConversation> getOrCreateConversation({
    required String trainerId,
    String? trainerUserId,
    String? trainerName,
  }) async {
    return ChatConversation(
      id: 'conv-adversarial-1',
      userId: currentUserId,
      trainerId: trainerId,
      trainerUserId: trainerUserId ?? 'coach-user-1',
      createdAt: DateTime.utc(2026, 10, 14, 10),
      updatedAt: DateTime.utc(2026, 10, 14, 10),
      trainerName: trainerName ?? 'Coach',
    );
  }

  @override
  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String plaintext,
    required String recipientUserId,
    String? clientUuid,
  }) async {
    final idx = sendCount++;
    final delay = delayGenerator != null ? delayGenerator!(idx) : sendDelay;
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }

    if (shouldFailSend) {
      final err = failureError;
      if (err is Exception) {
        throw err;
      } else if (err is Error) {
        throw err;
      } else {
        throw Exception(
          err?.toString() ??
              'Simulated network connection drop during sendMessage',
        );
      }
    }

    final effectiveClientUuid = clientUuid ?? 'gen-uuid-$idx';
    final payload = <String, dynamic>{
      'conversation_id': conversationId,
      'plaintext': plaintext,
      'recipient_user_id': recipientUserId,
      'client_uuid': effectiveClientUuid,
    };
    recordedSentPayloads.add(payload);

    return ChatMessage(
      id: 'db-msg-id-$idx',
      conversationId: conversationId,
      senderId: currentUserId,
      clientUuid: effectiveClientUuid,
      ciphertext: 'ciphertext_for_$plaintext',
      nonce: 'nonce_for_$plaintext',
      createdAt: DateTime.now().toUtc(),
      plaintext: plaintext,
      isOutgoing: true,
    );
  }

  @override
  Future<void> subscribeToConversation(
    String conversationId, {
    required void Function(ChatMessage message) onMessageReceived,
    required void Function(ChatMessage message) onMessageUpdated,
    String? recipientUserId,
    void Function(String userId, {required bool isTyping})? onTypingStatus,
  }) async {
    activeSubscribedConvId = conversationId;
    wasUnsubscribed = false;
    capturedOnMessageReceived = onMessageReceived;
    capturedOnMessageUpdated = onMessageUpdated;
    capturedOnTypingStatus = onTypingStatus;
  }

  @override
  Future<void> unsubscribe() async {
    wasUnsubscribed = true;
    activeSubscribedConvId = null;
    capturedOnMessageReceived = null;
    capturedOnMessageUpdated = null;
    capturedOnTypingStatus = null;
  }

  int markAsReadCount = 0;
  @override
  Future<void> markConversationAsRead(String conversationId) async {
    markAsReadCount++;
  }

  int typingIndicatorSendCount = 0;
  @override
  Future<void> sendTypingIndicator({
    required String conversationId,
    required bool isTyping,
  }) async {
    typingIndicatorSendCount++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    ChatRealtimeService.resetMockData();
  });

  final dummyConv = ChatConversation(
    id: 'conv-adversarial-1',
    userId: 'athlete-user-1',
    trainerId: 'trainer-profile-1',
    trainerUserId: 'coach-user-1',
    createdAt: DateTime.utc(2026, 10, 14, 10),
    updatedAt: DateTime.utc(2026, 10, 14, 10),
  );

  // =========================================================================
  // Challenge 1: Burst Message Dispatch & Concurrency Resilience
  // =========================================================================
  group('Challenge 1: Burst Message Dispatch (50 Rapid Sends)', () {
    test(
      '50 rapid sequential/concurrent sends produces exactly 50 messages, '
      'zero dropped, zero races',
      () async {
        final service = TestableChatRealtimeService();
        final bloc = ChatBloc(chatService: service)
          ..emit(
            ChatRoomActive(
              conversation: dummyConv,
              messages: const <ChatMessage>[],
            ),
          );

        const totalBurst = 50;
        for (var i = 0; i < totalBurst; i++) {
          bloc.add(
            SendMessage(
              conversationId: dummyConv.id,
              plaintext: 'Burst message #$i',
              recipientUserId: 'coach-user-1',
              clientUuid: 'burst-uuid-$i',
            ),
          );
        }

        // Wait for all async bloc event dispatches to settle
        await Future<void>.delayed(const Duration(milliseconds: 300));

        final finalState = bloc.state;
        expect(finalState, isA<ChatRoomActive>());
        final activeState = finalState as ChatRoomActive;

        // Invariant 1: Exactly 50 messages exist
        expect(
          activeState.messages.length,
          totalBurst,
          reason: 'Expected $totalBurst messages, got '
              '${activeState.messages.length}',
        );

        // Invariant 2: Every single message transitioned from sending to sent
        for (var i = 0; i < totalBurst; i++) {
          final msg = activeState.messages[i];
          expect(msg.clientUuid, 'burst-uuid-$i');
          expect(msg.plaintext, 'Burst message #$i');
          expect(
            msg.deliveryStatus,
            MessageDeliveryStatus.sent,
            reason: 'Message $i (uuid: burst-uuid-$i) was not in sent status',
          );
        }

        // Invariant 3: Service recorded all 50 transmissions
        expect(service.sendCount, totalBurst);

        await bloc.close();
      },
    );

    test(
      '50 concurrent sends with randomized network jitter complete without '
      'dropping or clobbering',
      () async {
        final rng = Random(42);
        final service = TestableChatRealtimeService(
          delayGenerator: (index) {
            // Random jitter between 1 and 25 ms
            return Duration(milliseconds: 1 + rng.nextInt(25));
          },
        );

        final bloc = ChatBloc(chatService: service)
          ..emit(
            ChatRoomActive(
              conversation: dummyConv,
              messages: const <ChatMessage>[],
            ),
          );

        const totalBurst = 50;
        for (var i = 0; i < totalBurst; i++) {
          bloc.add(
            SendMessage(
              conversationId: dummyConv.id,
              plaintext: 'Jitter message #$i',
              recipientUserId: 'coach-user-1',
              clientUuid: 'jitter-uuid-$i',
            ),
          );
        }

        // Allow all randomized futures to complete
        await Future<void>.delayed(const Duration(milliseconds: 1200));

        final finalState = bloc.state as ChatRoomActive;
        expect(finalState.messages.length, totalBurst);

        final deliveredCount = finalState.messages
            .where((m) => m.deliveryStatus == MessageDeliveryStatus.sent)
            .length;
        expect(
          deliveredCount,
          totalBurst,
          reason: 'All $totalBurst jittered messages should be marked sent',
        );

        await bloc.close();
      },
    );

    test(
      'Zero-knowledge wire invariant verified across all 50 burst sends',
      () async {
        final service = TestableChatRealtimeService();
        final bloc = ChatBloc(chatService: service)
          ..emit(
            ChatRoomActive(
              conversation: dummyConv,
              messages: const <ChatMessage>[],
            ),
          );

        for (var i = 0; i < 50; i++) {
          bloc.add(
            SendMessage(
              conversationId: dummyConv.id,
              plaintext: 'Classified payload #$i',
              recipientUserId: 'coach-user-1',
              clientUuid: 'zk-uuid-$i',
            ),
          );
        }

        await Future<void>.delayed(const Duration(milliseconds: 250));

        final activeState = bloc.state as ChatRoomActive;
        for (final msg in activeState.messages) {
          final json = msg.toJson();
          expect(json.containsKey('plaintext'), isFalse);
          expect(json.containsKey('client_uuid'), isTrue);
          expect(json.containsKey('ciphertext'), isTrue);
          expect(json.containsKey('nonce'), isTrue);
        }

        await bloc.close();
      },
    );
  });

  // =========================================================================
  // Challenge 2: Real-time Duplicate Delivery & Idempotency
  // =========================================================================
  group('Challenge 2: Real-time Duplicate Delivery & Deduplication', () {
    test(
      'Realtime delivering INSERT event with identical clientUuid keeps list '
      'length strictly 1 and updates sending to sent',
      () async {
        final service = TestableChatRealtimeService(
          sendDelay: const Duration(milliseconds: 100),
        );
        final bloc = ChatBloc(chatService: service)
          ..emit(
            ChatRoomActive(
              conversation: dummyConv,
              messages: const <ChatMessage>[],
            ),
          )
          // 1. Dispatch SendMessage (optimistically in sending state)
          ..add(
            SendMessage(
              conversationId: dummyConv.id,
              plaintext: 'Optimistic message to be confirmed by Realtime',
              recipientUserId: 'coach-user-1',
              clientUuid: 'realtime-dedup-uuid-1',
            ),
          );

        // Give microtask time to add optimistic entry
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final optimisticState = bloc.state as ChatRoomActive;
        expect(optimisticState.messages.length, 1);
        expect(
          optimisticState.messages.first.deliveryStatus,
          MessageDeliveryStatus.sending,
        );

        // 2. Realtime delivers INSERT event before sendMessage HTTP completes
        bloc.add(
          MessageReceived(
            ChatMessage(
              id: 'server-db-id-from-realtime-1',
              conversationId: dummyConv.id,
              senderId: 'athlete-user-1',
              clientUuid: 'realtime-dedup-uuid-1',
              ciphertext: 'encrypted-ciphertext-realtime',
              nonce: 'nonce-realtime',
              createdAt: DateTime.now().toUtc(),
            ),
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 15));

        final realtimeConfirmedState = bloc.state as ChatRoomActive;
        // Invariant: List length must remain strictly 1
        expect(
          realtimeConfirmedState.messages.length,
          1,
          reason: 'Duplicate entry created on Realtime delivery',
        );
        expect(
          realtimeConfirmedState.messages.first.id,
          'server-db-id-from-realtime-1',
        );
        expect(
          realtimeConfirmedState.messages.first.deliveryStatus,
          MessageDeliveryStatus.sent,
        );
        // Plaintext must be preserved from optimistic message!
        expect(
          realtimeConfirmedState.messages.first.plaintext,
          'Optimistic message to be confirmed by Realtime',
        );

        // 3. Now let HTTP sendMessage finish
        await Future<void>.delayed(const Duration(milliseconds: 150));

        final finalState = bloc.state as ChatRoomActive;
        expect(finalState.messages.length, 1);
        expect(
          finalState.messages.first.deliveryStatus,
          MessageDeliveryStatus.sent,
        );

        await bloc.close();
      },
    );

    test(
      'Realtime duplicate storm (5 identical broadcast INSERT events) '
      'maintains message list length == 1',
      () async {
        final service = TestableChatRealtimeService();
        final bloc = ChatBloc(chatService: service)
          ..emit(
            ChatRoomActive(
              conversation: dummyConv,
              messages: [
                ChatMessage.createOptimistic(
                  conversationId: dummyConv.id,
                  senderId: 'athlete-user-1',
                  clientUuid: 'storm-uuid-1',
                  plaintext: 'Storm test message',
                  ciphertext: '',
                  nonce: '',
                ),
              ],
            ),
          );

        // Fire 5 identical INSERT events
        for (var i = 0; i < 5; i++) {
          bloc.add(
            MessageReceived(
              ChatMessage(
                id: 'server-msg-storm-1',
                conversationId: dummyConv.id,
                senderId: 'athlete-user-1',
                clientUuid: 'storm-uuid-1',
                ciphertext: 'storm-ciphertext',
                nonce: 'storm-nonce',
                createdAt: DateTime.now().toUtc(),
              ),
            ),
          );
        }

        await Future<void>.delayed(const Duration(milliseconds: 50));

        final state = bloc.state as ChatRoomActive;
        expect(state.messages.length, 1);
        expect(state.messages.first.deliveryStatus, MessageDeliveryStatus.sent);
        expect(state.messages.first.plaintext, 'Storm test message');

        await bloc.close();
      },
    );
  });

  // =========================================================================
  // Challenge 3: Late Delivery & Out-of-Order Message Handling
  // =========================================================================
  group('Challenge 3: Late Delivery & Out-of-Order Message Handling', () {
    test(
      'Out-of-order HTTP completions: Message 1 delayed, Message 2 fast; '
      'both transition to sent without corruption',
      () async {
        final service = TestableChatRealtimeService(
          delayGenerator: (idx) {
            // First message takes 120ms, second message takes 20ms
            return idx == 0
                ? const Duration(milliseconds: 120)
                : const Duration(milliseconds: 20);
          },
        );

        final bloc = ChatBloc(chatService: service)
          ..emit(
            ChatRoomActive(
              conversation: dummyConv,
              messages: const <ChatMessage>[],
            ),
          )
          ..add(
            SendMessage(
              conversationId: dummyConv.id,
              plaintext: 'First message (slow network)',
              recipientUserId: 'coach-user-1',
              clientUuid: 'slow-msg-1',
            ),
          );

        // Short wait then send second message
        await Future<void>.delayed(const Duration(milliseconds: 10));

        bloc.add(
          SendMessage(
            conversationId: dummyConv.id,
            plaintext: 'Second message (fast network)',
            recipientUserId: 'coach-user-1',
            clientUuid: 'fast-msg-2',
          ),
        );

        // After 60ms, fast message completed, slow message still sending
        await Future<void>.delayed(const Duration(milliseconds: 60));
        final intermediateState = bloc.state as ChatRoomActive;
        expect(intermediateState.messages.length, 2);
        expect(intermediateState.messages[0].clientUuid, 'slow-msg-1');
        expect(
          intermediateState.messages[0].deliveryStatus,
          MessageDeliveryStatus.sending,
        );
        expect(intermediateState.messages[1].clientUuid, 'fast-msg-2');
        expect(
          intermediateState.messages[1].deliveryStatus,
          MessageDeliveryStatus.sent,
        );

        // After 180ms total, both should be sent
        await Future<void>.delayed(const Duration(milliseconds: 100));
        final finalState = bloc.state as ChatRoomActive;
        expect(finalState.messages.length, 2);
        expect(
          finalState.messages[0].deliveryStatus,
          MessageDeliveryStatus.sent,
        );
        expect(
          finalState.messages[1].deliveryStatus,
          MessageDeliveryStatus.sent,
        );
        expect(
          finalState.messages[0].plaintext,
          'First message (slow network)',
        );
        expect(
          finalState.messages[1].plaintext,
          'Second message (fast network)',
        );

        await bloc.close();
      },
    );

    test(
      'Inbound peer messages arriving out of chronological order are appended',
      () async {
        final service = TestableChatRealtimeService();
        final bloc = ChatBloc(chatService: service)
          ..emit(
            ChatRoomActive(
              conversation: dummyConv,
              messages: const <ChatMessage>[],
            ),
          );

        final now = DateTime.now().toUtc();
        // Message with later timestamp arrives first
        final msgLater = ChatMessage(
          id: 'peer-msg-2',
          conversationId: dummyConv.id,
          senderId: 'coach-user-1',
          clientUuid: 'peer-uuid-2',
          ciphertext: 'cipher2',
          nonce: 'nonce2',
          createdAt: now.add(const Duration(seconds: 10)),
          plaintext: 'Second reply from coach',
        );

        // Message with earlier timestamp arrives late
        final msgEarlier = ChatMessage(
          id: 'peer-msg-1',
          conversationId: dummyConv.id,
          senderId: 'coach-user-1',
          clientUuid: 'peer-uuid-1',
          ciphertext: 'cipher1',
          nonce: 'nonce1',
          createdAt: now,
          plaintext: 'First reply from coach',
        );

        bloc.add(MessageReceived(msgLater));
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(MessageReceived(msgEarlier));
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final state = bloc.state as ChatRoomActive;
        expect(state.messages.length, 2);
        expect(
          state.messages.map((m) => m.clientUuid),
          containsAll(['peer-uuid-2', 'peer-uuid-1']),
        );
        expect(service.markAsReadCount, greaterThanOrEqualTo(2));

        await bloc.close();
      },
    );

    test(
      'MessageUpdated for read receipt sets delivered status without clobber',
      () async {
        final service = TestableChatRealtimeService();
        final initialMsg = ChatMessage(
          id: 'msg-read-check',
          conversationId: dummyConv.id,
          senderId: 'athlete-user-1',
          clientUuid: 'read-check-uuid',
          ciphertext: 'c',
          nonce: 'n',
          createdAt: DateTime.now().toUtc(),
          plaintext: 'Did you see this?',
        );

        final bloc = ChatBloc(chatService: service)
          ..emit(
            ChatRoomActive(
              conversation: dummyConv,
              messages: [initialMsg],
            ),
          );

        final readAt = DateTime.now().toUtc();
        bloc.add(
          MessageUpdated(
            initialMsg.copyWith(
              isRead: true,
              readAt: readAt,
            ),
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 10));

        final state = bloc.state as ChatRoomActive;
        expect(state.messages.length, 1);
        final updated = state.messages.first;
        expect(updated.isRead, isTrue);
        expect(updated.deliveryStatus, MessageDeliveryStatus.delivered);
        expect(updated.plaintext, 'Did you see this?');

        await bloc.close();
      },
    );
  });

  // =========================================================================
  // Challenge 4: Message Send Failure & Retry State Flow
  // =========================================================================
  group('Challenge 4: Message Send Failure & Retry State Flow', () {
    test(
      'Message send failure keeps message in list with failed status and error',
      () async {
        final service = TestableChatRealtimeService(
          shouldFailSend: true,
          failureError: Exception('Supabase 503 Service Unavailable'),
        );

        final bloc = ChatBloc(chatService: service)
          ..emit(
            ChatRoomActive(
              conversation: dummyConv,
              messages: const <ChatMessage>[],
            ),
          )
          ..add(
            SendMessage(
              conversationId: dummyConv.id,
              plaintext: 'Crucial workout data',
              recipientUserId: 'coach-user-1',
              clientUuid: 'fail-uuid-1',
            ),
          );

        await Future<void>.delayed(const Duration(milliseconds: 50));

        final state = bloc.state as ChatRoomActive;
        // Invariant 1: Message is NOT removed from list
        expect(state.messages.length, 1);
        // Invariant 2: Delivery status is failed
        expect(
          state.messages.first.deliveryStatus,
          MessageDeliveryStatus.failed,
        );
        // Invariant 3: Plaintext is preserved
        expect(state.messages.first.plaintext, 'Crucial workout data');
        // Invariant 4: Error message is populated on state
        expect(state.errorMessage, contains('503 Service Unavailable'));

        await bloc.close();
      },
    );

    test(
      'ADVERSARIAL CHECK: RetrySendMessage re-attempts transmission without '
      'duplicating message count',
      () async {
        final service = TestableChatRealtimeService(
          shouldFailSend: true,
          failureError: Exception('SocketException: Connection refused'),
        );

        final bloc = ChatBloc(chatService: service)
          ..emit(
            ChatRoomActive(
              conversation: dummyConv,
              messages: const <ChatMessage>[],
            ),
          )
          // 1. Send message that fails
          ..add(
            SendMessage(
              conversationId: dummyConv.id,
              plaintext: 'Retry test message',
              recipientUserId: 'coach-user-1',
              clientUuid: 'retry-check-uuid-1',
            ),
          );

        await Future<void>.delayed(const Duration(milliseconds: 30));

        final failState = bloc.state as ChatRoomActive;
        expect(failState.messages.length, 1);
        expect(
          failState.messages.first.deliveryStatus,
          MessageDeliveryStatus.failed,
        );
        expect(failState.messages.first.plaintext, 'Retry test message');

        // 2. Now network heals: configure service to succeed
        service.shouldFailSend = false;

        // 3. User taps retry
        bloc.add(const RetrySendMessage(clientUuid: 'retry-check-uuid-1'));

        await Future<void>.delayed(const Duration(milliseconds: 50));

        final retriedState = bloc.state as ChatRoomActive;

        // EMPIRICAL VERIFICATION:
        // Does retrying the message maintain strictly 1 message in the room,
        // or does it duplicate the entry?
        expect(
          retriedState.messages.length,
          1,
          reason: 'RetrySendMessage MUST NOT duplicate the message in the list.'
              ' Expected 1 message, got ${retriedState.messages.length}',
        );
        expect(
          retriedState.messages.first.deliveryStatus,
          MessageDeliveryStatus.sent,
          reason: 'Retried message should now have status sent',
        );
        expect(
          retriedState.messages.first.plaintext,
          'Retry test message',
          reason: 'Message text must not be clobbered upon retry',
        );

        await bloc.close();
      },
    );

    test(
      'RetrySendMessage fails again: keeps strictly 1 message in list with '
      'failed status',
      () async {
        final service = TestableChatRealtimeService(
          shouldFailSend: true,
          failureError: Exception('TimeoutException: network timeout'),
        );

        final bloc = ChatBloc(chatService: service)
          ..emit(
            ChatRoomActive(
              conversation: dummyConv,
              messages: const <ChatMessage>[],
            ),
          )
          ..add(
            SendMessage(
              conversationId: dummyConv.id,
              plaintext: 'Persistently failing message',
              recipientUserId: 'coach-user-1',
              clientUuid: 'fail-persist-uuid',
            ),
          );
        await Future<void>.delayed(const Duration(milliseconds: 30));

        // Retry while still failing
        bloc.add(const RetrySendMessage(clientUuid: 'fail-persist-uuid'));
        await Future<void>.delayed(const Duration(milliseconds: 30));

        final state = bloc.state as ChatRoomActive;
        expect(
          state.messages.length,
          1,
          reason: 'Repeated failure during retry must not duplicate the '
              'message. Found ${state.messages.length}',
        );
        expect(
          state.messages.first.deliveryStatus,
          MessageDeliveryStatus.failed,
        );
        expect(
          state.messages.first.plaintext,
          'Persistently failing message',
        );

        await bloc.close();
      },
    );
  });

  // =========================================================================
  // Challenge 5: Room Lifecycle, Typing Indicators & Clean Tear-down
  // =========================================================================
  group('Challenge 5: Room Lifecycle, Typing Indicators & Clean Tear-down', () {
    test(
      'CloseConversation cleans up subscription and resets active room',
      () async {
        final service = TestableChatRealtimeService();
        final bloc = ChatBloc(chatService: service)
          ..add(
            OpenConversation(
              conversationId: dummyConv.id,
              trainerId: dummyConv.trainerId,
              trainerUserId: dummyConv.trainerUserId,
            ),
          );

        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(service.activeSubscribedConvId, dummyConv.id);

        bloc.add(const CloseConversation());
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(service.wasUnsubscribed, isTrue);

        await bloc.close();
      },
    );

    test(
      'TypingIndicatorReceived toggles isPeerTyping true and false cleanly',
      () async {
        final service = TestableChatRealtimeService();
        final bloc = ChatBloc(chatService: service)
          ..emit(
            ChatRoomActive(
              conversation: dummyConv,
              messages: const <ChatMessage>[],
            ),
          )
          ..add(
            TypingIndicatorReceived(
              conversationId: dummyConv.id,
              userId: 'coach-user-1',
              isTyping: true,
            ),
          );

        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect((bloc.state as ChatRoomActive).isPeerTyping, isTrue);

        bloc.add(
          TypingIndicatorReceived(
            conversationId: dummyConv.id,
            userId: 'coach-user-1',
            isTyping: false,
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect((bloc.state as ChatRoomActive).isPeerTyping, isFalse);

        await bloc.close();
      },
    );
  });
}
