import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:fitness_app/features/chat/bloc/chat_event.dart';
import 'package:fitness_app/features/chat/bloc/chat_state.dart';
import 'package:fitness_app/features/chat/models/chat_conversation.dart';
import 'package:fitness_app/features/chat/models/chat_message.dart';
import 'package:fitness_app/features/chat/services/chat_realtime_service.dart';
import 'package:uuid/uuid.dart';

/// Business Logic Component managing E2EE chat state, optimistic dispatch,
/// client UUID deduplication, Realtime subscriptions, and read receipts.
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc({
    ChatRealtimeService? chatService,
    Uuid? uuid,
  }) : _chatService = chatService ?? ChatRealtimeService(),
       _uuid = uuid ?? const Uuid(),
       super(const ChatInitial()) {
    on<LoadConversations>(_onLoadConversations);
    on<OpenConversation>(_onOpenConversation);
    on<SendMessage>(_onSendMessage);
    on<RetrySendMessage>(_onRetrySendMessage);
    on<MessageReceived>(_onMessageReceived);
    on<MessageUpdated>(_onMessageUpdated);
    on<MarkConversationRead>(_onMarkConversationRead);
    on<SendTypingIndicator>(_onSendTypingIndicator);
    on<TypingIndicatorReceived>(_onTypingIndicatorReceived);
    on<CloseConversation>(_onCloseConversation);
  }

  final ChatRealtimeService _chatService;
  final Uuid _uuid;

  List<ChatConversation> _cachedConversations = const <ChatConversation>[];
  Timer? _typingDebounceTimer;

  // ── Conversation List Loading ─────────────────────────────────────

  Future<void> _onLoadConversations(
    LoadConversations event,
    Emitter<ChatState> emit,
  ) async {
    emit(const ChatConversationsLoading());
    try {
      final conversations = await _chatService.getConversations(
        forceRefresh: event.forceRefresh,
      );
      _cachedConversations = conversations;
      emit(ChatConversationsLoaded(conversations: conversations));
    } on Object catch (e) {
      emit(ChatError('Failed to load conversations: $e'));
    }
  }

  // ── Open Active Chat Room ─────────────────────────────────────────

  Future<void> _onOpenConversation(
    OpenConversation event,
    Emitter<ChatState> emit,
  ) async {
    emit(ChatRoomLoading(conversationId: event.conversationId));

    try {
      // 1. Resolve or create conversation
      ChatConversation? conversation;
      if (event.trainerId != null) {
        conversation = await _chatService.getOrCreateConversation(
          trainerId: event.trainerId!,
          trainerUserId: event.trainerUserId,
          trainerName: event.trainerName,
        );
      } else {
        conversation = _cachedConversations.firstWhere(
          (c) => c.id == event.conversationId,
          orElse: () => ChatConversation(
            id: event.conversationId,
            userId: _chatService.currentUserId,
            trainerId: event.trainerId ?? '',
            trainerUserId: event.trainerUserId,
            trainerName: event.trainerName,
            createdAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
      }

      final peerUserId = conversation.getOtherParticipantUserId(
        _chatService.currentUserId,
      );

      // 2. Fetch history and decrypt in memory
      final messages = await _chatService.getMessages(
        conversationId: conversation.id,
        recipientUserId: peerUserId,
      );

      // 3. Attach Realtime Channel
      await _chatService.subscribeToConversation(
        conversation.id,
        recipientUserId: peerUserId,
        onMessageReceived: (msg) => add(MessageReceived(msg)),
        onMessageUpdated: (msg) => add(MessageUpdated(msg)),
        onTypingStatus: (uid, {required isTyping}) => add(
          TypingIndicatorReceived(
            conversationId: conversation!.id,
            userId: uid,
            isTyping: isTyping,
          ),
        ),
      );

      // 4. Mark unread messages as read
      add(MarkConversationRead(conversation.id));

      emit(
        ChatRoomActive(
          conversation: conversation,
          messages: messages,
        ),
      );
    } on Object catch (e) {
      emit(ChatError('Failed to open chat room: $e'));
    }
  }

  // ── Optimistic Message Sending & Deduplication ─────────────────────

  Future<void> _onSendMessage(
    SendMessage event,
    Emitter<ChatState> emit,
  ) async {
    if (state is! ChatRoomActive) return;
    final currentState = state as ChatRoomActive;

    final clientUuid = event.clientUuid ?? _uuid.v4();
    final effectiveRecipient = event.recipientUserId.isNotEmpty
        ? event.recipientUserId
        : currentState.conversation.getOtherParticipantUserId(
            _chatService.currentUserId,
          );

    // Step 1: Create optimistic message for instantaneous UI rendering
    final optimisticMessage = ChatMessage.createOptimistic(
      conversationId: event.conversationId,
      senderId: _chatService.currentUserId,
      clientUuid: clientUuid,
      plaintext: event.plaintext,
      ciphertext: '', // Temporarily empty in local UI until encrypted
      nonce: '',
    );

    final updatedMessages = List<ChatMessage>.from(currentState.messages);
    final existingIndex = updatedMessages.indexWhere(
      (m) => m.clientUuid == clientUuid,
    );

    if (existingIndex >= 0) {
      // Retry flow: transition existing message in-place without duplicating
      updatedMessages[existingIndex] = updatedMessages[existingIndex].copyWith(
        deliveryStatus: MessageDeliveryStatus.sending,
        plaintext: event.plaintext,
      );
    } else {
      // New message: add optimistic placeholder
      updatedMessages.add(optimisticMessage);
    }

    emit(currentState.copyWith(messages: updatedMessages));

    // Step 2: Encrypt and send to Supabase
    try {
      final confirmed = await _chatService.sendMessage(
        conversationId: event.conversationId,
        plaintext: event.plaintext,
        recipientUserId: effectiveRecipient,
        clientUuid: clientUuid,
      );

      // Step 3: Replace optimistic placeholder with server-confirmed message
      if (state is ChatRoomActive) {
        final activeState = state as ChatRoomActive;
        final list = List<ChatMessage>.from(activeState.messages);
        final idx = list.indexWhere((m) => m.clientUuid == clientUuid);

        if (idx >= 0) {
          list[idx] = confirmed.copyWith(
            plaintext: event.plaintext,
            deliveryStatus: MessageDeliveryStatus.sent,
          );
          emit(activeState.copyWith(messages: list));
        }
      }
    } on Object catch (e) {
      // Step 4: Mark message as failed if network error occurs
      if (state is ChatRoomActive) {
        final activeState = state as ChatRoomActive;
        final list = List<ChatMessage>.from(activeState.messages);
        final idx = list.indexWhere((m) => m.clientUuid == clientUuid);

        if (idx >= 0) {
          list[idx] = list[idx].copyWith(
            deliveryStatus: MessageDeliveryStatus.failed,
          );
          emit(
            activeState.copyWith(
              messages: list,
              errorMessage: 'Message delivery failed: $e',
            ),
          );
        }
      }
    }
  }

  // ── Retry Failed Message ──────────────────────────────────────────

  Future<void> _onRetrySendMessage(
    RetrySendMessage event,
    Emitter<ChatState> emit,
  ) async {
    if (state is! ChatRoomActive) return;
    final currentState = state as ChatRoomActive;

    final existing = currentState.messages.firstWhere(
      (m) => m.clientUuid == event.clientUuid,
      orElse: () => throw Exception('Message not found for retry'),
    );

    final text = existing.plaintext;
    if (text == null || text.isEmpty) return;

    final peerUserId = currentState.conversation.getOtherParticipantUserId(
      _chatService.currentUserId,
    );

    // Re-dispatch SendMessage reusing the exact same clientUuid for idempotency
    add(
      SendMessage(
        conversationId: currentState.conversation.id,
        plaintext: text,
        recipientUserId: peerUserId,
        clientUuid: existing.clientUuid,
      ),
    );
  }

  // ── Realtime Inbound Message (Deduplication Check) ─────────────────

  void _onMessageReceived(
    MessageReceived event,
    Emitter<ChatState> emit,
  ) {
    if (state is! ChatRoomActive) return;
    final currentState = state as ChatRoomActive;

    final list = List<ChatMessage>.from(currentState.messages);
    final existingIndex = list.indexWhere(
      (m) => m.clientUuid == event.message.clientUuid,
    );

    if (existingIndex >= 0) {
      // DEDUPLICATION: Message was sent by us and confirmed via broadcast
      final existing = list[existingIndex];
      list[existingIndex] = event.message.copyWith(
        plaintext: existing.plaintext, // Preserve decrypted plaintext
        deliveryStatus: MessageDeliveryStatus.sent,
      );
      emit(currentState.copyWith(messages: list));
    } else {
      // INBOUND MESSAGE: Incoming message from peer
      list.add(event.message);
      emit(currentState.copyWith(messages: list));

      // Auto-read incoming message if user is actively viewing this room
      if (event.message.senderId != _chatService.currentUserId) {
        add(MarkConversationRead(currentState.conversation.id));
      }
    }
  }

  // ── Read Receipts & Status Updates ────────────────────────────────

  void _onMessageUpdated(
    MessageUpdated event,
    Emitter<ChatState> emit,
  ) {
    if (state is! ChatRoomActive) return;
    final currentState = state as ChatRoomActive;

    final list = List<ChatMessage>.from(currentState.messages);
    final idx = list.indexWhere(
      (m) =>
          m.id == event.message.id || m.clientUuid == event.message.clientUuid,
    );

    if (idx >= 0) {
      final existing = list[idx];
      list[idx] = existing.copyWith(
        isRead: event.message.isRead,
        readAt: event.message.readAt,
        deliveryStatus: event.message.isRead
            ? MessageDeliveryStatus.delivered
            : existing.deliveryStatus,
      );
      emit(currentState.copyWith(messages: list));
    }
  }

  Future<void> _onMarkConversationRead(
    MarkConversationRead event,
    Emitter<ChatState> emit,
  ) async {
    await _chatService.markConversationAsRead(event.conversationId);
  }

  // ── Ephemeral Typing Indicators ───────────────────────────────────

  void _onSendTypingIndicator(
    SendTypingIndicator event,
    Emitter<ChatState> emit,
  ) {
    _chatService.sendTypingIndicator(
      conversationId: event.conversationId,
      isTyping: event.isTyping,
    );
  }

  void _onTypingIndicatorReceived(
    TypingIndicatorReceived event,
    Emitter<ChatState> emit,
  ) {
    if (state is! ChatRoomActive) return;
    final currentState = state as ChatRoomActive;

    _typingDebounceTimer?.cancel();

    if (event.isTyping) {
      emit(currentState.copyWith(isPeerTyping: true));
      // Auto-clear typing indicator after 4 seconds of inactivity
      _typingDebounceTimer = Timer(const Duration(seconds: 4), () {
        if (!isClosed && state is ChatRoomActive) {
          add(
            TypingIndicatorReceived(
              conversationId: event.conversationId,
              userId: event.userId,
              isTyping: false,
            ),
          );
        }
      });
    } else {
      emit(currentState.copyWith(isPeerTyping: false));
    }
  }

  // ── Room Close & Cleanup ──────────────────────────────────────────

  Future<void> _onCloseConversation(
    CloseConversation event,
    Emitter<ChatState> emit,
  ) async {
    _typingDebounceTimer?.cancel();
    await _chatService.unsubscribe();
    add(const LoadConversations(forceRefresh: true));
  }

  @override
  Future<void> close() {
    _typingDebounceTimer?.cancel();
    _chatService.dispose();
    return super.close();
  }
}
