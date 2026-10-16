import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/core/theme/app_spacing.dart';
import 'package:fitness_app/core/widgets/elevated_card.dart';
import 'package:fitness_app/core/widgets/primary_button.dart';
import 'package:fitness_app/core/widgets/secondary_button.dart';
import 'package:fitness_app/features/chat/bloc/chat_bloc.dart';
import 'package:fitness_app/features/chat/screens/chat_screen.dart';
import 'package:fitness_app/features/payments/screens/checkout_bottom_sheet.dart';
import 'package:fitness_app/features/trainers/models/trainer_profile.dart';
import 'package:fitness_app/features/trainers/widgets/specialty_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Trainer Profile Detail Screen: shows trainer bio, verified badge, rating,
/// certifications list, specialties chips, hourly rate with platform fee
/// breakdown, and action buttons ("Book Session" and "Message Coach").
class TrainerDetailScreen extends StatelessWidget {
  const TrainerDetailScreen({
    required this.trainer,
    super.key,
    this.displayName,
  });

  final TrainerProfile trainer;
  final String? displayName;

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

  void _onBookSession(BuildContext context, double rate, String trainerName) {
    CheckoutBottomSheet.show(
      context,
      trainer: trainer,
    );
  }

  void _onMessageCoach(BuildContext context, String trainerName) {
    ChatBloc? chatBloc;
    try {
      final b = context.read<ChatBloc>();
      if (!b.isClosed) chatBloc = b;
    } catch (_) {}

    final isTemplate = trainer.id.startsWith('trainer-') ||
        trainer.id.startsWith('mock-') ||
        trainer.userId.startsWith('user-coach-') ||
        trainer.displayName == 'Bob Trainer' ||
        trainer.displayName == 'Charlie Yoga' ||
        trainer.displayName == 'Diana Vance';

    Navigator.push(
      context,
      MaterialPageRoute<dynamic>(
        builder: (context) => ChatScreen(
          conversationId: 'conv_${trainer.id}',
          trainerId: trainer.id,
          trainerUserId: trainer.userId,
          trainerName: trainerName,
          trainerSpecialty: trainer.specialties.isNotEmpty
              ? trainer.specialties.first
              : null,
          chatBloc: chatBloc,
          isTemplateCoach: isTemplate,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = _getDisplayName();
    final initials = _getInitials(name);
    final specialties = trainer.specialties;
    final certs = trainer.certifications;
    final hourlyRate = trainer.hourlyRate;
    final rating = trainer.rating;
    final verified = trainer.verified;

    final platformFee = trainer.platformFeeAmountPerHour;
    final trainerTakeHome = trainer.trainerPayoutPerHour;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF0F172A),
                      Color(0xFF1E293B),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 36),
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: AppColors.coverPull,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                          border: Border.all(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initials,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            name,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (verified) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.verified_rounded,
                              size: 20,
                              color: AppColors.secondaryAccent,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ElevatedCard(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMetric(
                          icon: Icons.star_rounded,
                          iconColor: Colors.amber,
                          value: rating.toStringAsFixed(1),
                          label: 'Rating',
                        ),
                        Container(
                          width: 1,
                          height: 32,
                          color: AppColors.border,
                        ),
                        _buildMetric(
                          icon: Icons.workspace_premium_rounded,
                          iconColor: AppColors.secondaryAccent,
                          value: 'Verified',
                          label: 'Credentials',
                        ),
                        Container(
                          width: 1,
                          height: 32,
                          color: AppColors.border,
                        ),
                        _buildMetric(
                          icon: Icons.bolt_rounded,
                          iconColor: AppColors.primary,
                          value: '₹${hourlyRate.toStringAsFixed(0)}',
                          label: 'Hourly Rate',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'ABOUT COACH',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedCard(
                    child: Text(
                      trainer.bio.isNotEmpty
                          ? trainer.bio
                          : 'Professional fitness coach dedicated to '
                              'customized training and longevity.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.55,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (specialties.isNotEmpty) ...[
                    Text(
                      'SPECIALTIES & EXPERTISE',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: specialties
                          .map((s) => SpecialtyChip(label: s))
                          .toList(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  if (certs.isNotEmpty) ...[
                    Text(
                      'CERTIFICATIONS & CREDENTIALS',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedCard(
                      child: Column(
                        children: certs.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final cert = entry.value;
                          return Column(
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.verified_user_rounded,
                                    color: AppColors.primary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      cert,
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (idx < certs.length - 1)
                                const Divider(
                                  color: AppColors.border,
                                  height: 20,
                                ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  Text(
                    'PRICING & PLATFORM FEE TRANSPARENCY',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFeeRow(
                          label: 'Total Client Rate',
                          value: '₹${hourlyRate.toStringAsFixed(2)} / hr',
                          isBold: true,
                          color: AppColors.textPrimary,
                        ),
                        const Divider(color: AppColors.border, height: 16),
                        _buildFeeRow(
                          label: 'Coach Net Payout (90%)',
                          value: '₹${trainerTakeHome.toStringAsFixed(2)}',
                          isBold: false,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 8),
                        _buildFeeRow(
                          label: 'PulseFit Platform Fee (10%)',
                          value: '₹${platformFee.toStringAsFixed(2)}',
                          isBold: false,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.shield_outlined,
                                size: 18,
                                color: AppColors.secondaryAccent,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'PulseFit maintains 100% transparent fee '
                                  'structures. The 10% platform fee supports '
                                  'encrypted messaging and Razorpay split '
                                  'routing.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 11,
                                    height: 1.4,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.border),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: SecondaryButton(
                  label: 'Message Coach',
                  icon: Icons.chat_bubble_outline_rounded,
                  onPressed: () => _onMessageCoach(context, name),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: PrimaryButton(
                  label: 'Book • ₹${hourlyRate.toStringAsFixed(0)}',
                  icon: Icons.bolt_rounded,
                  onPressed: () => _onBookSession(context, hourlyRate, name),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetric({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildFeeRow({
    required String label,
    required String value,
    required bool isBold,
    required Color color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
