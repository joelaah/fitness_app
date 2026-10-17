import 'package:fitness_app/core/responsive/app_breakpoints.dart';
import 'package:fitness_app/core/theme/app_theme.dart';
import 'package:fitness_app/core/widgets/animated_neon_volume_ring.dart';
import 'package:fitness_app/features/chat/bloc/chat_bloc.dart';
import 'package:fitness_app/features/chat/screens/conversations_screen.dart';
import 'package:fitness_app/features/routines/providers/routine_provider.dart';
import 'package:fitness_app/features/routines/repositories/shared_prefs_routine_repository.dart';
import 'package:fitness_app/features/routines/screens/routines_screen.dart';
import 'package:fitness_app/features/trainers/screens/trainer_discovery_screen.dart';
import 'package:fitness_app/features/workout/bloc/ai_coach_bloc.dart';
import 'package:fitness_app/features/workout/providers/workout_provider.dart';
import 'package:fitness_app/features/workout/repositories/workout_history_repository.dart';
import 'package:fitness_app/features/workout/screens/ai_coach_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  group('Desktop Responsive Screens Tests', () {
    testWidgets('RoutinesScreen renders multi-column grid and neon volume ring on desktop',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => RoutineProvider(repository: routineRepository),
            ),
            ChangeNotifierProvider(
              create: (_) => WorkoutProvider(historyRepository: historyRepository),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const RoutinesScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Neon volume ring overview deck should be present
      expect(find.byType(AnimatedNeonVolumeRing), findsOneWidget);
      expect(find.text('Volume & Consistency Telemetry'), findsOneWidget);

      // On 1280px wide desktop, template cards should be laid out in a GridView
      expect(find.byType(GridView), findsOneWidget);
      final gridView = tester.widget<GridView>(find.byType(GridView));
      final delegate = gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 3);
      expect(delegate.mainAxisExtent, 96.0);
    });

    testWidgets('RoutinesScreen renders single column list on mobile (<900px)',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => RoutineProvider(repository: routineRepository),
            ),
            ChangeNotifierProvider(
              create: (_) => WorkoutProvider(historyRepository: historyRepository),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const RoutinesScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // On mobile, GridView is omitted in favor of single-column Column layout
      expect(find.byType(GridView), findsNothing);
      expect(find.text('Upper / Lower'), findsOneWidget);
    });

    testWidgets('TrainerDiscoveryScreen renders SliverGrid on desktop (>=900px)',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const TrainerDiscoveryScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Check for ConstrainedBox enforcing marketplaceMaxWidth (1280.0)
      final constrainedBoxes = tester.widgetList<ConstrainedBox>(find.byType(ConstrainedBox));
      final hasMarketplaceMax = constrainedBoxes.any(
        (box) => box.constraints.maxWidth == AppBreakpoints.marketplaceMaxWidth,
      );
      expect(hasMarketplaceMax, isTrue);

      // Should render SliverGrid for coaches on desktop
      expect(find.byType(SliverGrid), findsOneWidget);
      final sliverGrid = tester.widget<SliverGrid>(find.byType(SliverGrid));
      final delegate =
          sliverGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 3);
      expect(delegate.mainAxisExtent, 220.0);
    });

    testWidgets('AiCoachScreen renders dual-column split view on desktop (>=900px)',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => RoutineProvider(repository: routineRepository),
            ),
            ChangeNotifierProvider(
              create: (_) => WorkoutProvider(historyRepository: historyRepository),
            ),
          ],
          child: MultiBlocProvider(
            providers: [
              BlocProvider<AiCoachBloc>(create: (_) => AiCoachBloc()),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const Scaffold(body: AiCoachScreen()),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Should render split view Row with Chat (flex: 5) and Insights (flex: 6)
      final expandedList = tester.widgetList<Expanded>(find.byType(Expanded));
      final hasFlex5 = expandedList.any((e) => e.flex == 5);
      final hasFlex6 = expandedList.any((e) => e.flex == 6);
      expect(hasFlex5, isTrue);
      expect(hasFlex6, isTrue);

      // TabBar is hidden on desktop split view
      expect(find.byType(TabBar), findsNothing);
    });

    testWidgets('ConversationsScreen renders split-view roster and placeholder on desktop',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<ChatBloc>(create: (_) => ChatBloc()),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const ConversationsScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // On desktop, empty chat placeholder is shown on right pane
      expect(find.text('PulseFit AI Encrypted Chat'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    });
  });
}
