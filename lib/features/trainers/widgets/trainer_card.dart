import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/core/theme/app_spacing.dart';
import 'package:fitness_app/core/widgets/elevated_card.dart';
import 'package:fitness_app/core/widgets/perspective_tilt_card.dart';
import 'package:fitness_app/features/trainers/models/trainer_profile.dart';
import 'package:fitness_app/features/trainers/screens/trainer_detail_screen.dart';
import 'package:fitness_app/features/trainers/widgets/specialty_chip.dart';
import 'package:flutter/material.dart';

/// Trainer card widget rendered in Trainer Discovery browsing lists.
class TrainerCard extends StatelessWidget {
  const TrainerCard({
    required this.trainer,
    super.key,
    this.displayName,
    this.onTap,
  });

  final TrainerProfile trainer;
  final String? displayName;
  final VoidCallback? onTap;

  String _getDisplayName() {
    if (displayName != null && displayName!.isNotEmpty) {
      return displayName!;
    }
    if (trainer.displayName != null && trainer.displayName!.isNotEmpty) {
      return trainer.displayName!;
    }
    final idStr = trainer.id;
    final suffix = idStr.length >= 4 ? idStr.substring(0, 4) : idStr;
    return 'Coach ${suffix.toUpperCase()}';
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty
        ? name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase()
        : 'PT';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = _getDisplayName();
    final initials = _getInitials(name);
    final specialties = trainer.specialties;
    final hourlyRate = trainer.hourlyRate;
    final rating = trainer.rating;
    final verified = trainer.verified;

    final card = ElevatedCard(
      onTap: onTap ??
            () {
              Navigator.push(
                context,
                MaterialPageRoute<dynamic>(
                  builder: (context) => TrainerDetailScreen(
                    trainer: trainer,
                    displayName: name,
                  ),
                ),
              );
            },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Avatar + Name + Rating + Verified Badge
            Row(
              children: [
                // Gradient Avatar with Initials
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: AppColors.coverPull,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),

                // Name & Rating Section
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (verified) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.verified_rounded,
                              size: 16,
                              color: AppColors.secondaryAccent,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            rating.toStringAsFixed(1),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            '•',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Verified Coach',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Hourly Rate Highlight
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${hourlyRate.toStringAsFixed(0)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      '/ hour',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Bio Preview
            if (trainer.bio.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                trainer.bio,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Specialties Row & Navigation Cue
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      ...specialties.take(3).map(
                            (s) => SpecialtyChip(label: s),
                          ),
                      if (specialties.length > 3)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '+${specialties.length - 3}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ],
        ),
      );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PerspectiveTiltCard(
        borderRadius: 20,
        elevation: 2.0,
        child: card,
      ),
    );
  }
}
