import 'package:fitness_app/core/theme/app_theme.dart';
import 'package:fitness_app/core/widgets/empty_state_widget.dart';
import 'package:fitness_app/features/workout/bloc/ai_coach_bloc.dart';
import 'package:fitness_app/features/workout/bloc/ai_coach_state.dart';
import 'package:fitness_app/features/workout/models/ai_recommendation.dart';
import 'package:fitness_app/features/workout/models/workout_session.dart';
import 'package:fitness_app/features/workout/providers/workout_provider.dart';
import 'package:fitness_app/features/workout/repositories/workout_history_repository.dart';
import 'package:fitness_app/features/workout/screens/ai_coach_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AI Coach & RAG Insights Adversarial UI Tests', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    Widget buildTestScreen({
      required AiCoachBloc bloc,
      TextScaler textScaler = TextScaler.noScaling,
    }) {
      final historyRepo = WorkoutHistoryRepository(prefs);
      final workoutProvider = WorkoutProvider(historyRepository: historyRepo);

      return MultiProvider(
        providers: [
          ChangeNotifierProvider<WorkoutProvider>.value(value: workoutProvider),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: child!,
            );
          },
          home: AiCoachScreen(bloc: bloc),
        ),
      );
    }

    testWidgets('Renders on narrow mobile viewport (320x568) without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final bloc = AiCoachBloc(
        initialState: const AiCoachState(
          messages: [
            ChatMessage(
              role: 'assistant',
              text: 'Welcome to your AI Coach. How can I help your training today?',
            ),
          ],
        ),
      );

      await tester.pumpWidget(buildTestScreen(bloc: bloc));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders with large accessibility text scale (1.5x) without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final bloc = AiCoachBloc(
        initialState: const AiCoachState(
          messages: [
            ChatMessage(
              role: 'assistant',
              text: 'Welcome to your AI Coach. How can I help your training today?',
            ),
          ],
        ),
      );

      await tester.pumpWidget(buildTestScreen(
        bloc: bloc,
        textScaler: const TextScaler.linear(1.5),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Assistant message with long source citations does not overflow',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final bloc = AiCoachBloc(
        initialState: const AiCoachState(
          messages: [
            ChatMessage(
              role: 'assistant',
              text: 'Welcome',
            ),
            ChatMessage(
              role: 'user',
              text: 'How much volume for hypertrophy?',
            ),
            ChatMessage(
              role: 'assistant',
              text: 'Optimal volume is 10-20 weekly sets per muscle group.',
              sources: [
                'Schoenfeld BJ, et al. Dose-response relationship between weekly resistance training volume and increases in muscle mass: A systematic review and meta-analysis. J Sports Sci. 2017',
              ],
            ),
          ],
        ),
      );

      await tester.pumpWidget(buildTestScreen(bloc: bloc));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('EmptyStateWidget with card=true under narrow viewport does not overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: EmptyStateWidget(
                icon: Icons.auto_awesome,
                title: 'No Workout History Yet',
                description:
                    'Complete your first workout so the AI Coach can analyze your volume, fatigue, and progression.',
                buttonText: 'Go to AI Chat',
                isCard: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders with extreme text scale (2.0x) on 320x568 without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final bloc = AiCoachBloc(
        initialState: const AiCoachState(
          messages: [
            ChatMessage(
              role: 'assistant',
              text: 'Welcome to your AI Coach. How can I help your training today?',
            ),
          ],
        ),
      );

      await tester.pumpWidget(buildTestScreen(
        bloc: bloc,
        textScaler: const TextScaler.linear(2.0),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Quota exceeded banner renders on narrow viewport without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final bloc = AiCoachBloc(
        initialState: const AiCoachState(
          isQuotaExceeded: true,
          remainingQueries: 0,
          messages: [
            ChatMessage(
              role: 'assistant',
              text: 'Welcome to your AI Coach.',
            ),
          ],
        ),
      );

      await tester.pumpWidget(buildTestScreen(bloc: bloc));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ai_quota_upgrade_prompt')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Long continuous string in user message wraps without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final bloc = AiCoachBloc(
        initialState: const AiCoachState(
          messages: [
            ChatMessage(
              role: 'user',
              text: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
            ),
          ],
        ),
      );

      await tester.pumpWidget(buildTestScreen(bloc: bloc));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Tapping prompt chip sends message without errors',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final bloc = AiCoachBloc(
        initialState: const AiCoachState(
          messages: [
            ChatMessage(
              role: 'assistant',
              text: 'Welcome',
            ),
          ],
        ),
      );

      await tester.pumpWidget(buildTestScreen(bloc: bloc));
      await tester.pumpAndSettle();

      final firstChip = find.text('How do I apply progressive overload?');
      expect(firstChip, findsOneWidget);
      await tester.tap(firstChip);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Insights tab with active recommendation renders on 320x568 without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final historyRepo = WorkoutHistoryRepository(prefs);
      await historyRepo.save(WorkoutSession(
        id: 'sess-1',
        routineId: 'r-1',
        dayId: 'd-1',
        startTime: DateTime.now().subtract(const Duration(days: 1)),
        endTime: DateTime.now(),
      ));

      final rec = AiRecommendation(
        summary: const RecommendationSummary(
          sessionsAnalyzed: 18,
          totalVolume: 125400.0,
          totalSets: 148,
          totalReps: 1850,
          volumeByMuscleGroup: {
            'Chest': 45000.0,
            'Back': 52000.0,
            'Legs': 28400.0,
          },
          mostTrainedMuscleGroups: ['Chest', 'Back'],
          recentlyUntrainedMuscleGroups: ['Legs', 'Shoulders'],
        ),
        recommendations: const [
          SingleRecommendation(
            title: 'Increase Lower Body Volume',
            category: 'Hypertrophy',
            description: 'Your leg volume is below recommended threshold.',
            priority: 'high',
          ),
        ],
        recovery: const [
          RecoveryItem(
            title: 'Sleep Optimization',
            description: 'Aim for 7-9 hours of restful sleep.',
          ),
        ],
        nextWorkout: const NextWorkout(
          title: 'Lower Body Strength & Hypertrophy',
          reason: 'Legs have rested for 4 days.',
          exercises: [
            NextExerciseItem(
              name: 'Barbell Squat',
              reason: 'Primary knee flexion movement',
            ),
          ],
        ),
        generatedAt: DateTime.now(),
        sessionsAnalyzed: 18,
        pipelineSource: 'local_fallback',
      );

      final bloc = AiCoachBloc(
        initialState: AiCoachState(
          recommendation: rec,
        ),
      );

      await tester.pumpWidget(buildTestScreen(bloc: bloc));
      await tester.pumpAndSettle();

      // Switch to Plan & Insights tab
      final insightsTab = find.text('Plan & Insights');
      expect(insightsTab, findsOneWidget);
      await tester.tap(insightsTab);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Insights tab with active recommendation renders with 1.5x text scale without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final historyRepo = WorkoutHistoryRepository(prefs);
      await historyRepo.save(WorkoutSession(
        id: 'sess-1',
        routineId: 'r-1',
        dayId: 'd-1',
        startTime: DateTime.now().subtract(const Duration(days: 1)),
        endTime: DateTime.now(),
      ));

      final rec = AiRecommendation(
        summary: const RecommendationSummary(
          sessionsAnalyzed: 18,
          totalVolume: 125400.0,
          totalSets: 148,
          totalReps: 1850,
          volumeByMuscleGroup: {
            'Chest': 45000.0,
            'Back': 52000.0,
            'Legs': 28400.0,
          },
          mostTrainedMuscleGroups: ['Chest', 'Back'],
          recentlyUntrainedMuscleGroups: ['Legs', 'Shoulders'],
        ),
        recommendations: const [
          SingleRecommendation(
            title: 'Increase Lower Body Volume',
            category: 'Hypertrophy',
            description: 'Your leg volume is below recommended threshold.',
            priority: 'high',
          ),
        ],
        recovery: const [
          RecoveryItem(
            title: 'Sleep Optimization',
            description: 'Aim for 7-9 hours of restful sleep.',
          ),
        ],
        nextWorkout: const NextWorkout(
          title: 'Lower Body Strength & Hypertrophy',
          reason: 'Legs have rested for 4 days.',
          exercises: [
            NextExerciseItem(
              name: 'Barbell Squat',
              reason: 'Primary knee flexion movement',
            ),
          ],
        ),
        generatedAt: DateTime.now(),
        sessionsAnalyzed: 18,
        pipelineSource: 'local_fallback',
      );

      final bloc = AiCoachBloc(
        initialState: AiCoachState(
          recommendation: rec,
        ),
      );

      await tester.pumpWidget(buildTestScreen(
        bloc: bloc,
        textScaler: const TextScaler.linear(1.5),
      ));
      await tester.pumpAndSettle();

      final insightsTab = find.text('Plan & Insights');
      expect(insightsTab, findsOneWidget);
      await tester.tap(insightsTab);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Quota exceeded banner renders on 320x568 with 1.5x text scale without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final bloc = AiCoachBloc(
        initialState: const AiCoachState(
          isQuotaExceeded: true,
          remainingQueries: 0,
          messages: [
            ChatMessage(
              role: 'assistant',
              text: 'Welcome to your AI Coach.',
            ),
          ],
        ),
      );

      await tester.pumpWidget(buildTestScreen(
        bloc: bloc,
        textScaler: const TextScaler.linear(1.5),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ai_quota_upgrade_prompt')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Desktop dual-column split view with recommendation renders with 1.5x text scale without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 750);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final historyRepo = WorkoutHistoryRepository(prefs);
      await historyRepo.save(WorkoutSession(
        id: 'sess-1',
        routineId: 'r-1',
        dayId: 'd-1',
        startTime: DateTime.now().subtract(const Duration(days: 1)),
        endTime: DateTime.now(),
      ));

      final rec = AiRecommendation(
        summary: const RecommendationSummary(
          sessionsAnalyzed: 18,
          totalVolume: 125400.0,
          totalSets: 148,
          totalReps: 1850,
          volumeByMuscleGroup: {
            'Chest': 45000.0,
            'Back': 52000.0,
            'Legs': 28400.0,
          },
          mostTrainedMuscleGroups: ['Chest', 'Back'],
          recentlyUntrainedMuscleGroups: ['Legs', 'Shoulders'],
        ),
        recommendations: const [
          SingleRecommendation(
            title: 'Increase Lower Body Volume',
            category: 'Hypertrophy',
            description: 'Your leg volume is below recommended threshold.',
            priority: 'high',
          ),
        ],
        recovery: const [
          RecoveryItem(
            title: 'Sleep Optimization',
            description: 'Aim for 7-9 hours of restful sleep.',
          ),
        ],
        nextWorkout: const NextWorkout(
          title: 'Lower Body Strength & Hypertrophy',
          reason: 'Legs have rested for 4 days.',
          exercises: [
            NextExerciseItem(
              name: 'Barbell Squat',
              reason: 'Primary knee flexion movement',
            ),
          ],
        ),
        generatedAt: DateTime.now(),
        sessionsAnalyzed: 18,
        pipelineSource: 'local_fallback',
      );

      final bloc = AiCoachBloc(
        initialState: AiCoachState(
          recommendation: rec,
          messages: const [
            ChatMessage(
              role: 'assistant',
              text: 'Welcome to your AI Coach.',
            ),
          ],
        ),
      );

      await tester.pumpWidget(buildTestScreen(
        bloc: bloc,
        textScaler: const TextScaler.linear(1.5),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Insights tab empty state (no workout history) on 320x568 does not overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final bloc = AiCoachBloc(
        initialState: const AiCoachState(),
      );

      await tester.pumpWidget(buildTestScreen(bloc: bloc));
      await tester.pumpAndSettle();

      final insightsTab = find.text('Plan & Insights');
      expect(insightsTab, findsOneWidget);
      await tester.tap(insightsTab);
      await tester.pumpAndSettle();

      expect(find.text('No Workout History Yet'), findsOneWidget);
      expect(find.text('Go to AI Chat'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Insights tab empty state on 320x568 with 1.5x text scale does not overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final bloc = AiCoachBloc(
        initialState: const AiCoachState(),
      );

      await tester.pumpWidget(buildTestScreen(
        bloc: bloc,
        textScaler: const TextScaler.linear(1.5),
      ));
      await tester.pumpAndSettle();

      final insightsTab = find.text('Plan & Insights');
      expect(insightsTab, findsOneWidget);
      await tester.tap(insightsTab);
      await tester.pumpAndSettle();

      expect(find.text('No Workout History Yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Empty state Go to AI Chat button navigates back to tab 0',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final bloc = AiCoachBloc(
        initialState: const AiCoachState(
          messages: [
            ChatMessage(
              role: 'assistant',
              text: 'Welcome to your AI Coach.',
            ),
          ],
        ),
      );

      await tester.pumpWidget(buildTestScreen(bloc: bloc));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Plan & Insights'));
      await tester.pumpAndSettle();

      final goToChatBtn = find.text('Go to AI Chat');
      expect(goToChatBtn, findsOneWidget);
      await tester.tap(goToChatBtn);
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Prompt chips with 2.5x accessibility text scale do not overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final bloc = AiCoachBloc(
        initialState: const AiCoachState(
          messages: [
            ChatMessage(
              role: 'assistant',
              text: 'Welcome to your AI Coach.',
            ),
          ],
        ),
      );

      await tester.pumpWidget(buildTestScreen(
        bloc: bloc,
        textScaler: const TextScaler.linear(2.5),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Recommendation card with long title and category badge has clean layout and no overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final historyRepo = WorkoutHistoryRepository(prefs);
      await historyRepo.save(WorkoutSession(
        id: 'sess-rec-long',
        routineId: 'r-1',
        dayId: 'd-1',
        startTime: DateTime.now().subtract(const Duration(days: 1)),
        endTime: DateTime.now(),
      ));

      final rec = AiRecommendation(
        summary: const RecommendationSummary(
          sessionsAnalyzed: 10,
          totalVolume: 85000.0,
          totalSets: 90,
          totalReps: 1000,
          volumeByMuscleGroup: {'Back': 40000.0},
          mostTrainedMuscleGroups: ['Back'],
          recentlyUntrainedMuscleGroups: ['Chest'],
        ),
        recommendations: const [
          SingleRecommendation(
            title: 'Substantial Volume Increase Across All Posterior Kinetic Chain Movements',
            category: 'Hypertrophy & Performance',
            description: 'Focus on progressive overload with controlled tempo.',
            priority: 'high',
          ),
        ],
        recovery: const [
          RecoveryItem(
            title: 'Extended Sleep Duration',
            description: 'Get at least 8 hours of sleep for CNS recovery.',
          ),
        ],
        nextWorkout: const NextWorkout(
          title: 'Upper Body Pull & Posterior Chain Hypertrophy Specialization',
          reason: 'Back muscles have recovered for 72 hours.',
          exercises: [
            NextExerciseItem(
              name: 'Barbell Deadlift',
              reason: 'Heavy neural activation',
            ),
          ],
        ),
        generatedAt: DateTime.now(),
        sessionsAnalyzed: 10,
        pipelineSource: 'local_fallback',
      );

      final bloc = AiCoachBloc(
        initialState: AiCoachState(recommendation: rec),
      );

      await tester.pumpWidget(buildTestScreen(
        bloc: bloc,
        textScaler: const TextScaler.linear(1.5),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Plan & Insights'));
      await tester.pumpAndSettle();

      expect(find.text('HYPERTROPHY & PERFORMANCE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
