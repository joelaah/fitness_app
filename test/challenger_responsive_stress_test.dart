import 'package:fitness_app/core/responsive/app_breakpoints.dart';
import 'package:fitness_app/core/theme/app_theme.dart';
import 'package:fitness_app/core/widgets/adaptive_navigation_rail.dart';
import 'package:fitness_app/core/widgets/animated_neon_volume_ring.dart';
import 'package:fitness_app/features/chat/bloc/chat_bloc.dart';
import 'package:fitness_app/features/routines/providers/routine_provider.dart';
import 'package:fitness_app/features/routines/repositories/shared_prefs_routine_repository.dart';
import 'package:fitness_app/features/routines/screens/routines_screen.dart';
import 'package:fitness_app/features/trainers/screens/trainer_discovery_screen.dart';
import 'package:fitness_app/features/trainers/widgets/trainer_card.dart';
import 'package:fitness_app/features/workout/bloc/ai_coach_bloc.dart';
import 'package:fitness_app/features/workout/providers/workout_provider.dart';
import 'package:fitness_app/features/workout/repositories/workout_history_repository.dart';
import 'package:fitness_app/features/workout/screens/ai_coach_screen.dart';
import 'package:fitness_app/main_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

extension on WidgetTester {
  Future<void> pumpAndAdvance([
    Duration duration = const Duration(milliseconds: 400),
  ]) async {
    await pump();
    await pump(duration);
    await pump();
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

  Widget buildTestableMainScreen({int initialIndex = 0}) {
    return MultiProvider(
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
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AiCoachBloc>(create: (_) => AiCoachBloc()),
          BlocProvider<ChatBloc>(create: (_) => ChatBloc()),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: MainScreen(initialIndex: initialIndex),
        ),
      ),
    );
  }

  group('Adversarial Stress Test: Breakpoint Boundaries', () {
    testWidgets('Threshold boundary: width = 899.0 must be mobile bottom nav, no rail', (tester) async {
      tester.view.physicalSize = const Size(899.0, 800.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableMainScreen());
      await tester.pumpAndAdvance();

      expect(find.byType(BottomNavigationBar), findsOneWidget,
          reason: 'At width 899.0, BottomNavigationBar must be present');
      expect(find.byType(AdaptiveNavigationRail), findsNothing,
          reason: 'At width 899.0, AdaptiveNavigationRail must not be present');
    });

    testWidgets('Threshold boundary: width = 900.0 must be desktop rail, no bottom nav', (tester) async {
      tester.view.physicalSize = const Size(900.0, 800.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableMainScreen());
      await tester.pumpAndAdvance();

      expect(find.byType(AdaptiveNavigationRail), findsOneWidget,
          reason: 'At width 900.0, AdaptiveNavigationRail must be present');
      expect(find.byType(BottomNavigationBar), findsNothing,
          reason: 'At width 900.0, BottomNavigationBar must not be present');
    });

    testWidgets('Threshold boundary: width = 1199.0 must render 2 columns in Routines and Trainers', (tester) async {
      tester.view.physicalSize = const Size(1199.0, 900.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Routines screen
      await tester.pumpWidget(buildTestableMainScreen(initialIndex: 1));
      await tester.pumpAndAdvance();

      final gridView = tester.widget<GridView>(find.byType(GridView));
      final routinesDelegate = gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(routinesDelegate.crossAxisCount, 2,
          reason: 'At width 1199.0, RoutinesScreen must render 2 columns');

      // Switch to Trainers tab (index 3)
      await tester.tap(find.text('Trainers'));
      await tester.pumpAndAdvance();

      final sliverGrid = tester.widget<SliverGrid>(find.byType(SliverGrid));
      final trainersDelegate = sliverGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(trainersDelegate.crossAxisCount, 2,
          reason: 'At width 1199.0, TrainerDiscoveryScreen must render 2 columns');
    });

    testWidgets('Threshold boundary: width = 1200.0 must render 3 columns in Routines and Trainers', (tester) async {
      tester.view.physicalSize = const Size(1200.0, 900.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Routines screen
      await tester.pumpWidget(buildTestableMainScreen(initialIndex: 1));
      await tester.pumpAndAdvance();

      final gridView = tester.widget<GridView>(find.byType(GridView));
      final routinesDelegate = gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(routinesDelegate.crossAxisCount, 3,
          reason: 'At width 1200.0, RoutinesScreen must render 3 columns');

      // Switch to Trainers tab (index 3)
      await tester.tap(find.text('Trainers'));
      await tester.pumpAndAdvance();

      final sliverGrid = tester.widget<SliverGrid>(find.byType(SliverGrid));
      final trainersDelegate = sliverGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(trainersDelegate.crossAxisCount, 3,
          reason: 'At width 1200.0, TrainerDiscoveryScreen must render 3 columns');
    });

    testWidgets('Threshold boundary: width = 320.0 (narrow mobile) zero RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(320.0, 640.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.dumpErrorToConsole(details);
      };

      await tester.pumpWidget(buildTestableMainScreen(initialIndex: 0));
      await tester.pumpAndAdvance();
      final exception = tester.takeException();
      expect(exception, isNull);

      // Tab 1: Routines
      await tester.tap(find.text('Routines'));
      await tester.pumpAndAdvance();
      expect(tester.takeException(), isNull);

      // Tab 2: AI Coach
      await tester.tap(find.text('AI Coach'));
      await tester.pumpAndAdvance();
      expect(tester.takeException(), isNull);

      // Tab 3: Trainers
      await tester.tap(find.text('Trainers'));
      await tester.pumpAndAdvance();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Threshold boundary: width = 1920.0 (wide desktop) properly constrained and zero overflow', (tester) async {
      tester.view.physicalSize = const Size(1920.0, 1080.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableMainScreen(initialIndex: 0));
      await tester.pumpAndAdvance();
      expect(find.byType(AdaptiveNavigationRail), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Tab 1: Routines
      await tester.tap(find.text('Routines'));
      await tester.pumpAndAdvance();
      expect(tester.takeException(), isNull);

      // Tab 2: AI Coach
      await tester.tap(find.text('AI Coach'));
      await tester.pumpAndAdvance();
      expect(tester.takeException(), isNull);

      // Tab 3: Trainers
      await tester.tap(find.text('Trainers'));
      await tester.pumpAndAdvance();
      expect(tester.takeException(), isNull);
    });
  });

  group('Adversarial Stress Test: Dynamic Resize & State Preservation Across 900px', () {
    testWidgets('User input in AI Coach is preserved when resizing across 900px breakpoint', (tester) async {
      // Start in mobile mode (800px width)
      tester.view.physicalSize = const Size(800.0, 800.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableMainScreen(initialIndex: 2));
      await tester.pumpAndAdvance();

      // Find the TextField in AI Coach
      final aiTextField = find.byType(TextField);
      expect(aiTextField, findsOneWidget);

      const testInput = 'I have lower back soreness after deadlifts';
      await tester.enterText(aiTextField, testInput);
      await tester.pump();

      // Verify text entered
      final textFieldWidgetBefore = tester.widget<TextField>(aiTextField);
      expect(textFieldWidgetBefore.controller?.text, testInput);

      // RESIZE VIEWPORT ACROSS 900px BREAKPOINT TO DESKTOP (1100px)
      tester.view.physicalSize = const Size(1100.0, 800.0);
      await tester.pumpAndAdvance();

      // Check if text is still intact
      final aiTextFieldAfter = find.byType(TextField);
      expect(aiTextFieldAfter, findsOneWidget);
      final textFieldWidgetAfter = tester.widget<TextField>(aiTextFieldAfter);
      expect(
        textFieldWidgetAfter.controller?.text,
        testInput,
        reason: 'AI Coach text input should NOT be wiped when resizing across 900px breakpoint',
      );
    });

    testWidgets('User search query in Trainers is preserved when resizing across 900px breakpoint', (tester) async {
      // Start in mobile mode (800px width)
      tester.view.physicalSize = const Size(800.0, 800.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableMainScreen(initialIndex: 3));
      await tester.pumpAndAdvance();

      // Find search field
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      const searchQuery = 'Hypertrophy Coach';
      await tester.enterText(searchField, searchQuery);
      await tester.pump();

      final searchFieldBefore = tester.widget<TextField>(searchField);
      expect(searchFieldBefore.controller?.text, searchQuery);

      // RESIZE VIEWPORT ACROSS 900px BREAKPOINT TO DESKTOP (1280px)
      tester.view.physicalSize = const Size(1280.0, 800.0);
      await tester.pumpAndAdvance();

      // Check if search query is preserved
      final searchFieldAfter = find.byType(TextField);
      expect(searchFieldAfter, findsOneWidget);
      final searchFieldWidgetAfter = tester.widget<TextField>(searchFieldAfter);
      expect(
        searchFieldWidgetAfter.controller?.text,
        searchQuery,
        reason: 'Trainers search query should NOT be wiped when resizing across 900px breakpoint',
      );
    });

    testWidgets('Selected tab index is preserved when resizing across 900px boundary', (tester) async {
      tester.view.physicalSize = const Size(800.0, 800.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableMainScreen(initialIndex: 3));
      await tester.pumpAndAdvance();

      // Check Trainers screen is visible
      expect(find.byType(TrainerDiscoveryScreen), findsOneWidget);

      // Resize to desktop (1000px)
      tester.view.physicalSize = const Size(1000.0, 800.0);
      await tester.pumpAndAdvance();

      // Selected tab should still be Trainers (index 3)
      expect(find.byType(TrainerDiscoveryScreen), findsOneWidget);
      expect(find.byType(AdaptiveNavigationRail), findsOneWidget);
      final rail = tester.widget<AdaptiveNavigationRail>(find.byType(AdaptiveNavigationRail));
      expect(rail.selectedIndex, 3);
    });
  });

  group('Adversarial Stress Test: Layout & Overflow Edge Cases', () {
    testWidgets('AdaptiveNavigationRail does not overflow during intermediate transition widths', (tester) async {
      final transitionWidths = [76.0, 100.0, 140.0, 180.0, 220.0, 240.0];

      for (final w in transitionWidths) {
        tester.view.physicalSize = Size(w + 500, 800.0);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: Row(
                children: [
                  SizedBox(
                    width: w,
                    child: AdaptiveNavigationRail(
                      selectedIndex: 0,
                      onDestinationSelected: (_) {},
                      isExtended: w > 150,
                      onToggleExtended: () {},
                      onOpenChat: () {},
                      onOpenPayments: () {},
                    ),
                  ),
                  const Expanded(child: Placeholder()),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull,
            reason: 'AdaptiveNavigationRail must not throw RenderFlex overflow at width $w');
      }
      tester.view.resetPhysicalSize();
    });
  });
}
