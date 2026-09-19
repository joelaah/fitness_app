import 'package:fitness_app/features/exercises/screens/exercise_library_screen.dart';
import 'package:fitness_app/features/home/screens/home_screen.dart';
import 'package:fitness_app/features/routines/screens/routines_screen.dart';
import 'package:fitness_app/features/workout/screens/ai_coach_screen.dart';
import 'package:fitness_app/features/workout/screens/history_screen.dart';
import 'package:flutter/material.dart';

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
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
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
              child: Icon(Icons.home),
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
              child: Icon(Icons.fitness_center),
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
              child: Icon(Icons.auto_awesome),
            ),
            label: 'AI Coach',
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
              child: Icon(Icons.history),
            ),
            label: 'History',
          ),
        ],
      ),
    );
  }
}
