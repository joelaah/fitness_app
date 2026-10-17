import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:fitness_app/features/auth/services/auth_service.dart';
import 'package:fitness_app/features/trainers/models/trainer_profile.dart';
import 'package:fitness_app/features/trainers/screens/trainer_dashboard_screen.dart';
import 'package:fitness_app/features/trainers/screens/trainer_discovery_screen.dart';
import 'package:fitness_app/features/trainers/screens/trainer_registration_screen.dart';
import 'package:fitness_app/features/trainers/services/certification_picker_service.dart';
import 'package:fitness_app/features/trainers/services/trainer_service.dart';
import 'package:fitness_app/features/trainers/services/trainer_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthService extends AuthService {
  _FakeAuthService({this.anon = false, this.userId = 'user-123'});

  final bool anon;
  final String? userId;

  @override
  bool get isAnonymous => anon;

  @override
  String? get currentUserId => userId;
}

class _FakeTrainerService extends TrainerService {
  _FakeTrainerService({this.profileToReturn, this.shouldThrow = false});

  TrainerProfile? profileToReturn;
  final bool shouldThrow;

  @override
  Future<TrainerProfile?> getMyTrainerProfile() async {
    if (shouldThrow) {
      throw Exception('Network error loading coach profile');
    }
    return profileToReturn;
  }

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
    final effectiveUid = userId ?? 'user-registered';
    final created = TrainerProfile(
      id: 'coach-reg-$effectiveUid',
      userId: effectiveUid,
      displayName: displayName ?? 'Coach',
      bio: bio,
      certifications: certifications,
      specialties: specialties,
      experienceYears: experienceYears,
      hourlyRate: hourlyRate,
      availability: availability,
    );
    profileToReturn = created;
    return created;
  }
}

class _FakeStorageService extends TrainerStorageService {
  @override
  Future<String> uploadCertification({
    required String userId,
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
  }) async {
    return 'https://storage.pulsefit.io/$userId/$fileName';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CertificationPickerService Unit Tests', () {
    test('sanitizeExtensions normalizes dots, whitespace, and uppercase', () {
      final input = <String>['.pdf', ' .png ', 'JPG', '..jpeg', '  ', ''];
      final sanitized = CertificationPickerService.sanitizeExtensions(input);

      expect(sanitized, equals(['pdf', 'png', 'jpg', 'jpeg']));
    });

    test(
      'formatAcceptString generates valid HTML accept string with no leading whitespace',
      () {
        final acceptStr = CertificationPickerService.formatAcceptString(
          ['pdf', 'png', 'jpg', 'jpeg'],
        );

        expect(acceptStr, equals('.pdf,.png,.jpg,.jpeg'));
        expect(acceptStr.startsWith(' '), isFalse);
        expect(acceptStr.contains(' '), isFalse);

        final messyInputAccept = CertificationPickerService.formatAcceptString(
          ['.pdf', '  .PNG  ', '..jpg'],
        );
        expect(messyInputAccept, equals('.pdf,.png,.jpg'));
      },
    );

    test(
      'pickCertification parses PDF result and passes cancelUploadOnWindowBlur: false',
      () async {
        bool? capturedBlurParam;
        FileType? capturedType;
        List<String>? capturedExtensions;
        bool? capturedWithData;

        final pdfBytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x0A]);

        final service = CertificationPickerService(
          pickFilesHandler: ({
            FileType type = FileType.any,
            List<String>? allowedExtensions,
            bool withData = true,
            bool cancelUploadOnWindowBlur = true,
          }) async {
            capturedBlurParam = cancelUploadOnWindowBlur;
            capturedType = type;
            capturedExtensions = allowedExtensions;
            capturedWithData = withData;

            return FilePickerResult([
              PlatformFile(
                name: 'cpt_certified.pdf',
                size: pdfBytes.length,
                bytes: pdfBytes,
              ),
            ]);
          },
        );

        final result = await service.pickCertification();

        expect(result, isNotNull);
        expect(result!.name, equals('cpt_certified.pdf'));
        expect(result.extension, equals('pdf'));
        expect(result.isPdf, isTrue);
        expect(result.isImage, isFalse);
        expect(result.bytes, equals(pdfBytes));
        expect(result.size, equals(pdfBytes.length));

        expect(capturedBlurParam, isFalse);
        expect(capturedType, equals(FileType.custom));
        expect(capturedWithData, isTrue);
        expect(capturedExtensions, equals(['pdf', 'png', 'jpg', 'jpeg']));
      },
    );

    test('pickCertification parses PNG and JPG image results correctly', () async {
      final pngBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);

      final pngService = CertificationPickerService(
        pickFilesHandler: ({
          FileType type = FileType.any,
          List<String>? allowedExtensions,
          bool withData = true,
          bool cancelUploadOnWindowBlur = true,
        }) async {
          return FilePickerResult([
            PlatformFile(
              name: 'trainer_badge.PNG',
              size: pngBytes.length,
              bytes: pngBytes,
            ),
          ]);
        },
      );

      final pngResult = await pngService.pickCertification();
      expect(pngResult, isNotNull);
      expect(pngResult!.name, equals('trainer_badge.PNG'));
      expect(pngResult.extension, equals('png'));
      expect(pngResult.isImage, isTrue);
      expect(pngResult.isPdf, isFalse);
      expect(pngResult.bytes, equals(pngBytes));

      final jpgBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF]);
      final jpgService = CertificationPickerService(
        pickFilesHandler: ({
          FileType type = FileType.any,
          List<String>? allowedExtensions,
          bool withData = true,
          bool cancelUploadOnWindowBlur = true,
        }) async {
          return FilePickerResult([
            PlatformFile(
              name: 'cert_photo.jpg',
              size: jpgBytes.length,
              bytes: jpgBytes,
            ),
          ]);
        },
      );

      final jpgResult = await jpgService.pickCertification();
      expect(jpgResult, isNotNull);
      expect(jpgResult!.extension, equals('jpg'));
      expect(jpgResult.isImage, isTrue);
    });

    test('pickCertification returns null when file picking is cancelled', () async {
      final cancelledService = CertificationPickerService(
        pickFilesHandler: ({
          FileType type = FileType.any,
          List<String>? allowedExtensions,
          bool withData = true,
          bool cancelUploadOnWindowBlur = true,
        }) async {
          return null;
        },
      );

      final result = await cancelledService.pickCertification();
      expect(result, isNull);
    });

    test('pickCertification catches exceptions and returns null safely', () async {
      final throwingService = CertificationPickerService(
        pickFilesHandler: ({
          FileType type = FileType.any,
          List<String>? allowedExtensions,
          bool withData = true,
          bool cancelUploadOnWindowBlur = true,
        }) async {
          throw Exception('File dialog interrupted');
        },
      );

      final result = await throwingService.pickCertification();
      expect(result, isNull);
    });

    test(
      'pickCertification falls back to bytes.length when file.size is zero or negative',
      () async {
        final mockBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7]);
        final service = CertificationPickerService(
          pickFilesHandler: ({
            FileType type = FileType.any,
            List<String>? allowedExtensions,
            bool withData = true,
            bool cancelUploadOnWindowBlur = true,
          }) async {
            return FilePickerResult([
              PlatformFile(
                name: 'zero_size_file.pdf',
                size: 0,
                bytes: mockBytes,
              ),
            ]);
          },
        );

        final result = await service.pickCertification();
        expect(result, isNotNull);
        expect(result!.size, equals(mockBytes.length));
        expect(result.bytes, equals(mockBytes));
      },
    );

    test(
      'pickCertification handles null file.extension and derives from filename or falls back to pdf',
      () async {
        final service = CertificationPickerService(
          pickFilesHandler: ({
            FileType type = FileType.any,
            List<String>? allowedExtensions,
            bool withData = true,
            bool cancelUploadOnWindowBlur = true,
          }) async {
            return FilePickerResult([
              PlatformFile(
                name: 'document_without_ext',
                size: 10,
                bytes: Uint8List(10),
              ),
            ]);
          },
        );

        final result = await service.pickCertification();
        expect(result, isNotNull);
        expect(result!.extension, equals('pdf'));
        expect(result.isPdf, isTrue);
      },
    );

    test(
      'pickCertification identifies PNG magic bytes when filename has no extension',
      () async {
        final pngMagicBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A]);
        final service = CertificationPickerService(
          pickFilesHandler: ({
            FileType type = FileType.any,
            List<String>? allowedExtensions,
            bool withData = true,
            bool cancelUploadOnWindowBlur = true,
          }) async {
            return FilePickerResult([
              PlatformFile(
                name: 'scanned_badge_no_ext',
                size: pngMagicBytes.length,
                bytes: pngMagicBytes,
              ),
            ]);
          },
        );

        final result = await service.pickCertification();
        expect(result, isNotNull);
        expect(result!.extension, equals('png'));
        expect(result.isImage, isTrue);
        expect(result.isPdf, isFalse);
      },
    );

    test(
      'pickCertification identifies PNG magic bytes when filename ends with a trailing dot',
      () async {
        final pngMagicBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A]);
        final service = CertificationPickerService(
          pickFilesHandler: ({
            FileType type = FileType.any,
            List<String>? allowedExtensions,
            bool withData = true,
            bool cancelUploadOnWindowBlur = true,
          }) async {
            return FilePickerResult([
              PlatformFile(
                name: 'scanned_badge.',
                size: pngMagicBytes.length,
                bytes: pngMagicBytes,
              ),
            ]);
          },
        );

        final result = await service.pickCertification();
        expect(result, isNotNull);
        expect(result!.extension, equals('png'));
        expect(result.isImage, isTrue);
        expect(result.isPdf, isFalse);
      },
    );

    test(
      'pickCertification identifies PDF magic bytes when filename has an unknown extension (.tmp)',
      () async {
        final pdfBytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x0A]);
        final service = CertificationPickerService(
          pickFilesHandler: ({
            FileType type = FileType.any,
            List<String>? allowedExtensions,
            bool withData = true,
            bool cancelUploadOnWindowBlur = true,
          }) async {
            return FilePickerResult([
              PlatformFile(
                name: 'certificate.tmp',
                size: pdfBytes.length,
                bytes: pdfBytes,
              ),
            ]);
          },
        );

        final result = await service.pickCertification();
        expect(result, isNotNull);
        expect(result!.extension, equals('pdf'));
        expect(result.isPdf, isTrue);
      },
    );

    test(
      'pickCertification identifies WebP magic bytes when filename has no extension',
      () async {
        final webpBytes = Uint8List.fromList([
          0x52, 0x49, 0x46, 0x46, // RIFF
          0x00, 0x00, 0x00, 0x00,
          0x57, 0x45, 0x42, 0x50, // WEBP
        ]);
        final service = CertificationPickerService(
          pickFilesHandler: ({
            FileType type = FileType.any,
            List<String>? allowedExtensions,
            bool withData = true,
            bool cancelUploadOnWindowBlur = true,
          }) async {
            return FilePickerResult([
              PlatformFile(
                name: 'coaching_badge_no_ext',
                size: webpBytes.length,
                bytes: webpBytes,
              ),
            ]);
          },
        );

        final result = await service.pickCertification();
        expect(result, isNotNull);
        expect(result!.extension, equals('webp'));
        expect(result.isImage, isTrue);
        expect(result.isPdf, isFalse);
      },
    );

    test('sanitizeExtensions deduplicates duplicate and mixed-case extensions', () {
      final input = <String>['.pdf', ' .png ', 'PDF', '..jpeg', 'png', ''];
      final sanitized = CertificationPickerService.sanitizeExtensions(input);

      expect(sanitized, equals(['pdf', 'png', 'jpeg']));
    });

    test(
      'sanitizeExtensions strips wildcards (*), leading and trailing dots, and rejects invalid non-alphanumeric tokens',
      () {
        final input = <String>[
          '*.pdf',
          ' .PNG ',
          '..jpg..',
          'jpeg.',
          '*.*',
          'image/png',
          'doc;tmp',
        ];
        final sanitized = CertificationPickerService.sanitizeExtensions(input);

        expect(sanitized, equals(['pdf', 'png', 'jpg', 'jpeg']));
      },
    );

    test('formatAcceptString deduplicates extensions and generates clean accept string', () {
      final acceptStr = CertificationPickerService.formatAcceptString(
        ['pdf', 'png', 'PDF', 'jpg', 'jpeg', '.png'],
      );

      expect(acceptStr, equals('.pdf,.png,.jpg,.jpeg'));
    });

    test('formatAcceptString handles wildcards, extra dots, and empty lists cleanly', () {
      final acceptStr = CertificationPickerService.formatAcceptString(
        ['*.pdf', '..png..', 'jpeg.', '*.*'],
      );
      expect(acceptStr, equals('.pdf,.png,.jpeg'));

      final emptyAcceptStr = CertificationPickerService.formatAcceptString(
        ['*.*', ''],
      );
      expect(emptyAcceptStr, equals(''));
    });

    test(
      'pickCertification resolves blank or whitespace filename to fallback with detected extension',
      () async {
        final pdfBytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x0A]);
        final service = CertificationPickerService(
          pickFilesHandler: ({
            FileType type = FileType.any,
            List<String>? allowedExtensions,
            bool withData = true,
            bool cancelUploadOnWindowBlur = true,
          }) async {
            return FilePickerResult([
              PlatformFile(
                name: '   ',
                size: pdfBytes.length,
                bytes: pdfBytes,
              ),
            ]);
          },
        );

        final result = await service.pickCertification();
        expect(result, isNotNull);
        expect(result!.name, equals('certificate.pdf'));
        expect(result.extension, equals('pdf'));
        expect(result.isPdf, isTrue);
      },
    );
  });

  group('TrainerDashboardScreen Role Guard & Access Restriction Widget Tests', () {
    const verifiedCoachProfile = TrainerProfile(
      id: 'trainer-verified-77',
      userId: 'user-coach-77',
      displayName: 'Coach Marcus Vance',
      bio: 'Hypertrophy specialist and CSCS certified strength coach.',
      certifications: <String>['CSCS', 'NASM-PES'],
      specialties: <String>['Hypertrophy', 'Strength'],
      experienceYears: 8,
      hourlyRate: 3000,
      rating: 4.95,
    );

    testWidgets(
      'Anonymous user is denied access and presented with Access Restricted view without telemetry',
      (tester) async {
        final authService = _FakeAuthService(anon: true);
        final trainerService = _FakeTrainerService(profileToReturn: null);

        await tester.pumpWidget(
          MaterialApp(
            home: TrainerDashboardScreen(
              authService: authService,
              trainerService: trainerService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Informative restricted screen displayed
        expect(find.text('Access Restricted: Coaches Only'), findsOneWidget);
        expect(find.text('Register as a Coach'), findsOneWidget);
        expect(find.text('Return to Coaches'), findsOneWidget);
        expect(find.byIcon(Icons.lock_person_rounded), findsOneWidget);

        // 2. Private trainer telemetry MUST NOT be rendered
        expect(find.text('SESSION RATE & FEE BREAKDOWN'), findsNothing);
        expect(find.text('Hourly Booking Rate'), findsNothing);
        expect(find.text('Your Net Payout (90%)'), findsNothing);
        expect(find.text('PulseFit Cut (10%)'), findsNothing);
        expect(find.text('COACH PERFORMANCE'), findsNothing);
        expect(find.text('Active Clients'), findsNothing);
        expect(find.text('Sessions Held'), findsNothing);
        expect(find.text('Coach Devon Hayes'), findsNothing);
      },
    );

    testWidgets(
      'Authenticated non-trainer user (getMyTrainerProfile == null) is denied access',
      (tester) async {
        final authService = _FakeAuthService(anon: false, userId: 'client-user-99');
        final trainerService = _FakeTrainerService(profileToReturn: null);

        await tester.pumpWidget(
          MaterialApp(
            home: TrainerDashboardScreen(
              authService: authService,
              trainerService: trainerService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Access Restricted: Coaches Only'), findsOneWidget);
        expect(find.text('Register as a Coach'), findsOneWidget);
        expect(find.text('Hourly Booking Rate'), findsNothing);
        expect(find.text('Coach Devon Hayes'), findsNothing);
      },
    );

    testWidgets(
      'Registered trainer sees their dashboard, session rates, net payout and metrics',
      (tester) async {
        final authService = _FakeAuthService(anon: false, userId: 'user-coach-77');
        final trainerService = _FakeTrainerService(
          profileToReturn: verifiedCoachProfile,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: TrainerDashboardScreen(
              authService: authService,
              trainerService: trainerService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verified trainer metrics visible
        expect(find.text('Coach Marcus Vance'), findsOneWidget);
        expect(find.text('₹3000 / session'), findsOneWidget);
        expect(find.text('Your Net Payout (90%)'), findsOneWidget);
        expect(find.text('₹2700'), findsOneWidget);
        expect(find.text('PulseFit Cut (10%)'), findsOneWidget);
        expect(find.text('₹300'), findsOneWidget);
        expect(find.text('Active Clients'), findsOneWidget);
        expect(find.text('Sessions Held'), findsOneWidget);
        expect(find.text('Average Rating'), findsOneWidget);

        // 2. Restricted banner must NOT appear
        expect(find.text('Access Restricted: Coaches Only'), findsNothing);
      },
    );

    testWidgets(
      'Clicking Register as a Coach navigates to TrainerRegistrationScreen',
      (tester) async {
        final authService = _FakeAuthService(anon: false, userId: 'client-1');
        final trainerService = _FakeTrainerService(profileToReturn: null);
        final storageService = _FakeStorageService();

        await tester.pumpWidget(
          MaterialApp(
            home: TrainerDashboardScreen(
              authService: authService,
              trainerService: trainerService,
              storageService: storageService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final registerBtn = find.text('Register as a Coach');
        expect(registerBtn, findsOneWidget);

        await tester.tap(registerBtn);
        await tester.pumpAndSettle();

        // Verify navigation to TrainerRegistrationScreen
        expect(find.byType(TrainerRegistrationScreen), findsOneWidget);
        expect(find.text('Complete Coach Registration'), findsOneWidget);
      },
    );

    testWidgets(
      'Clicking Return to Coaches button pops back to previous screen',
      (tester) async {
        final authService = _FakeAuthService(anon: true);
        final trainerService = _FakeTrainerService(profileToReturn: null);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<dynamic>(
                        builder: (context) => TrainerDashboardScreen(
                          authService: authService,
                          trainerService: trainerService,
                        ),
                      ),
                    );
                  },
                  child: const Text('Open Dashboard'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Dashboard'));
        await tester.pumpAndSettle();

        expect(find.text('Access Restricted: Coaches Only'), findsOneWidget);

        final returnBtn = find.text('Return to Coaches');
        expect(returnBtn, findsOneWidget);
        await tester.ensureVisible(returnBtn);

        await tester.tap(returnBtn);
        await tester.pumpAndSettle();

        // Screen popped, back to root screen
        expect(find.text('Open Dashboard'), findsOneWidget);
        expect(find.text('Access Restricted: Coaches Only'), findsNothing);
      },
    );

    testWidgets(
      'AppBar back action on restricted screen pops back to previous route',
      (tester) async {
        final authService = _FakeAuthService(anon: true);
        final trainerService = _FakeTrainerService(profileToReturn: null);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<dynamic>(
                        builder: (context) => TrainerDashboardScreen(
                          authService: authService,
                          trainerService: trainerService,
                        ),
                      ),
                    );
                  },
                  child: const Text('Go To Restricted'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Go To Restricted'));
        await tester.pumpAndSettle();

        final backIcon = find.byTooltip('Return to Coaches');
        expect(backIcon, findsOneWidget);

        await tester.tap(backIcon);
        await tester.pumpAndSettle();

        expect(find.text('Go To Restricted'), findsOneWidget);
      },
    );

    testWidgets(
      'Direct injection of trainerProfile renders dashboard immediately for authenticated coach',
      (tester) async {
        final authService = _FakeAuthService(anon: false);

        await tester.pumpWidget(
          MaterialApp(
            home: TrainerDashboardScreen(
              authService: authService,
              trainerProfile: verifiedCoachProfile,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Coach Marcus Vance'), findsOneWidget);
        expect(find.text('₹3000 / session'), findsOneWidget);
        expect(find.text('Access Restricted: Coaches Only'), findsNothing);
      },
    );

    testWidgets(
      'Anonymous user with directly passed trainerProfile is denied access and falls back to restricted view',
      (tester) async {
        final authService = _FakeAuthService(anon: true);

        await tester.pumpWidget(
          MaterialApp(
            home: TrainerDashboardScreen(
              authService: authService,
              trainerProfile: verifiedCoachProfile,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Must still deny access even if a profile object was passed
        expect(find.text('Access Restricted: Coaches Only'), findsOneWidget);
        expect(find.text('Register as a Coach'), findsOneWidget);
        expect(find.text('Coach Marcus Vance'), findsNothing);
      },
    );

    testWidgets(
      'TrainerDashboardScreen renders restricted view when getMyTrainerProfile throws an exception',
      (tester) async {
        final authService = _FakeAuthService(anon: false, userId: 'coach-error-user');
        final trainerService = _FakeTrainerService(shouldThrow: true);

        await tester.pumpWidget(
          MaterialApp(
            home: TrainerDashboardScreen(
              authService: authService,
              trainerService: trainerService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Access Restricted: Coaches Only'), findsOneWidget);
        expect(find.text('Register as a Coach'), findsOneWidget);
        expect(find.text('SESSION RATE & FEE BREAKDOWN'), findsNothing);
      },
    );

    testWidgets(
      'Return to Coaches button falls back to TrainerDiscoveryScreen when Navigator.canPop is false',
      (tester) async {
        final authService = _FakeAuthService(anon: true);
        final trainerService = _FakeTrainerService(profileToReturn: null);

        await tester.pumpWidget(
          MaterialApp(
            home: TrainerDashboardScreen(
              authService: authService,
              trainerService: trainerService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Access Restricted: Coaches Only'), findsOneWidget);

        final returnBtn = find.text('Return to Coaches');
        expect(returnBtn, findsOneWidget);
        await tester.ensureVisible(returnBtn);

        await tester.tap(returnBtn);
        await tester.pumpAndSettle();

        expect(find.byType(TrainerDiscoveryScreen), findsOneWidget);
        expect(find.text('Access Restricted: Coaches Only'), findsNothing);
      },
    );

    testWidgets(
      'AppBar leading back button falls back to TrainerDiscoveryScreen when Navigator.canPop is false',
      (tester) async {
        final authService = _FakeAuthService(anon: true);
        final trainerService = _FakeTrainerService(profileToReturn: null);

        await tester.pumpWidget(
          MaterialApp(
            home: TrainerDashboardScreen(
              authService: authService,
              trainerService: trainerService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final backIcon = find.byTooltip('Return to Coaches');
        expect(backIcon, findsOneWidget);

        await tester.tap(backIcon);
        await tester.pumpAndSettle();

        expect(find.byType(TrainerDiscoveryScreen), findsOneWidget);
        expect(find.text('Access Restricted: Coaches Only'), findsNothing);
      },
    );

    testWidgets(
      'Registering as a coach from restricted dashboard updates view upon return',
      (tester) async {
        final authService =
            _FakeAuthService(anon: false, userId: 'new-coach-123');
        final trainerService = _FakeTrainerService(profileToReturn: null);
        final storageService = _FakeStorageService();

        await tester.pumpWidget(
          MaterialApp(
            home: TrainerDashboardScreen(
              authService: authService,
              trainerService: trainerService,
              storageService: storageService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Access Restricted: Coaches Only'), findsOneWidget);

        // Tap 'Register as a Coach'
        await tester.tap(find.text('Register as a Coach'));
        await tester.pumpAndSettle();

        expect(find.byType(TrainerRegistrationScreen), findsOneWidget);

        // Enter display name and bio
        await tester.enterText(
          find.widgetWithText(TextFormField, 'e.g. Alex Mercer, CSCS'),
          'Coach Samantha Ray',
        );
        await tester.enterText(
          find.widgetWithText(
            TextFormField,
            'Describe your coaching style and results...',
          ),
          'Elite strength and conditioning coach with 10+ years experience.',
        );

        // Submit form
        final submitBtn = find.text('Complete Coach Registration');
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        // Screen popped, back to TrainerDashboardScreen which reloads profile
        expect(find.byType(TrainerRegistrationScreen), findsNothing);
        expect(find.text('Coach Samantha Ray'), findsOneWidget);
        expect(find.text('SESSION RATE & FEE BREAKDOWN'), findsOneWidget);
        expect(find.text('Access Restricted: Coaches Only'), findsNothing);
      },
    );
  });
}
