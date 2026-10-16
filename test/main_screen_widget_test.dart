import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/core/theme/app_theme.dart';
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

  group('MainScreen Navigation Architecture & Tab Tests', () {
    testWidgets('renders all 6 navigation destinations in BottomNavigationBar',
        (tester) async {
      await tester.pumpWidget(buildTestableMainScreen());
      await tester.pumpAndAdvance();

      final navBar = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );

      expect(navBar.items.length, 6);
      expect(navBar.items[0].label, 'Home');
      expect(navBar.items[1].label, 'Routines');
      expect(navBar.items[2].label, 'AI Coach');
      expect(navBar.items[3].label, 'Trainers');
      expect(navBar.items[4].label, 'Exercises');
      expect(navBar.items[5].label, 'History');
    });

    testWidgets(
      'Trainers tab is present at index 3 and navigable',
      (tester) async {
        await tester.pumpWidget(buildTestableMainScreen());
        await tester.pumpAndAdvance();

        final navBar = tester.widget<BottomNavigationBar>(
          find.byType(BottomNavigationBar),
        );
        final trainersItem = navBar.items[3];
        expect(trainersItem.label, 'Trainers');

        // Tap tab 3: Trainers
        final trainersTab = find.text('Trainers');
        expect(trainersTab, findsOneWidget);
        await tester.tap(trainersTab);
        await tester.pumpAndAdvance();

        final updatedNavBar = tester.widget<BottomNavigationBar>(
          find.byType(BottomNavigationBar),
        );
        expect(updatedNavBar.currentIndex, 3);
        expect(find.byType(TrainerDiscoveryScreen), findsOneWidget);
      },
    );

    testWidgets(
      'tapping all tabs sequentially switches screens without crashing',
      (tester) async {
        await tester.pumpWidget(buildTestableMainScreen());
        await tester.pumpAndAdvance();

        final navBarFinder = find.byType(BottomNavigationBar);

        // 1. Home (index 0)
        expect(find.byType(HomeScreen), findsOneWidget);

        // 2. Routines (index 1)
        await tester.tap(find.text('Routines'));
        await tester.pumpAndAdvance();
        expect(
          tester.widget<BottomNavigationBar>(navBarFinder).currentIndex,
          1,
        );
        expect(find.byType(RoutinesScreen), findsOneWidget);

        // 3. AI Coach (index 2)
        await tester.tap(find.text('AI Coach'));
        await tester.pumpAndAdvance();
        expect(
          tester.widget<BottomNavigationBar>(navBarFinder).currentIndex,
          2,
        );
        expect(find.byType(AiCoachScreen), findsOneWidget);

        // 4. Trainers (index 3)
        await tester.tap(find.text('Trainers'));
        await tester.pumpAndAdvance();
        expect(
          tester.widget<BottomNavigationBar>(navBarFinder).currentIndex,
          3,
        );
        expect(find.byType(TrainerDiscoveryScreen), findsOneWidget);

        // 5. Exercises (index 4)
        await tester.tap(find.text('Exercises'));
        await tester.pumpAndAdvance();
        expect(
          tester.widget<BottomNavigationBar>(navBarFinder).currentIndex,
          4,
        );
        expect(find.byType(ExerciseLibraryScreen), findsOneWidget);

        // 6. History (index 5)
        await tester.tap(find.text('History'));
        await tester.pumpAndAdvance();
        expect(
          tester.widget<BottomNavigationBar>(navBarFinder).currentIndex,
          5,
        );
        expect(find.byType(HistoryScreen), findsOneWidget);

        // Cycle back to Home
        await tester.tap(find.text('Home'));
        await tester.pumpAndAdvance();
        expect(
          tester.widget<BottomNavigationBar>(navBarFinder).currentIndex,
          0,
        );
        expect(find.byType(HomeScreen), findsOneWidget);
      },
    );

    testWidgets('supports programmatic initialIndex parameter', (tester) async {
      await tester.pumpWidget(buildTestableMainScreen(initialIndex: 3));
      await tester.pumpAndAdvance();

      final navBar = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      expect(navBar.currentIndex, 3);
      expect(find.byType(TrainerDiscoveryScreen), findsOneWidget);
    });

    testWidgets('HomeScreen callbacks switch tabs correctly', (tester) async {
      await tester.pumpWidget(buildTestableMainScreen());
      await tester.pumpAndAdvance();

      // Ensure Browse Routines on HomeScreen is visible before tapping
      final browseRoutinesBtn = find.text('Browse Routines');
      expect(browseRoutinesBtn, findsOneWidget);
      await tester.ensureVisible(browseRoutinesBtn);
      await tester.pumpAndAdvance();
      await tester.tap(browseRoutinesBtn);
      await tester.pumpAndAdvance();

      final navBar = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      expect(navBar.currentIndex, 1);
      expect(find.byType(RoutinesScreen), findsOneWidget);
    });
  });

  group('MainScreen Header Quick Actions Tests', () {
    testWidgets(
      'Home tab displays PulseFit AI branding and header action icons',
      (tester) async {
        await tester.pumpWidget(buildTestableMainScreen());
        await tester.pumpAndAdvance();

        // Branding
        expect(find.text('PulseFit AI'), findsOneWidget);
        expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);

        // Header action buttons
        expect(find.byTooltip('Encrypted Messages'), findsOneWidget);
        expect(find.byTooltip('Payment History'), findsOneWidget);
        expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
        expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);
      },
    );

    testWidgets(
      'Conditional AppBar: Non-Home tabs do not render outer AppBar',
      (tester) async {
        // Routines tab at index 1
        await tester.pumpWidget(buildTestableMainScreen(initialIndex: 1));
        await tester.pumpAndAdvance();

        // PulseFit AI branding AppBar from MainScreen is NOT present
        expect(find.text('PulseFit AI'), findsNothing);
        expect(find.byTooltip('Encrypted Messages'), findsNothing);

        // RoutinesScreen has its own AppBar
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('Routines'),
          ),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.add), findsOneWidget);
      },
    );

    testWidgets(
      'Chat header action icon is present and opens ConversationsScreen',
      (tester) async {
        await tester.pumpWidget(buildTestableMainScreen());
        await tester.pumpAndAdvance();

        final chatActionIcon = find.byTooltip('Encrypted Messages');
        expect(chatActionIcon, findsOneWidget);

        await tester.tap(chatActionIcon);
        await tester.pumpAndAdvance(const Duration(milliseconds: 500));

        // Verify ConversationsScreen is pushed onto Navigator stack
        expect(find.byType(ConversationsScreen), findsOneWidget);

        // Pop back to MainScreen using arrow back button
        final arrowBack = find.byIcon(Icons.arrow_back_rounded);
        expect(arrowBack, findsOneWidget);
        await tester.tap(arrowBack);
        await tester.pumpAndAdvance(const Duration(milliseconds: 500));

        expect(find.byType(MainScreen), findsOneWidget);
        expect(find.byType(ConversationsScreen), findsNothing);
      },
    );

    testWidgets(
      'Payment History header action icon opens PaymentHistoryScreen',
      (tester) async {
        await tester.pumpWidget(buildTestableMainScreen());
        await tester.pumpAndAdvance();

        final paymentsActionIcon = find.byTooltip('Payment History');
        expect(paymentsActionIcon, findsOneWidget);

        await tester.tap(paymentsActionIcon);
        await tester.pumpAndAdvance(const Duration(milliseconds: 500));

        // Verify PaymentHistoryScreen is pushed onto Navigator stack
        expect(find.byType(PaymentHistoryScreen), findsOneWidget);

        // Pop back to MainScreen
        final backButton = find.byType(BackButton);
        expect(backButton, findsOneWidget);
        await tester.tap(backButton);
        await tester.pumpAndAdvance(const Duration(milliseconds: 500));

        expect(find.byType(MainScreen), findsOneWidget);
        expect(find.byType(PaymentHistoryScreen), findsNothing);
      },
    );
  });

  group('MainScreen Theme Tokens & Design System Compliance Tests', () {
    testWidgets(
      'Scaffold and BottomNavigationBar adhere to PulseFit tokens',
      (tester) async {
        await tester.pumpWidget(buildTestableMainScreen());
        await tester.pumpAndAdvance();

        // 1. Scaffold background
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
        expect(scaffold.backgroundColor, AppColors.background);
        expect(scaffold.backgroundColor, const Color(0xFF0F172A));

        // 2. Navigation bar container decoration
        final container = tester.widget<Container>(
          find.byKey(const Key('bottom_nav_container')),
        );
        final decoration = container.decoration as BoxDecoration?;
        expect(decoration?.color, AppColors.surface);
        expect(decoration?.color, const Color(0xFF1E293B));
        expect(decoration?.border?.top.color, AppColors.border);
        expect(decoration?.border?.top.color, const Color(0xFF334155));

        // 3. BottomNavigationBar colors
        final navBar = tester.widget<BottomNavigationBar>(
          find.byType(BottomNavigationBar),
        );
        expect(navBar.backgroundColor, AppColors.surface);
        expect(navBar.selectedItemColor, AppColors.primary);
        expect(navBar.selectedItemColor, const Color(0xFF00E676));
        expect(navBar.unselectedItemColor, AppColors.textSecondary);
        expect(navBar.unselectedItemColor, const Color(0xFF94A3B8));
      },
    );

    testWidgets(
      'MainScreen contains strictly ZERO PopScope or WillPopScope',
      (tester) async {
        await tester.pumpWidget(buildTestableMainScreen());
        await tester.pumpAndAdvance();

        expect(find.byType(PopScope), findsNothing);
        expect(
          find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == 'WillPopScope',
          ),
          findsNothing,
        );
      },
    );
  });
}
