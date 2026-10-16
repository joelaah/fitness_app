import 'dart:math';

import 'package:fitness_app/core/theme/app_theme.dart';
import 'package:fitness_app/core/widgets/category_chip.dart';
import 'package:fitness_app/features/chat/bloc/chat_bloc.dart';
import 'package:fitness_app/features/chat/screens/conversations_screen.dart';
import 'package:fitness_app/features/exercises/screens/exercise_library_screen.dart';
import 'package:fitness_app/features/home/screens/home_screen.dart';
import 'package:fitness_app/features/payments/screens/payment_history_screen.dart';
import 'package:fitness_app/features/routines/providers/routine_provider.dart';
import 'package:fitness_app/features/routines/repositories/shared_prefs_routine_repository.dart';
import 'package:fitness_app/features/routines/screens/routines_screen.dart';
import 'package:fitness_app/features/trainers/screens/trainer_discovery_screen.dart';
import 'package:fitness_app/features/workout/bloc/ai_coach_bloc.dart';
import 'package:fitness_app/features/workout/providers/workout_provider.dart';
import 'package:fitness_app/features/workout/repositories/workout_history_repository.dart';
import 'package:fitness_app/features/workout/screens/ai_coach_screen.dart';
import 'package:fitness_app/features/workout/screens/history_screen.dart';
import 'package:fitness_app/features/workout/widgets/ai_coach_card.dart';
import 'package:fitness_app/main_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

extension on WidgetTester {
  Future<void> pumpAndAdvance([
    Duration duration = const Duration(milliseconds: 300),
  ]) async {
    await pump();
    await pump(duration);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late SharedPrefsRoutineRepository routineRepository;
  late WorkoutHistoryRepository historyRepository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    routineRepository = SharedPrefsRoutineRepository(prefs);
    historyRepository = WorkoutHistoryRepository(prefs);
  });

  Widget buildTestableMainScreen({
    int initialIndex = 0,
    bool provideChatBloc = false,
  }) {
    Widget child = MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => RoutineProvider(repository: routineRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => WorkoutProvider(
            historyRepository: historyRepository,
          ),
        ),
      ],
      child: BlocProvider<AiCoachBloc>(
        create: (_) => AiCoachBloc(),
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: MainScreen(
            key: ValueKey('main_screen_$initialIndex'),
            initialIndex: initialIndex,
          ),
        ),
      ),
    );

    if (provideChatBloc) {
      child = BlocProvider<ChatBloc>(
        create: (_) => ChatBloc(),
        child: child,
      );
    }

    return child;
  }

  group('Group 1: Out-of-Bounds & Extreme initialIndex Clamping', () {
    testWidgets(
      'Negative initialIndex values clamp safely to index 0',
      (tester) async {
        final extremeNegatives = [-1, -5, -100, -2147483648];

        for (final negIndex in extremeNegatives) {
          await tester.pumpWidget(
            buildTestableMainScreen(initialIndex: negIndex),
          );
          await tester.pumpAndAdvance();

          expect(
            tester.takeException(),
            isNull,
            reason: 'Clamping $negIndex should not throw an exception',
          );

          final navBar = tester.widget<BottomNavigationBar>(
            find.byType(BottomNavigationBar),
          );
          final indexedStack = tester.widget<IndexedStack>(
            find.byType(IndexedStack),
          );

          expect(navBar.currentIndex, 0);
          expect(indexedStack.index, 0);
          expect(find.byType(HomeScreen), findsOneWidget);
          expect(find.text('PulseFit AI'), findsOneWidget);
        }
      },
    );

    testWidgets(
      'Overshooting initialIndex values clamp safely to index 5',
      (tester) async {
        final extremePositives = [6, 10, 100, 2147483647];

        for (final posIndex in extremePositives) {
          await tester.pumpWidget(
            buildTestableMainScreen(initialIndex: posIndex),
          );
          await tester.pumpAndAdvance();

          expect(
            tester.takeException(),
            isNull,
            reason: 'Clamping $posIndex should not throw an exception',
          );

          final navBar = tester.widget<BottomNavigationBar>(
            find.byType(BottomNavigationBar),
          );
          final indexedStack = tester.widget<IndexedStack>(
            find.byType(IndexedStack),
          );

          expect(navBar.currentIndex, 5);
          expect(indexedStack.index, 5);
          expect(find.byType(HistoryScreen), findsOneWidget);
          // Non-Home tabs do not render outer PulseFit AI AppBar
          expect(find.text('PulseFit AI'), findsNothing);
        }
      },
    );

    testWidgets(
      'Exact boundary initialIndex values (0 and 5) mount correct target tabs',
      (tester) async {
        // Tab 0 (Home)
        await tester.pumpWidget(buildTestableMainScreen());
        await tester.pumpAndAdvance();
        expect(
          tester
              .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
              .currentIndex,
          0,
        );
        expect(find.byType(HomeScreen), findsOneWidget);

        // Tab 5 (History)
        await tester.pumpWidget(buildTestableMainScreen(initialIndex: 5));
        await tester.pumpAndAdvance();
        expect(
          tester
              .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
              .currentIndex,
          5,
        );
        expect(find.byType(HistoryScreen), findsOneWidget);
      },
    );
  });

  group('Group 2: Rapid Randomized Tab Switching & State Retention', () {
    testWidgets(
      'Executes 60 rapid pseudo-random tab transitions without exceptions',
      (tester) async {
        await tester.pumpWidget(buildTestableMainScreen());
        await tester.pumpAndAdvance();

        final rng = Random(1337);
        final tabLabels = [
          'Home',
          'Routines',
          'AI Coach',
          'Trainers',
          'Exercises',
          'History',
        ];

        var currentExpectedIndex = 0;

        for (var i = 0; i < 60; i++) {
          final targetIndex = rng.nextInt(6);
          final targetLabel = tabLabels[targetIndex];

          final targetFinder = find.descendant(
            of: find.byType(BottomNavigationBar),
            matching: find.text(targetLabel),
          );
          await tester.tap(targetFinder);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));

          expect(
            tester.takeException(),
            isNull,
            reason: 'Transition $i to tab $targetIndex ($targetLabel) crashed',
          );

          currentExpectedIndex = targetIndex;
          final navBar = tester.widget<BottomNavigationBar>(
            find.byType(BottomNavigationBar),
          );
          final indexedStack = tester.widget<IndexedStack>(
            find.byType(IndexedStack),
          );

          expect(navBar.currentIndex, currentExpectedIndex);
          expect(indexedStack.index, currentExpectedIndex);
        }

        // Final settle verification
        await tester.pumpAndAdvance();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'IndexedStack tab state retention: search query survives tab switches',
      (tester) async {
        await tester.pumpWidget(buildTestableMainScreen());
        await tester.pumpAndAdvance();

        // 1. Navigate to Tab 3: Trainers
        await tester.tap(find.text('Trainers'));
        await tester.pumpAndAdvance();
        expect(find.byType(TrainerDiscoveryScreen), findsOneWidget);

        // 2. Input search text in TrainerDiscoveryScreen
        final searchField = find.byType(TextField);
        expect(searchField, findsOneWidget);
        await tester.enterText(searchField, 'Mobility');
        await tester.pumpAndAdvance();

        // 3. Tap 'Mobility' CategoryChip
        final mobilityChip = find.widgetWithText(CategoryChip, 'Mobility');
        expect(mobilityChip, findsOneWidget);
        await tester.tap(mobilityChip);
        await tester.pumpAndAdvance();

        // Verify state is applied on Tab 3
        expect(find.text('Mobility'), findsWidgets);

        // 4. Switch across multiple other tabs: 0 -> 1 -> 2 -> 4 -> 5
        await tester.tap(find.text('Home'));
        await tester.pumpAndAdvance();
        expect(find.byType(HomeScreen), findsOneWidget);

        await tester.tap(find.text('Routines'));
        await tester.pumpAndAdvance();
        expect(find.byType(RoutinesScreen), findsOneWidget);

        await tester.tap(find.text('AI Coach'));
        await tester.pumpAndAdvance();
        expect(find.byType(AiCoachScreen), findsOneWidget);

        await tester.tap(find.text('Exercises'));
        await tester.pumpAndAdvance();
        expect(find.byType(ExerciseLibraryScreen), findsOneWidget);

        await tester.tap(find.text('History'));
        await tester.pumpAndAdvance();
        expect(find.byType(HistoryScreen), findsOneWidget);

        // 5. Return to Tab 3: Trainers
        await tester.tap(find.text('Trainers'));
        await tester.pumpAndAdvance();
        expect(find.byType(TrainerDiscoveryScreen), findsOneWidget);

        // Verify that the search TextField retained 'Mobility'
        final retainedTextField = tester.widget<TextField>(searchField);
        expect(retainedTextField.controller?.text, 'Mobility');
      },
    );
  });

  group('Group 3: Deep Route Push / Pop Lifecycle & Provider Resilience', () {
    testWidgets(
      'Repeated push/pop of ConversationsScreen retains _selectedIndex',
      (tester) async {
        await tester.pumpWidget(buildTestableMainScreen());
        await tester.pumpAndAdvance();

        final chatAction = find.byKey(const Key('chat_header_action'));
        expect(chatAction, findsOneWidget);

        for (var i = 0; i < 5; i++) {
          await tester.tap(chatAction);
          await tester.pumpAndAdvance(const Duration(milliseconds: 400));

          expect(find.byType(ConversationsScreen), findsOneWidget);
          expect(tester.takeException(), isNull);

          final backBtn = find.byIcon(Icons.arrow_back_rounded);
          expect(backBtn, findsOneWidget);
          await tester.tap(backBtn);
          await tester.pumpAndAdvance(const Duration(milliseconds: 400));

          expect(find.byType(ConversationsScreen), findsNothing);
          expect(find.byType(MainScreen), findsOneWidget);

          final navBar = tester.widget<BottomNavigationBar>(
            find.byType(BottomNavigationBar),
          );
          expect(navBar.currentIndex, 0);
        }
      },
    );

    testWidgets(
      'Repeated push/pop of PaymentHistoryScreen retains _selectedIndex',
      (tester) async {
        await tester.pumpWidget(buildTestableMainScreen());
        await tester.pumpAndAdvance();

        final paymentAction = find.byKey(const Key('payments_header_action'));
        expect(paymentAction, findsOneWidget);

        for (var i = 0; i < 5; i++) {
          await tester.tap(paymentAction);
          await tester.pumpAndAdvance(const Duration(milliseconds: 400));

          expect(find.byType(PaymentHistoryScreen), findsOneWidget);
          expect(tester.takeException(), isNull);

          final backBtn = find.byType(BackButton);
          expect(backBtn, findsOneWidget);
          await tester.tap(backBtn);
          await tester.pumpAndAdvance(const Duration(milliseconds: 400));

          expect(find.byType(PaymentHistoryScreen), findsNothing);
          expect(find.byType(MainScreen), findsOneWidget);

          final navBar = tester.widget<BottomNavigationBar>(
            find.byType(BottomNavigationBar),
          );
          expect(navBar.currentIndex, 0);
        }
      },
    );

    testWidgets(
      'ChatBloc resolution branch: navigation with ancestor ChatBloc',
      (tester) async {
        await tester.pumpWidget(
          buildTestableMainScreen(provideChatBloc: true),
        );
        await tester.pumpAndAdvance();

        final chatAction = find.byKey(const Key('chat_header_action'));
        await tester.tap(chatAction);
        await tester.pumpAndAdvance(const Duration(milliseconds: 400));

        expect(find.byType(ConversationsScreen), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Pop back
        final backBtn = find.byIcon(Icons.arrow_back_rounded);
        await tester.tap(backBtn);
        await tester.pumpAndAdvance(const Duration(milliseconds: 400));

        expect(find.byType(ConversationsScreen), findsNothing);
        expect(find.byType(MainScreen), findsOneWidget);
      },
    );

    testWidgets(
      'ChatBloc resolution fallback: navigation without ancestor ChatBloc',
      (tester) async {
        // ChatBloc absent from ancestor tree
        await tester.pumpWidget(buildTestableMainScreen());
        await tester.pumpAndAdvance();

        final chatAction = find.byKey(const Key('chat_header_action'));
        await tester.tap(chatAction);
        await tester.pumpAndAdvance(const Duration(milliseconds: 400));

        // Must succeed without throwing ProviderNotFoundException
        expect(find.byType(ConversationsScreen), findsOneWidget);
        expect(tester.takeException(), isNull);

        final backBtn = find.byIcon(Icons.arrow_back_rounded);
        await tester.tap(backBtn);
        await tester.pumpAndAdvance(const Duration(milliseconds: 400));

        expect(find.byType(ConversationsScreen), findsNothing);
        expect(find.byType(MainScreen), findsOneWidget);
      },
    );
  });

  group('Group 4: Concurrent & Rapid Callback Invocations', () {
    testWidgets(
      'Simulate rapid consecutive onBrowseRoutines callback invocations',
      (tester) async {
        await tester.pumpWidget(buildTestableMainScreen());
        await tester.pumpAndAdvance();

        final homeScreen = tester.widget<HomeScreen>(find.byType(HomeScreen));

        // Fire onBrowseRoutines 10 times in immediate succession
        for (var i = 0; i < 10; i++) {
          homeScreen.onBrowseRoutines();
        }

        await tester.pumpAndAdvance();

        expect(tester.takeException(), isNull);
        final navBar = tester.widget<BottomNavigationBar>(
          find.byType(BottomNavigationBar),
        );
        expect(navBar.currentIndex, 1);
        expect(find.byType(RoutinesScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Simulate rapid alternating onBrowseRoutines & onOpenAiCoach calls',
      (tester) async {
        await tester.pumpWidget(buildTestableMainScreen());
        await tester.pumpAndAdvance();

        final homeScreen = tester.widget<HomeScreen>(find.byType(HomeScreen));

        // Rapid interleaved callback toggling
        for (var i = 0; i < 8; i++) {
          homeScreen.onBrowseRoutines();
          homeScreen.onOpenAiCoach?.call();
        }

        await tester.pumpAndAdvance();

        expect(tester.takeException(), isNull);
        final navBar = tester.widget<BottomNavigationBar>(
          find.byType(BottomNavigationBar),
        );
        // Last call was onOpenAiCoach -> index 2
        expect(navBar.currentIndex, 2);
        expect(find.byType(AiCoachScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Tapping AiCoachCard triggers onOpenAiCoach and navigates to index 2',
      (tester) async {
        await tester.pumpWidget(buildTestableMainScreen());
        await tester.pumpAndAdvance();

        final aiCoachCard = find.byType(AiCoachCard);
        expect(aiCoachCard, findsOneWidget);

        await tester.ensureVisible(aiCoachCard);
        await tester.pumpAndAdvance();

        await tester.tap(aiCoachCard);
        await tester.pumpAndAdvance();

        expect(tester.takeException(), isNull);
        final navBar = tester.widget<BottomNavigationBar>(
          find.byType(BottomNavigationBar),
        );
        expect(navBar.currentIndex, 2);
        expect(find.byType(AiCoachScreen), findsOneWidget);
      },
    );
  });

  group('Group 5: Architectural Rule & Display Surface Stress', () {
    testWidgets(
      'Strict architectural compliance: 0 PopScope in widget tree',
      (tester) async {
        await tester.pumpWidget(buildTestableMainScreen());
        await tester.pumpAndAdvance();

        expect(
          find.byType(PopScope),
          findsNothing,
          reason: 'SKILL.md Rule 1 explicitly prohibits PopScope',
        );

        expect(
          find.byWidgetPredicate(
            (w) => w.runtimeType.toString().contains('PopScope'),
          ),
          findsNothing,
          reason: 'No PopScope or WillPopScope variants permitted',
        );
      },
    );

    testWidgets(
      'Shell navigation bar resilience: 6 tabs render cleanly on default view',
      (tester) async {
        await tester.pumpWidget(buildTestableMainScreen());
        await tester.pumpAndAdvance();

        expect(
          tester.takeException(),
          isNull,
          reason: 'MainScreen must render cleanly on default viewport',
        );

        final navBar = tester.widget<BottomNavigationBar>(
          find.byType(BottomNavigationBar),
        );
        expect(navBar.items.length, 6);
        expect(navBar.currentIndex, 0);
      },
    );
  });
}
