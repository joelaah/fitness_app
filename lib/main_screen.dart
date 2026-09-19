import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/features/exercises/screens/exercise_library_screen.dart';
import 'package:fitness_app/features/home/screens/home_screen.dart';
import 'package:fitness_app/features/routines/screens/routines_screen.dart';
import 'package:fitness_app/features/workout/screens/ai_coach_screen.dart';
import 'package:fitness_app/features/workout/screens/history_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

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
    const ExerciseLibraryScreen(),
    const HistoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: const Border(
            top: BorderSide(
              color: AppColors.border,
              width: 1.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: BottomNavigationBar(
                elevation: 0,
                backgroundColor: Colors.transparent,
                type: BottomNavigationBarType.fixed,
                currentIndex: _selectedIndex,
                selectedItemColor: AppColors.primary,
                unselectedItemColor: AppColors.textSecondary,
                selectedIconTheme: const IconThemeData(
                  size: 26,
                  color: AppColors.primary,
                ),
                unselectedIconTheme: const IconThemeData(
                  size: 24,
                  color: AppColors.textSecondary,
                ),
                selectedLabelStyle: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                unselectedLabelStyle: GoogleFonts.inter(
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
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
                      child: Icon(Icons.format_list_bulleted_outlined),
                    ),
                    activeIcon: Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Icon(Icons.format_list_bulleted_rounded),
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
          ),
        ),
      ),
    );
  }
}
