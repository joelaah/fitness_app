import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/core/theme/app_spacing.dart';
import 'package:fitness_app/core/widgets/elevated_card.dart';
import 'package:fitness_app/features/routines/data/routine_templates.dart';
import 'package:fitness_app/features/routines/models/routine.dart';
import 'package:fitness_app/features/routines/providers/routine_provider.dart';
import 'package:fitness_app/features/routines/screens/routine_detail_screen.dart';
import 'package:fitness_app/features/routines/widgets/routine_cover_card.dart';
import 'package:flutter/material.dart';
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
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              children: [
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
                            final routineProvider = context
                                .read<RoutineProvider>();
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
                                      style: TextStyle(color: Colors.redAccent),
                                    ),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await routineProvider.deleteRoutine(routine.id);
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
                  child: Column(
                    children: [
                      _buildTemplateCard(
                        context,
                        template: RoutineTemplates.upperLower,
                        icon: Icons.layers,
                        tag: 'RECOMMENDED • 4 DAYS',
                        isRecommended: true,
                      ),
                      _buildTemplateCard(
                        context,
                        template: RoutineTemplates.pplHybrid,
                        icon: Icons.flash_on,
                        tag: '5 DAYS • PPL + UPPER/LOWER HYBRID',
                        isRecommended: true,
                      ),
                      _buildTemplateCard(
                        context,
                        template: RoutineTemplates.broSplit,
                        icon: Icons.military_tech,
                        tag: '5 DAYS • CLASSIC BODYPART SPLIT',
                      ),
                      _buildTemplateCard(
                        context,
                        template: RoutineTemplates.phul,
                        icon: Icons.bolt,
                        tag: '4 DAYS • POWER & HYPERTROPHY',
                      ),
                      _buildTemplateCard(
                        context,
                        template: RoutineTemplates.torsoLimbs,
                        icon: Icons.sports_gymnastics,
                        tag: '4 DAYS • TORSO & LIMBS',
                      ),
                      _buildTemplateCard(
                        context,
                        template: RoutineTemplates.ppl,
                        icon: Icons.repeat,
                        tag: '6 DAYS • CLASSIC PUSH PULL LEGS',
                      ),
                      _buildTemplateCard(
                        context,
                        template: RoutineTemplates.arnold,
                        icon: Icons.fitness_center,
                        tag: '6 DAYS • CHEST & ARMS FOCUS',
                      ),
                      _buildTemplateCard(
                        context,
                        template: RoutineTemplates.fullBody,
                        icon: Icons.accessibility_new,
                        tag: '3 DAYS • BUSY SCHEDULE',
                      ),
                    ],
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
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ElevatedCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isRecommended
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isRecommended
                    ? AppColors.primary
                    : AppColors.textSecondary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        template.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isRecommended
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      tag,
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
                  const SizedBox(height: 4),
                  Text(
                    '${template.days.length} Days • Balanced Workout',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
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
      ),
    );
  }
}
