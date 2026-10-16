import 'package:equatable/equatable.dart';
import 'package:fitness_app/features/chat/models/chat_conversation.dart';
import 'package:fitness_app/features/chat/models/chat_message.dart';

/// Base class for all states emitted by ChatBloc.
abstract class ChatState extends Equatable {
  const ChatState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any chat data has been loaded.
class ChatInitial extends ChatState {
  const ChatInitial();
}

/// Emitted while querying conversation list.
class ChatConversationsLoading extends ChatState {
  const ChatConversationsLoading();
}

/// Emitted when conversations have loaded successfully.
class ChatConversationsLoaded extends ChatState {
  const ChatConversationsLoaded({
    required this.conversations,
    this.activeConversation,
  });

  final List<ChatConversation> conversations;
  final ChatConversation? activeConversation;

  ChatConversationsLoaded copyWith({
    List<ChatConversation>? conversations,
    ChatConversation? activeConversation,
  }) {
    return ChatConversationsLoaded(
      conversations: conversations ?? this.conversations,
      activeConversation: activeConversation ?? this.activeConversation,
    );
  }

  @override
  List<Object?> get props => [conversations, activeConversation];
}

/// Emitted while connecting Realtime channel and fetching message history.
class ChatRoomLoading extends ChatState {
  const ChatRoomLoading({required this.conversationId});

  final String conversationId;

  @override
  List<Object?> get props => [conversationId];
}

/// Emitted when 1-on-1 chat room is active with real-time stream attached.
class ChatRoomActive extends ChatState {
  const ChatRoomActive({
    required this.conversation,
    required this.messages,
    this.isPeerTyping = false,
    this.peerTypingName,
    this.errorMessage,
  });

  final ChatConversation conversation;
  final List<ChatMessage> messages;
  final bool isPeerTyping;
  bool get isOtherUserTyping => isPeerTyping;
  final String? peerTypingName;
  final String? errorMessage;

  ChatRoomActive copyWith({
    ChatConversation? conversation,
    List<ChatMessage>? messages,
    bool? isPeerTyping,
    String? peerTypingName,
    String? errorMessage,
  }) {
    return ChatRoomActive(
      conversation: conversation ?? this.conversation,
      messages: messages ?? this.messages,
      isPeerTyping: isPeerTyping ?? this.isPeerTyping,
      peerTypingName: peerTypingName ?? this.peerTypingName,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    conversation,
    messages,
    isPeerTyping,
    peerTypingName,
    errorMessage,
  ];
}

/// Emitted on unrecoverable network, encryption, or subscription errors.
class ChatError extends ChatState {
  const ChatError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
