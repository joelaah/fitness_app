import 'dart:async';
import 'dart:typed_data';

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

class _ControllablePickerService extends CertificationPickerService {
  _ControllablePickerService({
    this.pickerCompleter,
    this.attachmentToReturn,
  });

  Completer<CertificationAttachment?>? pickerCompleter;
  CertificationAttachment? attachmentToReturn;

  @override
  Future<CertificationAttachment?> pickCertification() async {
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

  group('TrainerRegistrationScreen Upload Button Tests', () {
    testWidgets('upload_button_disabled_while_picking', (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final completer = Completer<CertificationAttachment?>();
      final picker = _ControllablePickerService(pickerCompleter: completer);

      await tester.pumpWidget(buildScreen(pickerService: picker));
      await tester.pumpAndSettle();

      final uploadBtnFinder = find.byKey(const Key('upload_certificate_button'));
      expect(uploadBtnFinder, findsOneWidget);
      await tester.ensureVisible(uploadBtnFinder);

      // Verify button is initially enabled
      var button = tester.widget<OutlinedButton>(uploadBtnFinder);
      expect(button.onPressed, isNotNull);

      // Tap button to start picking
      await tester.tap(uploadBtnFinder);
      await tester.pump(); // Triggers setState(() { _isPickingFile = true; })

      // Verify button is disabled during pick
      button = tester.widget<OutlinedButton>(uploadBtnFinder);
      expect(button.onPressed, isNull);

      // Complete future
      completer.complete(null);
      await tester.pumpAndSettle();

      // Verify button is re-enabled
      button = tester.widget<OutlinedButton>(uploadBtnFinder);
      expect(button.onPressed, isNotNull);
    });

    testWidgets('upload_button_shows_error_on_null_result', (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final picker = _ControllablePickerService(attachmentToReturn: null);

      await tester.pumpWidget(buildScreen(pickerService: picker));
      await tester.pumpAndSettle();

      final uploadBtnFinder = find.byKey(const Key('upload_certificate_button'));
      await tester.ensureVisible(uploadBtnFinder);
      await tester.tap(uploadBtnFinder);
      await tester.pump(); // Render SnackBar

      expect(
        find.text('Unable to open file picker. Please try again.'),
        findsOneWidget,
      );

      await tester.pumpAndSettle();
      final button = tester.widget<OutlinedButton>(uploadBtnFinder);
      expect(button.onPressed, isNotNull);
    });

    testWidgets('upload_button_adds_attachment_on_success', (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final sampleBytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46]);
      final successAttachment = CertificationAttachment(
        id: 'cert-success-1',
        name: 'verified_cscs.pdf',
        extension: 'pdf',
        bytes: sampleBytes,
        size: sampleBytes.length,
      );
      final picker = _ControllablePickerService(attachmentToReturn: successAttachment);

      await tester.pumpWidget(buildScreen(pickerService: picker));
      await tester.pumpAndSettle();

      final uploadBtnFinder = find.byKey(const Key('upload_certificate_button'));
      await tester.ensureVisible(uploadBtnFinder);
      await tester.tap(uploadBtnFinder);
      await tester.pumpAndSettle();

      expect(find.text('verified_cscs.pdf'), findsOneWidget);
      expect(find.text('Attached "verified_cscs.pdf" successfully!'), findsOneWidget);
    });
  });
}
