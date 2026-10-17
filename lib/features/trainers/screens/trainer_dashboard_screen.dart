import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/core/theme/app_spacing.dart';
import 'package:fitness_app/core/widgets/elevated_card.dart';
import 'package:fitness_app/core/widgets/primary_button.dart';
import 'package:fitness_app/core/widgets/secondary_button.dart';
import 'package:fitness_app/features/auth/services/auth_service.dart';
import 'package:fitness_app/features/payments/screens/payment_history_screen.dart';
import 'package:fitness_app/features/trainers/models/trainer_profile.dart';
import 'package:fitness_app/features/trainers/screens/trainer_detail_screen.dart';
import 'package:fitness_app/features/trainers/screens/trainer_discovery_screen.dart';
import 'package:fitness_app/features/trainers/screens/trainer_registration_screen.dart';
import 'package:fitness_app/features/trainers/services/certification_picker_service.dart';
import 'package:fitness_app/features/trainers/services/trainer_service.dart';
import 'package:fitness_app/features/trainers/services/trainer_storage_service.dart';
import 'package:flutter/material.dart';

/// Trainer Dashboard Screen:
/// Trainer's personal view showing their hourly rate, 10% platform fee
/// transparency, client statistics, and profile edit action.
class TrainerDashboardScreen extends StatefulWidget {
  const TrainerDashboardScreen({
    super.key,
    this.trainerProfile,
    this.trainerService,
    this.authService,
    this.storageService,
    this.pickerService,
  });

  final TrainerProfile? trainerProfile;
  final TrainerService? trainerService;
  final AuthService? authService;
  final TrainerStorageService? storageService;
  final CertificationPickerService? pickerService;

  @override
  State<TrainerDashboardScreen> createState() => _TrainerDashboardScreenState();
}

class _TrainerDashboardScreenState extends State<TrainerDashboardScreen> {
  TrainerProfile? _profile;
  late final TrainerService _trainerService;
  late final AuthService _authService;
  late final TrainerStorageService _storageService;
  late final CertificationPickerService _pickerService;
  bool _acceptingClients = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _trainerService = widget.trainerService ?? TrainerService();
    _authService = widget.authService ?? AuthService();
    _storageService = widget.storageService ?? TrainerStorageService();
    _pickerService = widget.pickerService ?? const CertificationPickerService();

    if (widget.trainerProfile != null && !_authService.isAnonymous) {
      _profile = widget.trainerProfile;
    } else {
      _loadDashboardProfile();
    }
  }

  Future<void> _loadDashboardProfile() async {
    setState(() => _isLoading = true);
    try {
      if (_authService.isAnonymous) {
        _profile = null;
      } else {
        final myProfile = await _trainerService.getMyTrainerProfile();
        _profile = myProfile;
      }
    } catch (e) {
      debugPrint('TrainerDashboardScreen error loading profile: $e');
      _profile = null;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _returnToCoaches(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<dynamic>(
          builder: (context) => TrainerDiscoveryScreen(
            trainerService: _trainerService,
          ),
        ),
      );
    }
  }

  Widget _buildAccessRestrictedView(BuildContext context, ThemeData theme) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trainer Dashboard'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Return to Coaches',
          onPressed: () => _returnToCoaches(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xl,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.lock_person_rounded,
                    size: 40,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Access Restricted: Coaches Only',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'The Trainer Dashboard contains private coach analytics, session '
                  'rate configurations, net payout telemetry, and client rosters. '
                  'This space is exclusively accessible to verified, registered coaches.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Are you a certified fitness professional? Register your coaching '
                  'credentials to showcase your expertise and start taking clients.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: 'Register as a Coach',
                  icon: Icons.person_add_rounded,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<dynamic>(
                        builder: (context) => TrainerRegistrationScreen(
                          trainerService: _trainerService,
                          authService: _authService,
                          storageService: _storageService,
                          pickerService: _pickerService,
                        ),
                      ),
                    ).then((_) => _loadDashboardProfile());
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                SecondaryButton(
                  label: 'Return to Coaches',
                  icon: Icons.arrow_back_rounded,
                  onPressed: () => _returnToCoaches(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Trainer Dashboard')),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      );
    }

    if (_profile == null) {
      return _buildAccessRestrictedView(context, theme);
    }

    final profile = _profile!;
    final hourlyRate = profile.hourlyRate;
    final platformFee = profile.platformFeeAmountPerHour;
    final netEarnings = profile.trainerPayoutPerHour;
    final displayName = profile.displayName ?? 'Coach';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trainer Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded),
            tooltip: 'Edit Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<dynamic>(
                  builder: (context) => TrainerRegistrationScreen(
                    existingProfile: profile,
                    trainerService: _trainerService,
                    authService: _authService,
                    storageService: _storageService,
                    pickerService: _pickerService,
                  ),
                ),
              ).then((_) => _loadDashboardProfile());
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedCard(
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
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
                      displayName.isNotEmpty
                          ? displayName.substring(0, 2).toUpperCase()
                          : 'PT',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                displayName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.verified_rounded,
                              size: 16,
                              color: AppColors.secondaryAccent,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Marketplace: '
                          '${_acceptingClients ? "Active" : "Paused"}',
                          style: TextStyle(
                            color: _acceptingClients
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _acceptingClients,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      setState(() {
                        _acceptingClients = val;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'SESSION RATE & FEE BREAKDOWN',
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedCard(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Hourly Booking Rate',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '₹${hourlyRate.toStringAsFixed(0)} / session',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: AppColors.border, height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Your Net Payout (90%)',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₹${netEarnings.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'PulseFit Cut (10%)',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₹${platformFee.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'PulseFit deducts a 10% platform fee automatically '
                    'via Razorpay Route split transfers.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'COACH PERFORMANCE',
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    title: 'Active Clients',
                    value: '4',
                    icon: Icons.people_alt_rounded,
                    iconColor: AppColors.secondaryAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    title: 'Sessions Held',
                    value: '32',
                    icon: Icons.fitness_center_rounded,
                    iconColor: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    title: 'Average Rating',
                    value: '4.95 ★',
                    icon: Icons.star_rounded,
                    iconColor: Colors.amber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: 'View Payout & Earnings History',
              icon: Icons.receipt_long_rounded,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<dynamic>(
                    builder: (context) => const PaymentHistoryScreen(
                      isTrainerMode: true,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            SecondaryButton(
              label: 'Preview Public Profile',
              icon: Icons.visibility_outlined,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<dynamic>(
                    builder: (context) => TrainerDetailScreen(
                      trainer: profile,
                      displayName: displayName,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return ElevatedCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
