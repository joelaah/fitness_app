import 'dart:async';

import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/core/widgets/primary_button.dart';
import 'package:fitness_app/features/auth/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthUpgradeDialog extends StatefulWidget {
  const AuthUpgradeDialog({
    super.key,
    this.authService,
    this.onGoogleSignIn,
    this.onAppleSignIn,
    this.onEmailSubmit,
    this.onEmailPasswordPressed,
  });

  final AuthService? authService;
  final Future<bool> Function()? onGoogleSignIn;
  final Future<bool> Function()? onAppleSignIn;
  final Future<void> Function(String email, String password, String name)?
      onEmailSubmit;
  final VoidCallback? onEmailPasswordPressed;

  /// Static helper to launch dialog and return whether user upgraded or
  /// signed in.
  static Future<bool> show(
    BuildContext context, {
    AuthService? authService,
    Future<bool> Function()? onGoogleSignIn,
    Future<bool> Function()? onAppleSignIn,
    Future<void> Function(String email, String password, String name)?
        onEmailSubmit,
    VoidCallback? onEmailPasswordPressed,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AuthUpgradeDialog(
        authService: authService,
        onGoogleSignIn: onGoogleSignIn,
        onAppleSignIn: onAppleSignIn,
        onEmailSubmit: onEmailSubmit,
        onEmailPasswordPressed: onEmailPasswordPressed,
      ),
    );
    return result ?? false;
  }

  @override
  State<AuthUpgradeDialog> createState() => _AuthUpgradeDialogState();
}

class _AuthUpgradeDialogState extends State<AuthUpgradeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late final AuthService _authService;
  bool _isSignInMode = false;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  bool get _isOAuthLoading => _isGoogleLoading || _isAppleLoading;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _startTimer();
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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _formatTtlRemaining() {
    final remaining = _authService.guestTimeRemaining;
    if (remaining == null) return '2-hour retention window';
    if (remaining == Duration.zero) return 'Session expired (0m remaining)';
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    if (hours > 0) {
      return minutes > 0
          ? '$hours hr $minutes min remaining'
          : '$hours hr remaining';
    }
    if (minutes > 0) {
      return '$minutes min remaining';
    }
    return '< 1 min remaining';
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });

    try {
      bool success = false;
      if (widget.onGoogleSignIn != null) {
        success = await widget.onGoogleSignIn!();
      } else {
        success = await _authService.signInWithOAuth(OAuthProvider.google);
      }

      if (mounted) {
        if (success) {
          Navigator.of(context).pop(true);
        } else {
          setState(() {
            _errorMessage =
                'Authentication could not be completed. Please try again.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('AuthException: ', '');
        });
      }
    } finally {
      if (mounted && _isGoogleLoading) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() {
      _isAppleLoading = true;
      _errorMessage = null;
    });

    try {
      bool success = false;
      if (widget.onAppleSignIn != null) {
        success = await widget.onAppleSignIn!();
      } else {
        success = await _authService.signInWithOAuth(OAuthProvider.apple);
      }

      if (mounted) {
        if (success) {
          Navigator.of(context).pop(true);
        } else {
          setState(() {
            _errorMessage =
                'Authentication could not be completed. Please try again.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('AuthException: ', '');
        });
      }
    } finally {
      if (mounted && _isAppleLoading) {
        setState(() => _isAppleLoading = false);
      }
    }
  }

  Future<void> _handleSubmit() async {
    widget.onEmailPasswordPressed?.call();

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final name = _nameController.text.trim();

      if (widget.onEmailSubmit != null) {
        await widget.onEmailSubmit!(email, password, name);
      } else if (_isSignInMode) {
        await _authService.signInWithEmail(email: email, password: password);
      } else {
        await _authService.upgradeAnonymousUser(
          email: email,
          password: password,
          displayName: name.isNotEmpty ? name : 'Coach',
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('AuthException: ', '');
        });
      }
    } finally {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _isLoading || _isOAuthLoading;

    return PopScope(
      canPop: !isBusy,
      child: Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.border),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Header Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(30),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: AppColors.primary.withAlpha(80)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.verified_user_rounded,
                              size: 13,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'ACCOUNT UPGRADE',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                        onPressed:
                            isBusy ? null : () => Navigator.of(context).pop(false),
                      ),
                    ],
                  ),
                const SizedBox(height: 10),

                // Dialog Title
                Text(
                  _isSignInMode
                      ? 'Sign In to Account'
                      : 'Save Your Workout History',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isSignInMode
                      ? 'Welcome back! Sign in to manage your workout profile.'
                      : 'Anonymous guest accounts are temporary. Upgrade to '
                          'permanently preserve your routines, logs, and progress.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),

                // 2-Hour TTL / Expiration Warning Card
                Builder(
                  builder: (context) {
                    final isExpired = _authService.isGuestExpired;
                    final ttlColor = isExpired ? AppColors.error : AppColors.warning;
                    final ttlIcon = isExpired ? Icons.error_outline : Icons.timer_outlined;

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: ttlColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ttlColor.withAlpha(90)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            ttlIcon,
                            color: ttlColor,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isExpired
                                      ? 'Guest Session Expired'
                                      : '2-Hour Auto-Expiration Policy',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: ttlColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isExpired
                                      ? 'Your guest session has expired. Upgrade now to preserve your progress. Status: ${_formatTtlRemaining()}.'
                                      : 'Guest data auto-expires in 2 hours unless linked '
                                          'to a verified account. Status: ${_formatTtlRemaining()}.',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppColors.textPrimary.withAlpha(220),
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Error Message (if any)
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.error.withAlpha(80)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.error,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 1. Continue with Google Button
                OutlinedButton(
                  key: const Key('upgrade_continue_with_google'),
                  onPressed:
                      (_isLoading || _isOAuthLoading) ? null : _handleGoogleSignIn,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    backgroundColor: AppColors.surfaceElevated,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isGoogleLoading) ...[
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ] else ...[
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'G',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueAccent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Text(
                        'Continue with Google',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // 2. Continue with Apple Button
                OutlinedButton(
                  key: const Key('upgrade_continue_with_apple'),
                  onPressed:
                      (_isLoading || _isOAuthLoading) ? null : _handleAppleSignIn,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    backgroundColor: AppColors.surfaceElevated,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isAppleLoading) ...[
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ] else ...[
                        const Icon(
                          Icons.apple,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                      ],
                      Text(
                        'Continue with Apple',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Divider: Or Email & Password
                Row(
                  children: [
                    const Expanded(
                      child: Divider(color: AppColors.border, thickness: 1),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'OR WITH EMAIL',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Divider(color: AppColors.border, thickness: 1),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Name Field (only in upgrade mode)
                if (!_isSignInMode) ...[
                  Text(
                    'Full Name / Coach Title',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameController,
                    enabled: !isBusy,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    textInputAction: TextInputAction.next,
                    style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. Alex Mercer',
                      prefixIcon: const Icon(
                        Icons.person_outline,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Please enter your name'
                        : null,
                  ),
                  const SizedBox(height: 14),
                ],

                // Email Address Field
                Text(
                  'Email Address',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _emailController,
                  enabled: !isBusy,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'coach@example.com',
                    prefixIcon: const Icon(
                      Icons.email_outlined,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                    if (!emailRegex.hasMatch(v.trim())) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Password Field
                Text(
                  'Password',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _passwordController,
                  enabled: !isBusy,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => isBusy ? null : _handleSubmit(),
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Minimum 6 characters',
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      onPressed: isBusy
                          ? null
                          : () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter a password';
                    }
                    if (v.trim().length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // 3. Continue with Email & Password Button
                PrimaryButton(
                  key: const Key('upgrade_continue_with_email'),
                  label: _isSignInMode
                      ? 'Sign In with Email'
                      : 'Continue with Email & Password',
                  isLoading: _isLoading,
                  icon: _isSignInMode ? Icons.login : Icons.arrow_forward,
                  onPressed:
                      (_isLoading || _isOAuthLoading) ? null : _handleSubmit,
                ),
                const SizedBox(height: 12),

                // Switch Sign In / Upgrade Mode
                TextButton(
                  onPressed: (_isLoading || _isOAuthLoading)
                      ? null
                      : () {
                          setState(() {
                            _isSignInMode = !_isSignInMode;
                            _errorMessage = null;
                          });
                        },
                  child: Text(
                    _isSignInMode
                        ? "Don't have an account? Upgrade anonymous guest"
                        : 'Already have a registered account? Sign In',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
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
