import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/features/chat/bloc/chat_bloc.dart';
import 'package:fitness_app/features/chat/screens/conversations_screen.dart';
import 'package:fitness_app/features/exercises/screens/exercise_library_screen.dart';
import 'package:fitness_app/features/home/screens/home_screen.dart';
import 'package:fitness_app/features/payments/screens/payment_history_screen.dart';
import 'package:fitness_app/features/routines/screens/routines_screen.dart';
import 'package:fitness_app/features/trainers/screens/trainer_discovery_screen.dart';
import 'package:fitness_app/features/workout/screens/ai_coach_screen.dart';
import 'package:fitness_app/features/workout/screens/history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

/// PulseFit AI Main Screen Shell
///
/// Implements a 6-destination bottom navigation bar with [IndexedStack]
/// state preservation, Dark/Neon PulseFit design token compliance,
/// and contextual quick-access header actions.
///
/// Navigation Tab Architecture:
/// - Index 0: Home (Dashboard, Daily Streak, Quick Actions)
/// - Index 1: Routines (Split Templates, Custom Workouts)
/// - Index 2: AI Coach (RAG Recommendation Engine)
/// - Index 3: Trainers (Coach Marketplace, Certifications, E2EE Chat Hub)
/// - Index 4: Exercises (Exercise Library & Filtering)
/// - Index 5: History (Past Workout Logs & Metrics)
///
/// Design System Tokens:
/// - Scaffold Background: [AppColors.background] (`#0F172A`)
/// - Navigation Container: [AppColors.surface] (`#1E293B`)
/// - Container Top Border: [AppColors.border] (`#334155`)
/// - Selected Tab Accent: [AppColors.primary] (`#00E676` Electric Mint)
/// - Unselected Tab Color: [AppColors.textSecondary] (`#94A3B8`)
///
/// Architecture Constraints:
/// - Strictly ZERO usage of PopScope or deprecated WillPopScope.
/// - Safe route construction injecting [ChatBloc] into [ConversationsScreen]
///   if absent from context.
class MainScreen extends StatefulWidget {
  const MainScreen({
    super.key,
    this.initialIndex = 0,
  });

  /// Allows programmatic or deep-link tab selection (default: 0)
  final int initialIndex;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _selectedIndex;

  late final List<Widget> _screens = [
    HomeScreen(
      onBrowseRoutines: () {
        setState(() {
          _selectedIndex = 1;
        });
      },
      onOpenAiCoach: () {
        setState(() {
          _selectedIndex = 2;
        });
      },
    ),
    const RoutinesScreen(),
    const AiCoachScreen(),
    const TrainerDiscoveryScreen(),
    const ExerciseLibraryScreen(),
    const HistoryScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, 5);
  }

  void _navigateToChat(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<dynamic>(
        builder: (ctx) {
          try {
            final bloc = ctx.read<ChatBloc>();
            return ConversationsScreen(chatBloc: bloc);
          } on Exception catch (_) {
            return BlocProvider<ChatBloc>(
              create: (_) => ChatBloc(),
              child: const ConversationsScreen(),
            );
          }
        },
      ),
    );
  }

  void _navigateToPayments(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<dynamic>(
        builder: (ctx) => const PaymentHistoryScreen(),
      ),
    );
  }

  PreferredSizeWidget? _buildHeaderAppBar(BuildContext context) {
    // Only render top AppBar on the Home tab (index 0).
    // Child tabs render their own dedicated headers.
    if (_selectedIndex != 0) return null;

    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      centerTitle: false,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.primary.withAlpha(80),
              ),
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'PulseFit AI',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          key: const Key('chat_header_action'),
          icon: const Icon(
            Icons.chat_bubble_outline_rounded,
            color: AppColors.textPrimary,
            size: 22,
          ),
          tooltip: 'Encrypted Messages',
          onPressed: () => _navigateToChat(context),
        ),
        IconButton(
          key: const Key('payments_header_action'),
          icon: const Icon(
            Icons.receipt_long_outlined,
            color: AppColors.textPrimary,
            size: 22,
          ),
          tooltip: 'Payment History',
          onPressed: () => _navigateToPayments(context),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildHeaderAppBar(context),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        key: const Key('bottom_nav_container'),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(
              color: AppColors.border,
            ),
          ),
        ),
        child: BottomNavigationBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          selectedLabelStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
          unselectedLabelStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w500,
            fontSize: 11,
          ),
          showSelectedLabels: true,
          showUnselectedLabels: true,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.home_outlined),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.home_rounded),
              ),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.fitness_center_outlined),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.fitness_center_rounded),
              ),
              label: 'Routines',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.auto_awesome_outlined),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.auto_awesome_rounded),
              ),
              label: 'AI Coach',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.sports_gymnastics_outlined),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.sports_gymnastics_rounded),
              ),
              label: 'Trainers',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.list_alt),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.list_alt_rounded),
              ),
              label: 'Exercises',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.history_outlined),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.history_rounded),
              ),
              label: 'History',
            ),
          ],
        ),
      ),
    );
  }
}
