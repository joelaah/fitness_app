import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/core/theme/app_spacing.dart';
import 'package:fitness_app/core/widgets/elevated_card.dart';
import 'package:fitness_app/core/widgets/primary_button.dart';
import 'package:fitness_app/features/auth/screens/auth_upgrade_dialog.dart';
import 'package:fitness_app/features/auth/services/auth_service.dart';
import 'package:fitness_app/features/trainers/models/certification_attachment.dart';
import 'package:fitness_app/features/trainers/models/trainer_profile.dart';
import 'package:fitness_app/features/trainers/services/certification_picker_service.dart';
import 'package:fitness_app/features/trainers/services/trainer_service.dart';
import 'package:fitness_app/features/trainers/services/trainer_storage_service.dart';
import 'package:fitness_app/features/trainers/widgets/certification_attachment_card.dart';
import 'package:fitness_app/features/trainers/widgets/certification_preview_dialog.dart';
import 'package:fitness_app/features/trainers/widgets/specialty_chip.dart';
import 'package:flutter/material.dart';

/// Trainer Registration & Profile Edit Screen:
/// Form to register or edit profile (bio, hourly rate, certs, specialties).
/// Enforces anonymous auth upgrade check before final registration.
class TrainerRegistrationScreen extends StatefulWidget {
  const TrainerRegistrationScreen({
    super.key,
    this.existingProfile,
    this.trainerService,
    this.authService,
    this.storageService,
    this.pickerService,
    this.isAnonymous,
  });

  final TrainerProfile? existingProfile;
  final TrainerService? trainerService;
  final AuthService? authService;
  final TrainerStorageService? storageService;
  final CertificationPickerService? pickerService;
  final bool? isAnonymous;


  @override
  State<TrainerRegistrationScreen> createState() =>
      _TrainerRegistrationScreenState();
}

class _TrainerRegistrationScreenState extends State<TrainerRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _displayNameController;
  late final TextEditingController _bioController;
  late final TextEditingController _rateController;
  late final TextEditingController _experienceController;
  late final TextEditingController _customSpecialtyController;
  late final TextEditingController _certController;

  late final TrainerService _trainerService;
  late final AuthService _authService;
  late final TrainerStorageService _storageService;
  late final CertificationPickerService _pickerService;

  final Set<String> _selectedSpecialties = <String>{};
  final List<String> _certifications = <String>[];
  final List<CertificationAttachment> _attachments =
      <CertificationAttachment>[];
  String? _certInputError;
  bool _isLoading = false;
  bool _isPickingFile = false;
  late final String _sessionFallbackUid;

  String get _effectiveUserId {
    final existingId = widget.existingProfile?.userId;
    if (existingId != null && existingId.isNotEmpty) return existingId;
    final authId = _authService.currentUserId;
    if (authId != null && authId.isNotEmpty) return authId;
    return _sessionFallbackUid;
  }

  static const List<String> _availableSpecialties = <String>[
    'Strength',
    'Hypertrophy',
    'HIIT',
    'Mobility',
    'Powerlifting',
    'Nutrition',
    'Yoga',
    'CrossFit',
    'Functional Fitness',
    'Calisthenics',
  ];

  @override
  void initState() {
    super.initState();
    _sessionFallbackUid = 'user-${DateTime.now().millisecondsSinceEpoch}';
    _trainerService = widget.trainerService ?? TrainerService();
    _authService = widget.authService ?? AuthService();
    _storageService = widget.storageService ?? TrainerStorageService();
    _pickerService = widget.pickerService ?? CertificationPickerService();

    final profile = widget.existingProfile;
    final initialName = profile?.displayName ?? '';

    _displayNameController = TextEditingController(text: initialName);
    _bioController = TextEditingController(text: profile?.bio ?? '');
    final rate = profile?.hourlyRate;
    _rateController = TextEditingController(
      text: rate != null ? rate.toStringAsFixed(0) : '1500',
    );
    final exp = profile?.experienceYears ?? 3;
    _experienceController = TextEditingController(text: exp.toString());
    _customSpecialtyController = TextEditingController();
    _certController = TextEditingController();

    if (profile != null && profile.specialties.isNotEmpty) {
      _selectedSpecialties.addAll(profile.specialties);
    } else {
      _selectedSpecialties.addAll(<String>['Strength', 'Hypertrophy']);
    }

    if (profile != null && profile.certifications.isNotEmpty) {
      var i = 0;
      for (final cert in profile.certifications) {
        if (TrainerProfile.isAttachmentUrl(cert)) {
          _attachments.add(
            CertificationAttachment.fromUrl(
              cert,
              id: 'cert-init-$i-${cert.hashCode}',
            ),
          );
          i++;
        } else {
          _certifications.add(cert);
        }
      }
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _rateController.dispose();
    _experienceController.dispose();
    _customSpecialtyController.dispose();
    _certController.dispose();
    super.dispose();
  }

  bool get _isAnonymousUser => widget.isAnonymous ?? _authService.isAnonymous;

  void _addCustomSpecialty() {
    final text = _customSpecialtyController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _selectedSpecialties.add(text);
        _customSpecialtyController.clear();
      });
    }
  }

  void _addCertification() {
    final text = _certController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _certInputError = 'Please enter a credential name.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a credential name before adding.'),
          backgroundColor: AppColors.warning,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_certifications.any((c) => c.toLowerCase() == text.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This credential has already been added.'),
          backgroundColor: AppColors.warning,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _certifications.add(text);
      _certController.clear();
      _certInputError = null;
    });
  }

  Future<void> _pickAndAttachCertificate() async {
    if (_isPickingFile) return;
    setState(() {
      _isPickingFile = true;
    });
    try {
      final attachment = await _pickerService.pickCertification();
      if (attachment == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to open file picker. Please try again.'),
              backgroundColor: AppColors.error,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      final existingIdx = _attachments.indexWhere(
        (a) => a.name.toLowerCase() == attachment.name.toLowerCase(),
      );
      if (existingIdx >= 0) {
        final existing = _attachments[existingIdx];
        if (existing.error == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('"${attachment.name}" is already attached.'),
                backgroundColor: AppColors.warning,
                duration: const Duration(seconds: 2),
              ),
            );
          }
          return;
        } else {
          setState(() {
            _attachments.removeAt(existingIdx);
          });
        }
      }

      final pendingAttachment = attachment.copyWith(isUploading: true);
      setState(() {
        _attachments.add(pendingAttachment);
      });

      final currentUid = _effectiveUserId;

      if (attachment.bytes != null && attachment.bytes!.isNotEmpty) {
        try {
          final mime = attachment.isPdf
              ? 'application/pdf'
              : (attachment.isImage
                  ? (attachment.extension == 'png'
                      ? 'image/png'
                      : (attachment.extension == 'webp'
                          ? 'image/webp'
                          : 'image/jpeg'))
                  : null);

          final storageUrl = await _storageService.uploadCertification(
            userId: currentUid,
            fileName: attachment.name,
            bytes: attachment.bytes!,
            mimeType: mime,
          );

          if (mounted) {
            final idx = _attachments.indexWhere((a) => a.id == attachment.id);
            if (idx >= 0) {
              setState(() {
                _attachments[idx] = _attachments[idx].copyWith(
                  storageUrl: storageUrl,
                  isUploading: false,
                  error: null,
                );
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Attached "${attachment.name}" successfully!'),
                  backgroundColor: AppColors.success,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          }
        } catch (e) {
          if (mounted) {
            final idx = _attachments.indexWhere((a) => a.id == attachment.id);
            if (idx >= 0) {
              setState(() {
                _attachments[idx] = _attachments[idx].copyWith(
                  isUploading: false,
                  error: 'Upload failed: $e',
                );
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to upload "${attachment.name}": $e'),
                  backgroundColor: AppColors.error,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          }
        }
      } else {
        if (mounted) {
          final idx = _attachments.indexWhere((a) => a.id == attachment.id);
          if (idx >= 0) {
            setState(() {
              _attachments[idx] = _attachments[idx].copyWith(
                isUploading: false,
                error: 'File content is empty or unreadable.',
              );
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text('Unable to read content from "${attachment.name}".'),
                backgroundColor: AppColors.error,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open file picker. Please try again.'),
            backgroundColor: AppColors.error,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPickingFile = false;
        });
      } else {
        _isPickingFile = false;
      }
    }
  }

  void _removeAttachment(CertificationAttachment attachment) {
    setState(() {
      _attachments.removeWhere((a) => a.id == attachment.id);
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed "${attachment.name}".'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _previewAttachment(CertificationAttachment attachment) {
    CertificationPreviewDialog.show(
      context,
      attachment: attachment,
      onRemove: () => _removeAttachment(attachment),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSpecialties.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one coaching specialty.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_attachments.any((a) => a.isUploading)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Please wait for file upload to complete before saving.'),
          backgroundColor: AppColors.warning,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_attachments.any((a) => a.error != null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please remove failed attachments before saving.'),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_attachments.any((a) => a.storageUrl == null || a.storageUrl!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for all attachments to finish uploading.'),
          backgroundColor: AppColors.warning,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_isAnonymousUser) {
      await _showUpgradePrompt();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final bio = _bioController.text.trim();
      final rate = double.parse(_rateController.text.trim());
      final exp = int.tryParse(_experienceController.text.trim()) ?? 0;
      final displayName = _displayNameController.text.trim();

      final List<String> allCertifications = <String>[
        ..._certifications,
        ..._attachments
            .map((a) => a.storageUrl)
            .whereType<String>()
            .where((url) => url.isNotEmpty),
      ];

      if (widget.existingProfile != null) {
        final existing = widget.existingProfile!;
        await _trainerService.updateTrainerProfile(
          existing.userId,
          displayName: displayName.isNotEmpty ? displayName : null,
          bio: bio,
          certifications: allCertifications,
          specialties: _selectedSpecialties.toList(),
          experienceYears: exp,
          hourlyRate: rate,
        );
      } else {
        final currentUid = _effectiveUserId;
        await _trainerService.registerTrainer(
          userId: currentUid,
          displayName: displayName.isNotEmpty ? displayName : 'Coach',
          bio: bio,
          certifications: allCertifications,
          specialties: _selectedSpecialties.toList(),
          experienceYears: exp,
          hourlyRate: rate,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Coach profile saved successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }


  Future<void> _showUpgradePrompt() async {
    final upgraded = await AuthUpgradeDialog.show(
      context,
      authService: _authService,
    );
    if (upgraded && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Account upgraded! You may now publish your coach profile.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.existingProfile != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Coach Profile' : 'Become a Coach'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isAnonymousUser) ...[
                ElevatedCard(
                  color: AppColors.surfaceElevated,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.warning,
                        size: 28,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Anonymous Session Detected',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: AppColors.warning,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'You must upgrade to a permanent account.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: _showUpgradePrompt,
                        child: const Text('Upgrade'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              Text(
                'COACH DISPLAY NAME',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _displayNameController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'e.g. Alex Mercer, CSCS',
                  prefixIcon: Icon(
                    Icons.person_outline,
                    color: AppColors.textSecondary,
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter your display name.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'COACH BIO & PHILOSOPHY',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _bioController,
                maxLines: 4,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Describe your coaching style and results...',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a bio for prospective clients.';
                  }
                  if (val.trim().length < 20) {
                    return 'Bio must be at least 20 characters.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'HOURLY RATE & PAYOUT PREVIEW',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _rateController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
                decoration: const InputDecoration(
                  prefixText: '₹ ',
                  suffixText: '/ hour',
                  hintText: '1500',
                ),
                onChanged: (_) => setState(() {}),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter your hourly rate.';
                  }
                  final parsed = double.tryParse(val.trim());
                  if (parsed == null || parsed < 0) {
                    return 'Please enter a valid rate >= 0.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final entered =
                      double.tryParse(_rateController.text.trim()) ?? 0.0;
                  final fee = entered * 0.10;
                  final payout = entered - fee;
                  return Text(
                    'Client pays: ₹${entered.toStringAsFixed(0)}  •  '
                    'Take-home (90%): ₹${payout.toStringAsFixed(0)}  •  '
                    'PulseFit Fee (10%): ₹${fee.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'YEARS OF EXPERIENCE',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _experienceController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'e.g. 5',
                  suffixText: 'years',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter your experience.';
                  }
                  final parsed = int.tryParse(val.trim());
                  if (parsed == null || parsed < 0) {
                    return 'Please enter a valid number >= 0.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'COACHING SPECIALTIES',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableSpecialties.map((spec) {
                  final isSelected = _selectedSpecialties.contains(spec);
                  return SpecialtyChip(
                    label: spec,
                    isInteractive: true,
                    isSelected: isSelected,
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedSpecialties.remove(spec);
                        } else {
                          _selectedSpecialties.add(spec);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customSpecialtyController,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Add custom specialty...',
                        isDense: true,
                      ),
                      onSubmitted: (_) => _addCustomSpecialty(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.add_circle,
                      color: AppColors.primary,
                      size: 28,
                    ),
                    onPressed: _addCustomSpecialty,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'CERTIFICATIONS & CREDENTIALS',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Add credential titles (e.g. CSCS) or upload certificate files (PDF, PNG, JPEG).',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              if (_certifications.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _certifications.map((cert) {
                    return SpecialtyChip(
                      label: cert,
                      icon: Icons.workspace_premium_rounded,
                      isInteractive: true,
                      isSelected: true,
                      onDeleted: () {
                        setState(() {
                          _certifications.remove(cert);
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],
              if (_attachments.isNotEmpty) ...[
                Column(
                  children: _attachments.map((attachment) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: CertificationAttachmentCard(
                        attachment: attachment,
                        onPreview: () => _previewAttachment(attachment),
                        onRemove: () => _removeAttachment(attachment),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('certification_text_input'),
                      controller: _certController,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'e.g. CSCS, NASM-CPT, RYT-500...',
                        isDense: true,
                        errorText: _certInputError,
                      ),
                      onChanged: (_) {
                        if (_certInputError != null) {
                          setState(() {
                            _certInputError = null;
                          });
                        }
                      },
                      onSubmitted: (_) => _addCertification(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    key: const Key('add_certification_button'),
                    icon: const Icon(
                      Icons.add_circle,
                      color: AppColors.primary,
                      size: 28,
                    ),
                    tooltip: 'Add credential title',
                    onPressed: _addCertification,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: const Key('upload_certificate_button'),
                icon: const Icon(Icons.upload_file_rounded, size: 20),
                label: const Text('Upload Certificate / Document'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _isPickingFile ? null : _pickAndAttachCertificate,
              ),

              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: isEditing
                    ? 'Update Coach Profile'
                    : 'Complete Coach Registration',
                isLoading: _isLoading,
                onPressed: _submit,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
