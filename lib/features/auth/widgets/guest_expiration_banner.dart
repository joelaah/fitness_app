import 'dart:async';

import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/features/auth/screens/auth_upgrade_dialog.dart';
import 'package:fitness_app/features/auth/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GuestExpirationBanner extends StatefulWidget {
  const GuestExpirationBanner({
    super.key,
    this.authService,
    this.onUpgradeTap,
  });

  final AuthService? authService;
  final VoidCallback? onUpgradeTap;

  @override
  State<GuestExpirationBanner> createState() => _GuestExpirationBannerState();
}

class _GuestExpirationBannerState extends State<GuestExpirationBanner> {
  late AuthService _authService;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _startTimer();
  }

  @override
  void didUpdateWidget(GuestExpirationBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.authService != oldWidget.authService) {
      _authService = widget.authService ?? AuthService();
    }
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _formatRemaining() {
    final remaining = _authService.guestTimeRemaining;
    if (remaining == null) return '2 hours';
    if (remaining == Duration.zero) return 'Expired';
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    if (hours > 0) {
      return minutes > 0 ? '$hours hr $minutes min' : '$hours hr';
    }
    if (minutes > 0) {
      return '$minutes min';
    }
    return '< 1 min';
  }

  Future<void> _handleUpgrade() async {
    if (widget.onUpgradeTap != null) {
      widget.onUpgradeTap!();
      return;
    }
    final upgraded = await AuthUpgradeDialog.show(
      context,
      authService: _authService,
    );
    if (upgraded == true && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_authService.isAnonymous || _authService.guestExpirationTime == null) {
      return const SizedBox.shrink();
    }

    final isExpired = _authService.isGuestExpired;
    final bannerColor = isExpired ? AppColors.error : AppColors.warning;

    return Container(
      key: const Key('guest_expiration_banner'),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: bannerColor.withAlpha(120),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bannerColor.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isExpired ? Icons.error_outline : Icons.hourglass_top_rounded,
              color: bannerColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        isExpired
                            ? 'Guest Session Expired'
                            : 'Guest Session Expiring',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: bannerColor.withAlpha(40),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _formatRemaining(),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: bannerColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isExpired
                      ? 'Your temporary guest data has expired. Save your account now to preserve remaining data.'
                      : 'Your workout history will expire in 2 hours unless you save your account.',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            key: const Key('guest_expiration_banner_action'),
            onPressed: _handleUpgrade,
            style: TextButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.background,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Save Account',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.background,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
