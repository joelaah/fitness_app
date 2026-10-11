import 'package:equatable/equatable.dart';
import 'package:fitness_app/features/workout/models/ai_recommendation.dart';

/// Status representing the lifecycle of AI recommendations retrieval.
enum AiCoachStatus { initial, loading, success, failure }

/// Represents an individual chat message in the AI Coach conversation.
class ChatMessage extends Equatable {
  const ChatMessage({
    required this.role,
    required this.text,
    this.sources = const [],
    this.sourceType = 'rag',
    this.isError = false,
  });

  final String role;
  final String text;
  final List<String> sources;
  final String sourceType;
  final bool isError;

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
  bool get isFallback => sourceType == 'local_fallback';

  /// Index operator for backwards compatibility with Map<String, dynamic> lookups.
  dynamic operator [](String key) {
    switch (key) {
      case 'role':
        return role;
      case 'text':
        return text;
      case 'sources':
        return sources;
      case 'source_type':
        return sourceType;
      case 'is_error':
        return isError;
      default:
        return null;
    }
  }

  @override
  List<Object?> get props => [role, text, sources, sourceType, isError];
}

/// Immutable state for AiCoachBloc.
class AiCoachState extends Equatable {
  const AiCoachState({
    this.status = AiCoachStatus.initial,
    this.recommendation,
    this.messages = const [initialChatMessage],
    this.isSending = false,
    this.errorMessage,
  });

  static const ChatMessage initialChatMessage = ChatMessage(
    role: 'assistant',
    text:
        'Hey! I am your Aura AI Coach, powered by exercise science research.\n\nAsk me anything about progressive overload, lifting technique, muscle recovery, warmups, or injury prevention!',
    sources: [],
    sourceType: 'rag',
  );

  final AiCoachStatus status;
  final AiRecommendation? recommendation;
  final List<ChatMessage> messages;
  final bool isSending;
  final String? errorMessage;

  bool get isLoading => status == AiCoachStatus.loading;
  bool get isSuccess => status == AiCoachStatus.success;
  bool get isFailure => status == AiCoachStatus.failure;

  AiCoachState copyWith({
    AiCoachStatus? status,
    AiRecommendation? Function()? recommendation,
    List<ChatMessage>? messages,
    bool? isSending,
    String? Function()? errorMessage,
  }) {
    return AiCoachState(
      status: status ?? this.status,
      recommendation:
          recommendation != null ? recommendation() : this.recommendation,
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        recommendation,
        messages,
        isSending,
        errorMessage,
      ];
}
