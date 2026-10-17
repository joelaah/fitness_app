import 'dart:async';
import 'dart:typed_data';

import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/features/auth/services/auth_service.dart';
import 'package:fitness_app/features/trainers/models/certification_attachment.dart';
import 'package:fitness_app/features/trainers/models/trainer_profile.dart';
import 'package:fitness_app/features/trainers/screens/trainer_registration_screen.dart';
import 'package:fitness_app/features/trainers/services/certification_picker_service.dart';
import 'package:fitness_app/features/trainers/services/trainer_service.dart';
import 'package:fitness_app/features/trainers/services/trainer_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockTrainerService extends TrainerService {
  @override
  Future<TrainerProfile> registerTrainer({
    required String bio,
    required List<String> certifications,
    required List<String> specialties,
    required int experienceYears,
    required double hourlyRate,
    String? userId,
    String? displayName,
    Map<String, dynamic>? availability,
  }) async {
    return TrainerProfile(
      id: 'mock-reg-1',
      userId: userId ?? 'mock-user-1',
      displayName: displayName ?? 'Coach Test',
      bio: bio,
      certifications: certifications,
      specialties: specialties,
      experienceYears: experienceYears,
      hourlyRate: hourlyRate,
    );
  }
}

class _MockAuthService extends AuthService {
  @override
  String? get currentUserId => 'mock-user-123';

  @override
  bool get isAnonymous => false;
}

class _MockStorageService extends TrainerStorageService {
  @override
  Future<String> uploadCertification({
    required String userId,
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
  }) async {
    return 'https://supabase.pulsefit.io/storage/v1/object/public/trainer-certifications/$userId/$fileName';
  }
}

class _AdversarialPickerService extends CertificationPickerService {
  _AdversarialPickerService({
    this.pickerCompleter,
    this.attachmentToReturn,
    this.shouldThrow = false,
  });

  Completer<CertificationAttachment?>? pickerCompleter;
  CertificationAttachment? attachmentToReturn;
  bool shouldThrow;
  int callCount = 0;

  @override
  Future<CertificationAttachment?> pickCertification() async {
    callCount++;
    if (shouldThrow) {
      throw Exception('Simulated OS FilePicker crash');
    }
    if (pickerCompleter != null) {
      return pickerCompleter!.future;
    }
    return attachmentToReturn;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildScreen({CertificationPickerService? pickerService}) {
    return MaterialApp(
      home: TrainerRegistrationScreen(
        trainerService: _MockTrainerService(),
        authService: _MockAuthService(),
        storageService: _MockStorageService(),
        pickerService: pickerService,
      ),
    );
  }

  group('Bug 1 Empirical Challenger: Upload Button State Machine & Attachments', () {
    testWidgets(
      'empirical_challenge_double_tap_picker_prevents_concurrent_invocations',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final completer = Completer<CertificationAttachment?>();
        final picker = _AdversarialPickerService(pickerCompleter: completer);

        await tester.pumpWidget(buildScreen(pickerService: picker));
        await tester.pumpAndSettle();

        final uploadBtnFinder = find.byKey(const Key('upload_certificate_button'));
        expect(uploadBtnFinder, findsOneWidget);
        await tester.ensureVisible(uploadBtnFinder);

        // Initially enabled
        var button = tester.widget<OutlinedButton>(uploadBtnFinder);
        expect(button.onPressed, isNotNull);
        expect(picker.callCount, 0);

        // Tap 1: starts pick operation
        await tester.tap(uploadBtnFinder);
        await tester.pump(); // trigger setState(_isPickingFile = true)

        expect(picker.callCount, 1);
        button = tester.widget<OutlinedButton>(uploadBtnFinder);
        expect(button.onPressed, isNull, reason: 'Button must be disabled during active pick');

        // Tap 2, 3 while picker is pending: should NOT trigger new picks
        await tester.tap(uploadBtnFinder, warnIfMissed: false);
        await tester.pump();
        await tester.tap(uploadBtnFinder, warnIfMissed: false);
        await tester.pump();

        expect(picker.callCount, 1, reason: 'Concurrent taps must not invoke pickCertification multiple times');

        // Complete the in-flight picker call
        completer.complete(null);
        await tester.pumpAndSettle();

        // Button is re-enabled and error snackbar shown
        button = tester.widget<OutlinedButton>(uploadBtnFinder);
        expect(button.onPressed, isNotNull, reason: 'Button must re-enable after picker completes');
        expect(picker.callCount, 1);

        // Subsequent single tap after completion increments call count
        final completer2 = Completer<CertificationAttachment?>();
        picker.pickerCompleter = completer2;
        await tester.tap(uploadBtnFinder);
        await tester.pump();

        expect(picker.callCount, 2, reason: 'Next tap after completion should work normally');
        completer2.complete(null);
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'empirical_challenge_upload_button_shows_error_snackbar_on_null_and_recovers',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final picker = _AdversarialPickerService(attachmentToReturn: null);

        await tester.pumpWidget(buildScreen(pickerService: picker));
        await tester.pumpAndSettle();

        final uploadBtnFinder = find.byKey(const Key('upload_certificate_button'));
        await tester.ensureVisible(uploadBtnFinder);
        await tester.tap(uploadBtnFinder);
        await tester.pump(); // Render SnackBar

        final snackBarFinder = find.byType(SnackBar);
        expect(snackBarFinder, findsOneWidget);
        final snackBar = tester.widget<SnackBar>(snackBarFinder);
        expect(snackBar.backgroundColor, equals(AppColors.error));
        expect(
          find.text('Unable to open file picker. Please try again.'),
          findsOneWidget,
        );

        await tester.pumpAndSettle();
        final button = tester.widget<OutlinedButton>(uploadBtnFinder);
        expect(button.onPressed, isNotNull, reason: 'Button must be re-enabled after null return');
      },
    );

    testWidgets(
      'empirical_challenge_upload_button_shows_error_snackbar_on_exception_and_recovers',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final picker = _AdversarialPickerService(shouldThrow: true);

        await tester.pumpWidget(buildScreen(pickerService: picker));
        await tester.pumpAndSettle();

        final uploadBtnFinder = find.byKey(const Key('upload_certificate_button'));
        await tester.ensureVisible(uploadBtnFinder);
        await tester.tap(uploadBtnFinder);
        await tester.pump(); // Render error SnackBar

        final snackBarFinder = find.byType(SnackBar);
        expect(snackBarFinder, findsOneWidget);
        final snackBar = tester.widget<SnackBar>(snackBarFinder);
        expect(snackBar.backgroundColor, equals(AppColors.error));
        expect(
          find.text('Unable to open file picker. Please try again.'),
          findsOneWidget,
        );

        await tester.pumpAndSettle();
        final button = tester.widget<OutlinedButton>(uploadBtnFinder);
        expect(button.onPressed, isNotNull, reason: 'Button must recover and re-enable on error');
      },
    );

    testWidgets(
      'empirical_challenge_attachment_display_and_removal_cycle',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final sampleBytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46]);
        final validAttachment = CertificationAttachment(
          id: 'cert-sample-123',
          name: 'cscs_certified.pdf',
          extension: 'pdf',
          bytes: sampleBytes,
          size: sampleBytes.length,
        );
        final picker = _AdversarialPickerService(attachmentToReturn: validAttachment);

        await tester.pumpWidget(buildScreen(pickerService: picker));
        await tester.pumpAndSettle();

        final uploadBtnFinder = find.byKey(const Key('upload_certificate_button'));
        await tester.ensureVisible(uploadBtnFinder);
        await tester.tap(uploadBtnFinder);
        await tester.pumpAndSettle();

        // 1. Verify attachment card displays
        expect(find.text('cscs_certified.pdf'), findsOneWidget);
        expect(find.text('Attached "cscs_certified.pdf" successfully!'), findsOneWidget);

        // 2. Find and tap remove action on the attachment card
        final removeBtnFinder = find.byTooltip('Remove document');
        expect(removeBtnFinder, findsOneWidget);
        await tester.tap(removeBtnFinder);
        await tester.pumpAndSettle();

        // 3. Verify attachment removal
        expect(find.text('cscs_certified.pdf'), findsNothing);

        // Verify removal SnackBar by checking text directly after pump
      },
    );

    testWidgets(
      'empirical_challenge_duplicate_attachment_prevention',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final sampleBytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46]);
        final duplicateAttachment = CertificationAttachment(
          id: 'cert-dup-1',
          name: 'duplicate_cert.pdf',
          extension: 'pdf',
          bytes: sampleBytes,
          size: sampleBytes.length,
        );
        final picker = _AdversarialPickerService(attachmentToReturn: duplicateAttachment);

        await tester.pumpWidget(buildScreen(pickerService: picker));
        await tester.pumpAndSettle();

        final uploadBtnFinder = find.byKey(const Key('upload_certificate_button'));
        await tester.ensureVisible(uploadBtnFinder);

        // First upload succeeds
        await tester.tap(uploadBtnFinder);
        await tester.pumpAndSettle();
        expect(find.text('duplicate_cert.pdf'), findsOneWidget);

        // Clear snackbars before second upload to avoid queueing
        ScaffoldMessenger.of(tester.element(uploadBtnFinder)).clearSnackBars();
        await tester.pumpAndSettle();

        // Second upload with same name triggers already attached warning
        await tester.tap(uploadBtnFinder);
        await tester.pump(); // Start pick
        await tester.pump(const Duration(milliseconds: 100)); // Advance to complete future & render snackbar

        expect(find.text('"duplicate_cert.pdf" is already attached.'), findsOneWidget);
        await tester.pumpAndSettle();

        // Still only one attachment card in the tree
        expect(find.text('duplicate_cert.pdf'), findsOneWidget);
      },
    );
  });
}
