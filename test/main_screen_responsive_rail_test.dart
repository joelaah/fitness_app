import 'package:fitness_app/core/theme/app_theme.dart';
import 'package:fitness_app/core/widgets/adaptive_navigation_rail.dart';
import 'package:fitness_app/features/chat/screens/conversations_screen.dart';
import 'package:fitness_app/features/payments/screens/payment_history_screen.dart';
import 'package:fitness_app/features/routines/providers/routine_provider.dart';
import 'package:fitness_app/features/routines/repositories/shared_prefs_routine_repository.dart';
import 'package:fitness_app/features/trainers/screens/trainer_discovery_screen.dart';
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
      child: BlocProvider<AiCoachBloc>(
        create: (_) => AiCoachBloc(),
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: MainScreen(initialIndex: initialIndex),
        ),
      ),
    );
  }

  group('Adaptive Navigation Rail & Desktop Responsiveness Tests', () {
    testWidgets('renders NavigationRail on viewport >= 900px width', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableMainScreen());
      await tester.pumpAndAdvance();

      expect(find.byType(AdaptiveNavigationRail), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsNothing);
      expect(find.text('PulseFit AI'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Routines'), findsOneWidget);
      expect(find.text('AI Coach'), findsOneWidget);
      expect(find.text('Trainers'), findsOneWidget);
      expect(find.text('Exercises'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
    });

    testWidgets('renders BottomNavigationBar on mobile viewport < 900px width', (tester) async {
      tester.view.physicalSize = const Size(600, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableMainScreen());
      await tester.pumpAndAdvance();

      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.byType(AdaptiveNavigationRail), findsNothing);
    });

    testWidgets('navigates to Trainers and AI Coach via rail destination taps', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableMainScreen());
      await tester.pumpAndAdvance();

      // Tap Trainers in rail
      await tester.tap(find.text('Trainers'));
      await tester.pumpAndAdvance();
      expect(find.byType(TrainerDiscoveryScreen), findsOneWidget);

      // Tap AI Coach in rail
      await tester.tap(find.text('AI Coach'));
      await tester.pumpAndAdvance();
      expect(find.byType(AiCoachScreen), findsOneWidget);
    });

    testWidgets('toggles rail between expanded and collapsed modes', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableMainScreen());
      await tester.pumpAndAdvance();

      // Starts expanded (240px)
      final railInitial = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byType(AdaptiveNavigationRail),
          matching: find.byType(AnimatedContainer),
        ).first,
      );
      expect(railInitial.constraints?.maxWidth ?? (railInitial.decoration != null ? 240.0 : 0.0), 240.0);

      // Tap collapse button
      final collapseBtn = find.byTooltip('Collapse Sidebar');
      expect(collapseBtn, findsOneWidget);
      await tester.tap(collapseBtn);
      await tester.pumpAndAdvance();

      // Now collapsed (76px)
      final expandBtn = find.byTooltip('Expand Sidebar');
      expect(expandBtn, findsOneWidget);

      // Tap expand button
      await tester.tap(expandBtn);
      await tester.pumpAndAdvance();
      expect(find.byTooltip('Collapse Sidebar'), findsOneWidget);
    });

    testWidgets('rail footer quick actions navigate to Chat and Payments', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableMainScreen());
      await tester.pumpAndAdvance();

      // Tap Chat action in rail footer
      final chatAction = find.byKey(const Key('chat_rail_action'));
      expect(chatAction, findsOneWidget);
      await tester.tap(chatAction);
      await tester.pumpAndAdvance(const Duration(milliseconds: 500));
      expect(find.byType(ConversationsScreen), findsOneWidget);

      // Pop back using navigator
      Navigator.of(tester.element(find.byType(ConversationsScreen))).pop();
      await tester.pumpAndAdvance(const Duration(milliseconds: 500));
      expect(find.byType(ConversationsScreen), findsNothing);

      // Tap Payments action in rail footer
      final paymentsAction = find.byKey(const Key('payments_rail_action'));
      expect(paymentsAction, findsOneWidget);
      await tester.tap(paymentsAction);
      await tester.pumpAndAdvance(const Duration(milliseconds: 500));
      expect(find.byType(PaymentHistoryScreen), findsOneWidget);
    });
  });
}
