import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Reusable fade-through page transition builder conforming to PulseFit AI's
/// dark neon aesthetic. Eliminates white flashes and desktop slide jank.
class PulseFitPageTransitionsBuilder extends PageTransitionsBuilder {
  const PulseFitPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _PulseFitFadeThroughTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}

class _PulseFitFadeThroughTransition extends StatelessWidget {
  const _PulseFitFadeThroughTransition({
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    final curvedSecondary = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    final primaryFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: curvedAnimation,
        curve: const Interval(0.20, 1.0, curve: Curves.easeOut),
      ),
    );

    final primaryScale =
        Tween<double>(begin: 0.96, end: 1.0).animate(curvedAnimation);

    final secondaryFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: curvedSecondary,
        curve: const Interval(0.0, 0.40, curve: Curves.easeIn),
      ),
    );

    final secondaryScale =
        Tween<double>(begin: 1.0, end: 0.96).animate(curvedSecondary);

    return ColoredBox(
      color: AppColors.background,
      child: FadeTransition(
        opacity: secondaryFade,
        child: ScaleTransition(
          scale: secondaryScale,
          child: FadeTransition(
            opacity: primaryFade,
            child: ScaleTransition(
              scale: primaryScale,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
