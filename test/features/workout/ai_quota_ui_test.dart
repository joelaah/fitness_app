import 'package:fitness_app/features/workout/bloc/ai_coach_bloc.dart';
import 'package:fitness_app/features/workout/bloc/ai_coach_event.dart';
import 'package:fitness_app/features/workout/bloc/ai_coach_state.dart';
import 'package:fitness_app/features/workout/providers/workout_provider.dart';
import 'package:fitness_app/features/workout/repositories/workout_history_repository.dart';
import 'package:fitness_app/features/workout/screens/ai_coach_screen.dart';
import 'package:fitness_app/features/workout/services/ai_quota_service.dart';
import 'package:fitness_app/features/workout/widgets/ai_quota_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void _setStandardViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
}

Widget _buildTestableAiCoachScreen({
  required AiCoachBloc bloc,
  required SharedPreferences prefs,
}) {
  final historyRepo = WorkoutHistoryRepository(prefs);
  final workoutProvider = WorkoutProvider(historyRepository: historyRepo);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<WorkoutProvider>.value(value: workoutProvider),
    ],
    child: MaterialApp(
      home: AiCoachScreen(
        bloc: bloc,
      ),
    ),
  );
}

void main() {
  group('AI Quota UI & Upgrade Prompt Display Tests (R1)', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    testWidgets('AiQuotaDialog renders clean upgrade prompt with benefits and action buttons',
        (tester) async {
      _setStandardViewport(tester);
      bool upgradeClicked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => AiQuotaDialog.show(
                  context,
                  onUpgrade: () {
                    upgradeClicked = true;
                  },
                ),
                child: const Text('Show Prompt'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Prompt'));
      await tester.pumpAndSettle();

      // Verify Dialog header and badge
      expect(find.byKey(const Key('ai_quota_upgrade_dialog')), findsOneWidget);
      expect(find.text('DAILY AI LIMIT REACHED'), findsOneWidget);
      expect(find.text('Upgrade for Unlimited AI Coach'), findsOneWidget);
      expect(find.text('5 of 5 free queries used today'), findsOneWidget);

      // Verify benefits list
      expect(find.text('Unlimited conversational AI coaching'), findsOneWidget);
      expect(find.text('Adaptive workout recommendations & progression'), findsOneWidget);

      // Verify upgrade button and trigger
      final upgradeBtn = find.byKey(const Key('upgrade_account_button'));
      expect(upgradeBtn, findsOneWidget);
      await tester.tap(upgradeBtn);
      await tester.pumpAndSettle();

      expect(upgradeClicked, isTrue);
      expect(find.byKey(const Key('ai_quota_upgrade_dialog')), findsNothing);
    });

    testWidgets('reaching quota displays in-app upgrade banner and prompt in AiCoachScreen',
        (tester) async {
      _setStandardViewport(tester);

      final quotaService = AiQuotaService();
      // Exhaust 5 queries
      for (var i = 0; i < 5; i++) {
        await quotaService.consumeQuery();
      }

      final bloc = AiCoachBloc(
        quotaService: quotaService,
        initialState: const AiCoachState(
          isQuotaExceeded: true,
          remainingQueries: 0,
        ),
      );

      await tester.pumpWidget(_buildTestableAiCoachScreen(bloc: bloc, prefs: prefs));
      await tester.pumpAndSettle();

      // Verify the upgrade banner appears in the chat tab
      expect(find.byKey(const Key('ai_quota_upgrade_prompt')), findsOneWidget);
      expect(
        find.textContaining('Daily AI limit reached (5/5)'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('upgrade_prompt_button')), findsOneWidget);

      // Tapping the inline Upgrade button launches the full upgrade dialog
      await tester.tap(find.byKey(const Key('upgrade_prompt_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ai_quota_upgrade_dialog')), findsOneWidget);
      expect(find.text('Upgrade for Unlimited AI Coach'), findsOneWidget);
    });

    testWidgets('AiCoachBloc triggers quota exceeded state and upgrade notice when 6th query is sent',
        (tester) async {
      _setStandardViewport(tester);

      final quotaService = AiQuotaService();
      // Consume 5 queries
      for (var i = 0; i < 5; i++) {
        await quotaService.consumeQuery();
      }

      final bloc = AiCoachBloc(quotaService: quotaService);

      await tester.pumpWidget(_buildTestableAiCoachScreen(bloc: bloc, prefs: prefs));
      await tester.pumpAndSettle();

      // Enter a chat message and attempt to send
      final inputField = find.byType(TextField);
      await tester.enterText(inputField, 'How do I optimize bench press?');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();

      // Verify that sending was blocked, quota dialog was shown, and limit message appeared
      expect(find.byKey(const Key('ai_quota_upgrade_dialog')), findsOneWidget);
      expect(bloc.state.isQuotaExceeded, isTrue);
      expect(bloc.state.remainingQueries, equals(0));
      expect(
        find.textContaining('Daily AI Coach query limit reached (5/5)'),
        findsOneWidget,
      );
    });

    testWidgets('dismisses upgrade banner and refreshes state when user upgrades in AiCoachScreen',
        (tester) async {
      _setStandardViewport(tester);

      final quotaService = AiQuotaService();
      // Consume 5 queries
      for (var i = 0; i < 5; i++) {
        await quotaService.consumeQuery();
      }

      final bloc = AiCoachBloc(
        quotaService: quotaService,
        initialState: const AiCoachState(
          isQuotaExceeded: true,
          remainingQueries: 0,
        ),
      );

      await tester.pumpWidget(_buildTestableAiCoachScreen(bloc: bloc, prefs: prefs));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ai_quota_upgrade_prompt')), findsOneWidget);

      // Simulate mid-session upgrade
      await quotaService.resetQuota();
      bloc.add(const AiCoachQuotaChecked());
      await tester.pumpAndSettle();

      // Banner must disappear
      expect(find.byKey(const Key('ai_quota_upgrade_prompt')), findsNothing);
      expect(bloc.state.isQuotaExceeded, isFalse);
    });
  });
}
