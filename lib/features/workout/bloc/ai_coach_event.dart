import 'package:equatable/equatable.dart';
import 'package:fitness_app/features/workout/models/workout_session.dart';

/// Base event class for AiCoachBloc.
abstract class AiCoachEvent extends Equatable {
  const AiCoachEvent();

  @override
  List<Object?> get props => [];
}

/// Dispatched to fetch or refresh AI recommendations from RAG service.
class AiCoachRecommendationsRequested extends AiCoachEvent {
  const AiCoachRecommendationsRequested({
    this.forceRefresh = false,
    this.sessions,
  });

  final bool forceRefresh;
  final List<WorkoutSession>? sessions;

  @override
  List<Object?> get props => [forceRefresh, sessions];
}

/// Dispatched when the user sends a message in the AI Coach chat.
class AiCoachMessageSent extends AiCoachEvent {
  const AiCoachMessageSent(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// Dispatched to reset the chat and insights state.
class AiCoachReset extends AiCoachEvent {
  const AiCoachReset();
}
