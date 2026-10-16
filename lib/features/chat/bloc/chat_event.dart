import 'package:equatable/equatable.dart';
import 'package:fitness_app/features/chat/models/chat_message.dart';

/// Base class for all events handled by ChatBloc.
abstract class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

/// Dispatched to load the user's active conversations list.
class LoadConversations extends ChatEvent {
  const LoadConversations({this.forceRefresh = false});

  final bool forceRefresh;

  @override
  List<Object?> get props => [forceRefresh];
}

/// Dispatched to open a 1-on-1 chat room with a coach/athlete.
class OpenConversation extends ChatEvent {
  const OpenConversation({
    required this.conversationId,
    this.trainerId,
    this.trainerUserId,
    this.trainerName,
  });

  final String conversationId;
  final String? trainerId;
  final String? trainerUserId;
  final String? trainerName;

  @override
  List<Object?> get props => [
    conversationId,
    trainerId,
    trainerUserId,
    trainerName,
  ];
}

/// Dispatched to send an E2EE encrypted message.
class SendMessage extends ChatEvent {
  const SendMessage({
    required this.conversationId,
    required this.plaintext,
    this.recipientUserId = '',
    this.clientUuid,
  });

  final String conversationId;
  final String plaintext;
  String get content => plaintext;
  final String recipientUserId;
  final String? clientUuid;

  @override
  List<Object?> get props => [
    conversationId,
    plaintext,
    recipientUserId,
    clientUuid,
  ];
}

/// Dispatched to retry a message that failed to deliver.
class RetrySendMessage extends ChatEvent {
  const RetrySendMessage({required this.clientUuid});

  final String clientUuid;

  @override
  List<Object?> get props => [clientUuid];
}

/// Alias for [RetrySendMessage] for compatibility.
typedef RetryMessageSend = RetrySendMessage;

/// Dispatched when Supabase Realtime delivers a new message.
class MessageReceived extends ChatEvent {
  const MessageReceived(this.message);

  final ChatMessage message;

  @override
  List<Object?> get props => [message];
}

/// Dispatched when Realtime delivers a message status update (read receipt).
class MessageUpdated extends ChatEvent {
  const MessageUpdated(this.message);

  final ChatMessage message;

  @override
  List<Object?> get props => [message];
}

/// Dispatched to mark unread messages in the active room as read.
class MarkConversationRead extends ChatEvent {
  const MarkConversationRead(this.conversationId);

  final String conversationId;

  @override
  List<Object?> get props => [conversationId];
}

/// Dispatched when current user types or stops typing.
class SendTypingIndicator extends ChatEvent {
  const SendTypingIndicator({
    required this.conversationId,
    required this.isTyping,
  });

  final String conversationId;
  final bool isTyping;

  @override
  List<Object?> get props => [conversationId, isTyping];
}

/// Dispatched when peer typing indicator broadcast is received.
class TypingIndicatorReceived extends ChatEvent {
  const TypingIndicatorReceived({
    required this.conversationId,
    required this.userId,
    required this.isTyping,
  });

  final String conversationId;
  final String userId;
  final bool isTyping;

  @override
  List<Object?> get props => [conversationId, userId, isTyping];
}

/// Dispatched when exiting the active chat room back to conversation list.
class CloseConversation extends ChatEvent {
  const CloseConversation();
}
