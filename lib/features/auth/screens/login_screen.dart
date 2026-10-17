import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/core/widgets/primary_button.dart';
import 'package:fitness_app/features/auth/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.authService,
    this.onGoogleSignIn,
    this.onAppleSignIn,
    this.onEmailSubmit,
    this.isSignUpInitial = false,
  });

  final AuthService? authService;
  final Future<bool> Function()? onGoogleSignIn;
  final Future<bool> Function()? onAppleSignIn;
  final Future<void> Function(
    String email,
    String password,
    String name,
    bool isSignUp,
  )? onEmailSubmit;
  final bool isSignUpInitial;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late final AuthService _authService;
  late bool _isSignUp;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  bool get _isOAuthLoading => _isGoogleLoading || _isAppleLoading;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _isSignUp = widget.isSignUpInitial;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
            _errorMessage = 'Google authentication was not completed.';
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
            _errorMessage = 'Apple authentication was not completed.';
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
        await widget.onEmailSubmit!(email, password, name, _isSignUp);
      } else if (_isSignUp) {
        if (_authService.isAnonymous) {
          await _authService.upgradeAnonymousUser(
            email: email,
            password: password,
            displayName: name.isNotEmpty ? name : 'Athlete',
          );
        } else {
          await _authService.signUpWithEmail(
            email: email,
            password: password,
            displayName: name.isNotEmpty ? name : 'Athlete',
          );
        }
      } else {
        await _authService.signInWithEmail(
          email: email,
          password: password,
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(
          color: AppColors.textPrimary,
          onPressed: isBusy ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Brand Header
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(25),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary.withAlpha(80)),
                      ),
                      child: const Icon(
                        Icons.bolt_rounded,
                        color: AppColors.primary,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'PulseFit AI',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isSignUp
                        ? 'Create your account to permanently save your workout history'
                        : 'Sign in to access your workouts, routines, and AI coach',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Surface Card
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _isSignUp ? 'Create Account' : 'Welcome Back',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),

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
                                  const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.error),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Continue with Google
                          OutlinedButton(
                            key: const Key('login_continue_with_google'),
                            onPressed: isBusy ? null : _handleGoogleSignIn,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              backgroundColor: AppColors.surfaceElevated,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_isGoogleLoading) ...[
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
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

                          // Continue with Apple
                          OutlinedButton(
                            key: const Key('login_continue_with_apple'),
                            onPressed: isBusy ? null : _handleAppleSignIn,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              backgroundColor: AppColors.surfaceElevated,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_isAppleLoading) ...[
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  ),
                                  const SizedBox(width: 10),
                                ] else ...[
                                  const Icon(Icons.apple, color: Colors.white, size: 20),
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

                          Row(
                            children: [
                              const Expanded(child: Divider(color: AppColors.border, thickness: 1)),
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
                              const Expanded(child: Divider(color: AppColors.border, thickness: 1)),
                            ],
                          ),
                          const SizedBox(height: 16),

                          if (_isSignUp) ...[
                            Text(
                              'Full Name',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _nameController,
                              enabled: !isBusy,
                              autovalidateMode: AutovalidateMode.onUserInteraction,
                              style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'e.g. Alex Mercer',
                                prefixIcon: const Icon(Icons.person_outline, color: AppColors.textSecondary, size: 20),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary)),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your name' : null,
                            ),
                            const SizedBox(height: 14),
                          ],

                          Text(
                            'Email Address',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _emailController,
                            enabled: !isBusy,
                            keyboardType: TextInputType.emailAddress,
                            autovalidateMode: AutovalidateMode.onUserInteraction,
                            style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'you@example.com',
                              prefixIcon: const Icon(Icons.email_outlined, color: AppColors.textSecondary, size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary)),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Please enter your email';
                              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) return 'Enter a valid email';
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          Text(
                            'Password',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _passwordController,
                            enabled: !isBusy,
                            obscureText: _obscurePassword,
                            autovalidateMode: AutovalidateMode.onUserInteraction,
                            onFieldSubmitted: (_) => isBusy ? null : _handleSubmit(),
                            style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Minimum 6 characters',
                              prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textSecondary, size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: AppColors.textSecondary, size: 20),
                                onPressed: isBusy ? null : () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary)),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Please enter a password';
                              if (v.trim().length < 6) return 'Password must be at least 6 characters';
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          PrimaryButton(
                            key: const Key('login_submit_button'),
                            label: _isSignUp ? 'Create Account' : 'Sign In',
                            isLoading: _isLoading,
                            icon: _isSignUp ? Icons.arrow_forward : Icons.login,
                            onPressed: isBusy ? null : _handleSubmit,
                          ),
                          const SizedBox(height: 14),

                          TextButton(
                            onPressed: isBusy
                                ? null
                                : () => setState(() {
                                      _isSignUp = !_isSignUp;
                                      _errorMessage = null;
                                    }),
                            child: Text(
                              _isSignUp
                                  ? 'Already have an account? Sign In'
                                  : "Don't have an account? Sign Up",
                              style: GoogleFonts.inter(
                                fontSize: 13,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
