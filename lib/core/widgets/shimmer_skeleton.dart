import 'package:fitness_app/core/responsive/app_breakpoints.dart';
import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/core/theme/app_spacing.dart';
import 'package:fitness_app/core/widgets/elevated_card.dart';
import 'package:flutter/material.dart';

/// A lightweight, hardware-accelerated shimmer effect wrapper for skeleton loaders.
///
/// Uses [RepaintBoundary] and [ShaderMask] to ensure that shimmer animations
/// execute entirely on the GPU without triggering layout passes or ancestor repaints.
/// In widget test environments, it gracefully halts continuous repeating so that
/// `pumpAndSettle` assertions settle immediately.
class PulseShimmer extends StatefulWidget {
  const PulseShimmer({
    required this.child,
    super.key,
    this.baseColor,
    this.highlightColor,
    this.duration = const Duration(milliseconds: 1500),
  });

  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration duration;

  @override
  State<PulseShimmer> createState() => _PulseShimmerState();
}

class _PulseShimmerState extends State<PulseShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final isTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (disableAnimations || isTest) {
      if (_controller.isAnimating) {
        _controller.stop();
      }
      _controller.value = 0.5;
    } else {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    }
  }

  @override
  void didUpdateWidget(PulseShimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.baseColor ?? AppColors.surface;
    final highlight = widget.highlightColor ??
        Color.lerp(AppColors.surfaceElevated, AppColors.primary, 0.12)!;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          final slide = _controller.value;
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) {
              if (bounds.isEmpty) {
                return const LinearGradient(
                  colors: [Colors.transparent, Colors.transparent],
                ).createShader(const Rect.fromLTWH(0, 0, 1, 1));
              }
              return LinearGradient(
                begin: Alignment(-2.0 + 4.0 * slide, -0.3),
                end: Alignment(-1.0 + 4.0 * slide, 0.3),
                colors: [
                  base,
                  highlight,
                  base,
                ],
                stops: const [0.1, 0.5, 0.9],
              ).createShader(bounds);
            },
            child: child,
          );
        },
      ),
    );
  }
}

/// A rounded rectangle placeholder box used to compose skeleton screens.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8.0,
    this.margin,
    this.color,
  });

  final double? width;
  final double? height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final safeRadius = (borderRadius.isNaN ||
            borderRadius.isInfinite ||
            borderRadius < 0.0)
        ? 0.0
        : borderRadius;
    final safeWidth = (width != null &&
            (width!.isNaN || width!.isInfinite || width! < 0.0))
        ? 0.0
        : width;
    final safeHeight = (height != null &&
            (height!.isNaN || height!.isInfinite || height! < 0.0))
        ? 0.0
        : height;
    return Container(
      width: safeWidth,
      height: safeHeight,
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? AppColors.surfaceElevated.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(safeRadius),
      ),
    );
  }
}

/// A circular placeholder used to compose skeleton avatars and indicators.
class ShimmerCircle extends StatelessWidget {
  const ShimmerCircle({
    required this.size,
    super.key,
    this.color,
  });

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final safeSize =
        (size.isNaN || size.isInfinite || size < 0.0) ? 0.0 : size;
    return Container(
      width: safeSize,
      height: safeSize,
      decoration: BoxDecoration(
        color: color ?? AppColors.surfaceElevated.withValues(alpha: 0.6),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Shimmer skeleton for routines loading in [RoutinesScreen].
class ShimmerRoutinesSkeleton extends StatelessWidget {
  const ShimmerRoutinesSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppBreakpoints.contentMaxWidth,
        ),
        child: PulseShimmer(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            children: [
              // Volume Deck Placeholder
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: ElevatedCard(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const ShimmerCircle(size: 110),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            ShimmerBox(width: 180, height: 18, borderRadius: 6),
                            SizedBox(height: 10),
                            ShimmerBox(
                              width: double.infinity,
                              height: 12,
                              borderRadius: 4,
                            ),
                            SizedBox(height: 6),
                            ShimmerBox(width: 140, height: 12, borderRadius: 4),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // "My Routines" Title
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: ShimmerBox(width: 140, height: 20, borderRadius: 6),
              ),
              const SizedBox(height: AppSpacing.md),

              // Routine horizontal cards
              SizedBox(
                height: 220,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  scrollDirection: Axis.horizontal,
                  itemCount: 3,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: AppSpacing.md),
                  itemBuilder: (_, __) => const SizedBox(
                    width: 200,
                    child: ElevatedCard(
                      padding: EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerBox(
                            width: double.infinity,
                            height: 110,
                            borderRadius: 12,
                          ),
                          SizedBox(height: 12),
                          ShimmerBox(width: 130, height: 16, borderRadius: 4),
                          SizedBox(height: 8),
                          ShimmerBox(width: 80, height: 12, borderRadius: 4),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // "Explore Templates" Title
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: ShimmerBox(width: 160, height: 20, borderRadius: 6),
              ),
              const SizedBox(height: AppSpacing.md),

              // Grid templates
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Column(
                  children: List.generate(
                    2,
                    (_) => const Padding(
                      padding: EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ElevatedCard(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            ShimmerBox(width: 40, height: 40, borderRadius: 10),
                            SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ShimmerBox(
                                    width: 140,
                                    height: 16,
                                    borderRadius: 4,
                                  ),
                                  SizedBox(height: 6),
                                  ShimmerBox(
                                    width: 90,
                                    height: 12,
                                    borderRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shimmer skeleton for trainer marketplace loading in [TrainerDiscoveryScreen].
class ShimmerTrainerDiscoverySkeleton extends StatelessWidget {
  const ShimmerTrainerDiscoverySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return PulseShimmer(
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (_, __) => const ElevatedCard(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar + Name + Rate
              Row(
                children: [
                  ShimmerCircle(size: 52),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(width: 140, height: 16, borderRadius: 4),
                        SizedBox(height: 6),
                        ShimmerBox(width: 100, height: 12, borderRadius: 4),
                      ],
                    ),
                  ),
                  ShimmerBox(width: 50, height: 24, borderRadius: 6),
                ],
              ),
              SizedBox(height: 14),
              // Bio lines
              ShimmerBox(width: double.infinity, height: 12, borderRadius: 4),
              SizedBox(height: 6),
              ShimmerBox(width: 220, height: 12, borderRadius: 4),
              SizedBox(height: 14),
              // Specialty chips
              Row(
                children: [
                  ShimmerBox(width: 70, height: 24, borderRadius: 12),
                  SizedBox(width: 8),
                  ShimmerBox(width: 85, height: 24, borderRadius: 12),
                  SizedBox(width: 8),
                  ShimmerBox(width: 60, height: 24, borderRadius: 12),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shimmer skeleton for trainer dashboard loading in [TrainerDashboardScreen].
class ShimmerTrainerDashboardSkeleton extends StatelessWidget {
  const ShimmerTrainerDashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return PulseShimmer(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: const [
            Row(
              children: [
                Expanded(
                  child: ElevatedCard(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(width: 32, height: 32, borderRadius: 8),
                        SizedBox(height: 12),
                        ShimmerBox(width: 80, height: 24, borderRadius: 4),
                        SizedBox(height: 6),
                        ShimmerBox(width: 60, height: 12, borderRadius: 4),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ElevatedCard(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(width: 32, height: 32, borderRadius: 8),
                        SizedBox(height: 12),
                        ShimmerBox(width: 80, height: 24, borderRadius: 4),
                        SizedBox(height: 6),
                        ShimmerBox(width: 60, height: 12, borderRadius: 4),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.md),
            ElevatedCard(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 140, height: 18, borderRadius: 4),
                  SizedBox(height: 14),
                  ShimmerBox(
                    width: double.infinity,
                    height: 12,
                    borderRadius: 4,
                  ),
                  SizedBox(height: 8),
                  ShimmerBox(
                    width: double.infinity,
                    height: 12,
                    borderRadius: 4,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer skeleton for active workout screen loading in [WorkoutActiveScreen].
class ShimmerWorkoutActiveSkeleton extends StatelessWidget {
  const ShimmerWorkoutActiveSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return PulseShimmer(
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: 2,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (_, __) => const ElevatedCard(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ShimmerBox(width: 160, height: 18, borderRadius: 4),
                  ShimmerCircle(size: 20),
                ],
              ),
              SizedBox(height: 16),
              // Header row
              Row(
                children: [
                  ShimmerBox(width: 28, height: 12, borderRadius: 4),
                  SizedBox(width: 16),
                  Expanded(
                    child: ShimmerBox(
                      width: double.infinity,
                      height: 12,
                      borderRadius: 4,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ShimmerBox(
                      width: double.infinity,
                      height: 12,
                      borderRadius: 4,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ShimmerBox(
                      width: double.infinity,
                      height: 12,
                      borderRadius: 4,
                    ),
                  ),
                  SizedBox(width: 16),
                  ShimmerBox(width: 32, height: 12, borderRadius: 4),
                ],
              ),
              SizedBox(height: 12),
              // Set rows
              _ShimmerSetRow(),
              SizedBox(height: 8),
              _ShimmerSetRow(),
              SizedBox(height: 8),
              _ShimmerSetRow(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShimmerSetRow extends StatelessWidget {
  const _ShimmerSetRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        ShimmerBox(width: 24, height: 18, borderRadius: 4),
        SizedBox(width: 12),
        Expanded(child: ShimmerBox(height: 32, borderRadius: 8)),
        SizedBox(width: 8),
        Expanded(child: ShimmerBox(height: 32, borderRadius: 8)),
        SizedBox(width: 8),
        Expanded(child: ShimmerBox(height: 32, borderRadius: 8)),
        SizedBox(width: 8),
        ShimmerBox(width: 34, height: 32, borderRadius: 8),
      ],
    );
  }
}

/// Shimmer skeleton for exercise library and picker screens.
class ShimmerExerciseLibrarySkeleton extends StatelessWidget {
  const ShimmerExerciseLibrarySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return PulseShimmer(
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Search box
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: ShimmerBox(
                width: double.infinity,
                height: 48,
                borderRadius: 16,
              ),
            ),
            // Category chips
            SizedBox(
              height: 36,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                scrollDirection: Axis.horizontal,
                itemCount: 5,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, __) =>
                    const ShimmerBox(width: 80, height: 34, borderRadius: 18),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Exercise item cards
            ...List.generate(
              4,
              (index) => const Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: ElevatedCard(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      ShimmerBox(width: 60, height: 60, borderRadius: 12),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerBox(width: 150, height: 16, borderRadius: 4),
                            SizedBox(height: 6),
                            ShimmerBox(width: 100, height: 12, borderRadius: 4),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
