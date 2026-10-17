import 'package:fitness_app/core/responsive/app_breakpoints.dart';
import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/core/theme/app_spacing.dart';
import 'package:fitness_app/core/widgets/animated_neon_volume_ring.dart';
import 'package:fitness_app/core/widgets/elevated_card.dart';
import 'package:fitness_app/core/widgets/perspective_tilt_card.dart';
import 'package:fitness_app/features/routines/data/routine_templates.dart';
import 'package:fitness_app/features/routines/models/routine.dart';
import 'package:fitness_app/features/routines/providers/routine_provider.dart';
import 'package:fitness_app/features/routines/screens/routine_detail_screen.dart';
import 'package:fitness_app/features/routines/widgets/routine_cover_card.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({super.key});

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  bool _isProcessing = false;
  String? _activeCreatingRoutineName;

  static final List<_TemplateEntry> _templates = [
    _TemplateEntry(
      template: RoutineTemplates.upperLower,
      icon: Icons.layers,
      tag: 'RECOMMENDED • 4 DAYS',
      isRecommended: true,
    ),
    _TemplateEntry(
      template: RoutineTemplates.pplHybrid,
      icon: Icons.flash_on,
      tag: '5 DAYS • PPL + UPPER/LOWER HYBRID',
      isRecommended: true,
    ),
    _TemplateEntry(
      template: RoutineTemplates.broSplit,
      icon: Icons.military_tech,
      tag: '5 DAYS • CLASSIC BODYPART SPLIT',
    ),
    _TemplateEntry(
      template: RoutineTemplates.phul,
      icon: Icons.bolt,
      tag: '4 DAYS • POWER & HYPERTROPHY',
    ),
    _TemplateEntry(
      template: RoutineTemplates.torsoLimbs,
      icon: Icons.sports_gymnastics,
      tag: '4 DAYS • TORSO & LIMBS',
    ),
    _TemplateEntry(
      template: RoutineTemplates.ppl,
      icon: Icons.repeat,
      tag: '6 DAYS • CLASSIC PUSH PULL LEGS',
    ),
    _TemplateEntry(
      template: RoutineTemplates.arnold,
      icon: Icons.fitness_center,
      tag: '6 DAYS • CHEST & ARMS FOCUS',
    ),
    _TemplateEntry(
      template: RoutineTemplates.fullBody,
      icon: Icons.accessibility_new,
      tag: '3 DAYS • BUSY SCHEDULE',
    ),
  ];

  Future<void> _createNewRoutine(RoutineProvider provider) async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
    });

    try {
      final newRoutine = WorkoutRoutine(
        id: const Uuid().v4(),
        name: 'My Custom Routine',
      );
      await provider.saveRoutine(newRoutine);
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute<dynamic>(
            builder: (_) => RoutineDetailScreen(routine: newRoutine),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RoutineProvider>();
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= AppBreakpoints.desktopMin;
    final isWide = width >= AppBreakpoints.wideDesktopMin;
    final crossAxisCount = isWide ? 3 : (isDesktop ? 2 : 1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Routines'),
        actions: [
          IconButton(
            icon: _isProcessing && _activeCreatingRoutineName == null
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : const Icon(Icons.add),
            onPressed: _isProcessing ? null : () => _createNewRoutine(provider),
          ),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppBreakpoints.contentMaxWidth,
                ),
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  children: [
                    _buildVolumeOverviewDeck(context),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: _buildSectionTitle('My Routines', context),
                    ),
                    if (provider.routines.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.md,
                        ),
                        child: Text(
                          'No routines yet. Create one or pick a template!',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    else
                      SizedBox(
                        height: 240,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                          itemCount: provider.routines.length,
                          itemBuilder: (context, index) {
                            final routine = provider.routines[index];
                            return RoutineCoverCard(
                              routine: routine,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute<dynamic>(
                                    builder: (_) =>
                                        RoutineDetailScreen(routine: routine),
                                  ),
                                );
                              },
                              onDelete: () async {
                                final routineProvider =
                                    context.read<RoutineProvider>();
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: const Text('Delete Routine?'),
                                    content: Text(
                                      'Are you sure you want to delete "${routine.name}"?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogContext, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogContext, true),
                                        child: const Text(
                                          'Delete',
                                          style: TextStyle(
                                              color: Colors.redAccent),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await routineProvider
                                      .deleteRoutine(routine.id);
                                }
                              },
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: AppSpacing.xl),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: _buildSectionTitle('Explore Templates', context),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: crossAxisCount == 1
                          ? Column(
                              children: _templates
                                  .map(
                                    (e) => _buildTemplateCard(
                                      context,
                                      template: e.template,
                                      icon: e.icon,
                                      tag: e.tag,
                                      isRecommended: e.isRecommended,
                                    ),
                                  )
                                  .toList(),
                            )
                          : GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                mainAxisExtent: 96,
                              ),
                              itemCount: _templates.length,
                              itemBuilder: (context, index) {
                                final e = _templates[index];
                                return _buildTemplateCard(
                                  context,
                                  template: e.template,
                                  icon: e.icon,
                                  tag: e.tag,
                                  isRecommended: e.isRecommended,
                                  isGrid: true,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildVolumeOverviewDeck(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.lg),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 600;
            const ringWidget = AnimatedNeonVolumeRing(
              size: 140,
              centerTitle: '82%',
              centerSubtitle: 'VOLUME GOAL',
              centerIcon: Icons.bolt_rounded,
              rings: [
                VolumeRingData(
                  progress: 0.82,
                  startColor: AppColors.primary,
                  endColor: Color(0xFF00E676),
                  strokeWidth: 8,
                  label: 'Consistency',
                ),
                VolumeRingData(
                  progress: 0.70,
                  startColor: Color(0xFF3B82F6),
                  endColor: Color(0xFF06B6D4),
                  strokeWidth: 8,
                  label: 'Push / Pull',
                ),
                VolumeRingData(
                  progress: 0.90,
                  startColor: Color(0xFFA855F7),
                  endColor: Color(0xFFEC4899),
                  strokeWidth: 8,
                  label: 'Weekly Target',
                ),
              ],
            );

            if (isCompact) {
              return Column(
                children: [
                  ringWidget,
                  const SizedBox(height: 12),
                  _buildVolumeLegendRow(),
                ],
              );
            }

            return Row(
              children: [
                ringWidget,
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Volume & Consistency Telemetry',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Track weekly mechanical tension, push/pull split volume, and completion targets in real-time.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildVolumeLegendRow(),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildVolumeLegendRow() {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _buildLegendChip(
          label: 'Weekly Goal: 4/5',
          color: AppColors.primary,
          icon: Icons.check_circle_outline_rounded,
        ),
        _buildLegendChip(
          label: 'Push/Pull: Balanced',
          color: const Color(0xFF3B82F6),
          icon: Icons.sync_alt_rounded,
        ),
        _buildLegendChip(
          label: 'Target: 14.2k kg',
          color: const Color(0xFFA855F7),
          icon: Icons.fitness_center_rounded,
        ),
      ],
    );
  }

  Widget _buildLegendChip({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge,
      ),
    );
  }

  Widget _buildTemplateCard(
    BuildContext context, {
    required WorkoutRoutine template,
    required IconData icon,
    required String tag,
    bool isRecommended = false,
    bool isGrid = false,
  }) {
    final theme = Theme.of(context);

    final card = ElevatedCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isRecommended
                  ? AppColors.primary.withAlpha(38)
                  : AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: isRecommended
                  ? AppColors.primary
                  : AppColors.textSecondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        template.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isRecommended
                        ? AppColors.primary.withAlpha(38)
                        : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    tag,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isRecommended
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${template.days.length} Days • Balanced Workout',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.background,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _isProcessing
                ? null
                : () async {
                    final routineProvider = context.read<RoutineProvider>();
                    final navigator = Navigator.of(context);
                    setState(() {
                      _isProcessing = true;
                      _activeCreatingRoutineName = template.name;
                    });
                    try {
                      final clonedRoutine = template.clone(newId: true);
                      await routineProvider.saveRoutine(clonedRoutine);
                      if (mounted) {
                        await navigator.push(
                          MaterialPageRoute<dynamic>(
                            builder: (_) =>
                                RoutineDetailScreen(routine: clonedRoutine),
                          ),
                        );
                      }
                    } finally {
                      if (mounted) {
                        setState(() {
                          _isProcessing = false;
                          _activeCreatingRoutineName = null;
                        });
                      }
                    }
                  },
            child: _activeCreatingRoutineName == template.name
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.background,
                    ),
                  )
                : Text(
                    'USE',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: AppColors.background,
                    ),
                  ),
          ),
        ],
      ),
    );

    final tiltedCard = PerspectiveTiltCard(
      borderRadius: 16,
      elevation: 2.0,
      child: card,
    );

    if (isGrid) {
      return tiltedCard;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: tiltedCard,
    );
  }
}

class _TemplateEntry {
  const _TemplateEntry({
    required this.template,
    required this.icon,
    required this.tag,
    this.isRecommended = false,
  });

  final WorkoutRoutine template;
  final IconData icon;
  final String tag;
  final bool isRecommended;
}
