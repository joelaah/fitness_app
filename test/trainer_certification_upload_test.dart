import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fitness_app/features/auth/services/auth_service.dart';
import 'package:fitness_app/features/trainers/models/certification_attachment.dart';
import 'package:fitness_app/features/trainers/models/trainer_profile.dart';
import 'package:fitness_app/features/trainers/screens/trainer_registration_screen.dart';
import 'package:fitness_app/features/trainers/services/certification_picker_service.dart';
import 'package:fitness_app/features/trainers/services/trainer_service.dart';
import 'package:fitness_app/features/trainers/services/trainer_storage_service.dart';
import 'package:fitness_app/features/trainers/widgets/certification_attachment_card.dart';
import 'package:fitness_app/features/trainers/widgets/certification_preview_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockTrainerService extends TrainerService {
  TrainerProfile? registeredProfile;
  TrainerProfile? updatedProfile;
  List<String>? lastCertifications;

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
    lastCertifications = List<String>.from(certifications);
    registeredProfile = TrainerProfile(
      id: 'mock-reg-1',
      userId: userId ?? 'mock-user-1',
      displayName: displayName ?? 'Coach Test',
      bio: bio,
      certifications: certifications,
      specialties: specialties,
      experienceYears: experienceYears,
      hourlyRate: hourlyRate,
    );
    return registeredProfile!;
  }

  @override
  Future<TrainerProfile> updateTrainerProfile(
    dynamic profileOrUserId, {
    String? displayName,
    String? bio,
    List<String>? certifications,
    List<String>? specialties,
    int? experienceYears,
    double? hourlyRate,
    Map<String, dynamic>? availability,
  }) async {
    lastCertifications =
        certifications != null ? List<String>.from(certifications) : null;
    updatedProfile = TrainerProfile(
      id: 'mock-reg-1',
      userId: profileOrUserId.toString(),
      displayName: displayName ?? 'Coach Test',
      bio: bio ?? '',
      certifications: certifications ?? const <String>[],
      specialties: specialties ?? const <String>[],
      experienceYears: experienceYears ?? 0,
      hourlyRate: hourlyRate ?? 1000,
    );
    return updatedProfile!;
  }
}

class _MockAuthService extends AuthService {
  _MockAuthService({this.mockUserId = 'mock-user-123'});

  final String? mockUserId;

  @override
  String? get currentUserId => mockUserId;

  @override
  bool get isAnonymous => false;
}

class _MockStorageService extends TrainerStorageService {
  _MockStorageService({
    this.shouldFail = false,
    this.publicUrlToReturn,
  });

  bool shouldFail;
  String? publicUrlToReturn;
  String? lastUploadedPath;
  Uint8List? lastUploadedBytes;
  String? lastUploadedMimeType;
  String? lastUploadedUserId;

  @override
  Future<String> uploadCertification({
    required String userId,
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
  }) async {
    lastUploadedUserId = userId;
    lastUploadedPath = '$userId/$fileName';
    lastUploadedBytes = bytes;
    lastUploadedMimeType = mimeType;

    if (shouldFail) {
      throw Exception('Storage connection timed out');
    }

    if (publicUrlToReturn != null) {
      return publicUrlToReturn!;
    }

    // Default mock URL simulating Supabase Storage public URL
    return 'https://supabase.pulsefit.io/storage/v1/object/public/trainer-certifications/$userId/$fileName';
  }
}

class _DelayedStorageService extends TrainerStorageService {
  _DelayedStorageService(this._future);

  final Future<String> _future;

  @override
  Future<String> uploadCertification({
    required String userId,
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
  }) {
    return _future;
  }
}

class _MockPickerService extends CertificationPickerService {
  _MockPickerService({this.fileToReturn});

  CertificationAttachment? fileToReturn;

  @override
  Future<CertificationAttachment?> pickCertification() async {
    return fileToReturn;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CertificationAttachment Model Unit Tests', () {
    test('Correctly identifies PDF vs Image files and formats file size', () {
      final pdfAttachment = CertificationAttachment(
        id: '1',
        name: 'nasm_cpt.pdf',
        extension: 'pdf',
        size: 512 * 1024, // 512 KB
      );
      expect(pdfAttachment.isPdf, isTrue);
      expect(pdfAttachment.isImage, isFalse);
      expect(pdfAttachment.formattedSize, '512.0 KB');

      final imgAttachment = CertificationAttachment(
        id: '2',
        name: 'cscs_cert.png',
        extension: 'png',
        size: 2 * 1024 * 1024, // 2 MB
      );
      expect(imgAttachment.isPdf, isFalse);
      expect(imgAttachment.isImage, isTrue);
      expect(imgAttachment.formattedSize, '2.0 MB');

      const smallAttachment = CertificationAttachment(
        id: '3',
        name: 'small.jpg',
        extension: 'jpg',
        size: 500,
      );
      expect(smallAttachment.formattedSize, '500 B');
    });

    test('Reconstructs attachment from base64 data URI', () {
      final sampleBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final b64 = base64Encode(sampleBytes);
      final dataUri = 'data:image/png;base64,$b64';

      final attachment = CertificationAttachment.fromUrl(dataUri);
      expect(attachment.extension, 'png');
      expect(attachment.isImage, isTrue);
      expect(attachment.bytes, isNotNull);
      expect(attachment.bytes!.length, 5);
      expect(attachment.storageUrl, dataUri);
    });

    test('Reconstructs attachment from Supabase Storage URL and decodes URL components',
        () {
      const storageUrl =
          'https://test.supabase.co/storage/v1/object/public/trainer-certifications/user-1/My%20CSCS%20Cert.pdf';
      final attachment = CertificationAttachment.fromUrl(storageUrl);

      expect(attachment.extension, 'pdf');
      expect(attachment.name, 'My CSCS Cert.pdf');
      expect(attachment.isPdf, isTrue);
      expect(attachment.storageUrl, storageUrl);
    });

    test('Reconstructs webp and jpg attachments from data URIs and supports custom id', () {
      final webpBytes = Uint8List.fromList([82, 73, 70, 70]);
      final webpUri = 'data:image/webp;base64,${base64Encode(webpBytes)}';
      final webpAttachment = CertificationAttachment.fromUrl(webpUri, id: 'custom-webp-id');

      expect(webpAttachment.id, 'custom-webp-id');
      expect(webpAttachment.extension, 'webp');
      expect(webpAttachment.isImage, isTrue);
      expect(webpAttachment.isPdf, isFalse);
      expect(webpAttachment.name, 'certificate.webp');

      final jpgBytes = Uint8List.fromList([255, 216, 255]);
      final jpgUri = 'data:image/jpg;base64,${base64Encode(jpgBytes)}';
      final jpgAttachment = CertificationAttachment.fromUrl(jpgUri);

      expect(jpgAttachment.extension, 'jpeg');
      expect(jpgAttachment.isImage, isTrue);
      expect(jpgAttachment.name, 'certificate.jpg');
    });

    test('Reconstructs name and extension from data URI with name= parameter and uppercase MIME', () {
      final sampleBytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
      final b64 = base64Encode(sampleBytes);
      final dataUri = 'data:IMAGE/PNG;name=my_special_cert.png;base64,$b64\n';

      final attachment = CertificationAttachment.fromUrl(dataUri);
      expect(attachment.extension, 'png');
      expect(attachment.isImage, isTrue);
      expect(attachment.name, 'my_special_cert.png');
      expect(attachment.bytes, isNotNull);
      expect(attachment.bytes!.length, 8);
    });
  });

  group('TrainerProfile Certification Helper Tests', () {
    test('isAttachmentUrl accurately detects URLs, data URIs, and storage paths',
        () {
      expect(
        TrainerProfile.isAttachmentUrl(
          'https://xyz.supabase.co/storage/v1/object/public/trainer-certifications/u1/file.pdf',
        ),
        isTrue,
      );
      expect(
        TrainerProfile.isAttachmentUrl(
          'trainer-certifications/u1/file.pdf',
        ),
        isTrue,
      );
      expect(
        TrainerProfile.isAttachmentUrl('data:image/png;base64,iVBORw0KGgo...'),
        isTrue,
      );
      expect(
        TrainerProfile.isAttachmentUrl('blob:http://localhost:3000/1234-5678'),
        isTrue,
      );
      expect(
        TrainerProfile.isAttachmentUrl('mock://trainer-certifications/u1/c.pdf'),
        isTrue,
      );
      expect(TrainerProfile.isAttachmentUrl('CSCS - NSCA Certified'), isFalse);
      expect(TrainerProfile.isAttachmentUrl('NASM-CPT'), isFalse);
      expect(TrainerProfile.isAttachmentUrl('RYT-500 Yoga Alliance'), isFalse);
    });

    test('isAttachmentUrl trims leading and trailing whitespace', () {
      expect(
        TrainerProfile.isAttachmentUrl('  https://pulsefit.io/cert.pdf  '),
        isTrue,
      );
      expect(
        TrainerProfile.isAttachmentUrl('   data:image/png;base64,abc  '),
        isTrue,
      );
    });

    test('textCertifications and certificationUrls correctly partition list',
        () {
      const profile = TrainerProfile(
        id: 't-1',
        userId: 'u-1',
        hourlyRate: 1500,
        certifications: <String>[
          'CSCS',
          'https://supabase.io/storage/v1/object/public/trainer-certifications/u1/doc.pdf',
          'NASM-CPT',
          'data:image/png;base64,ABCDEF',
        ],
      );

      expect(profile.textCertifications, equals(['CSCS', 'NASM-CPT']));
      expect(
        profile.certificationUrls,
        equals([
          'https://supabase.io/storage/v1/object/public/trainer-certifications/u1/doc.pdf',
          'data:image/png;base64,ABCDEF',
        ]),
      );
    });
  });

  group('TrainerStorageService Resilience & Fallback Tests', () {
    test('Gracefully generates base64 data URI fallback when Supabase is uninitialized',
        () async {
      final storage = TrainerStorageService(); // Uninitialized Supabase
      final sampleBytes = Uint8List.fromList([10, 20, 30, 40]);

      final fallbackUrl = await storage.uploadCertification(
        userId: 'user-test-1',
        fileName: 'cert.pdf',
        bytes: sampleBytes,
      );

      expect(fallbackUrl.startsWith('data:application/pdf;base64,'), isTrue);
      expect(fallbackUrl, contains(base64Encode(sampleBytes)));
    });

    test('Gracefully falls back to local data URI on network upload error',
        () async {
      final storage = _MockStorageService(shouldFail: true);
      final sampleBytes = Uint8List.fromList([1, 2, 3]);

      try {
        await storage.uploadCertification(
          userId: 'user-1',
          fileName: 'test.png',
          bytes: sampleBytes,
        );
        fail('Mock storage should throw');
      } catch (e) {
        expect(e.toString(), contains('timed out'));
      }
    });

    test('Sanitizes dangerous filenames and dot-segments without throwing', () async {
      final storage = TrainerStorageService();
      final sampleBytes = Uint8List.fromList([1, 2]);

      final fallbackUrl1 = await storage.uploadCertification(
        userId: 'user-dot',
        fileName: '..',
        bytes: sampleBytes,
      );
      expect(fallbackUrl1.startsWith('data:application/pdf;base64,'), isTrue);

      final fallbackUrl2 = await storage.uploadCertification(
        userId: 'user-dot',
        fileName: '.hidden.png',
        bytes: sampleBytes,
      );
      expect(fallbackUrl2.startsWith('data:image/png;base64,'), isTrue);
    });

    test('Sanitizes userId with path traversal and strips trailing dots from filenames', () async {
      final storage = TrainerStorageService();
      final bytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46]); // %PDF
      final result = await storage.uploadCertification(
        userId: '../../malicious_user',
        fileName: 'bad_file....',
        bytes: bytes,
      );
      expect(result, startsWith('data:application/pdf;base64,'));
    });

    test('Detects MIME and extension from magic bytes when filename has no extension', () async {
      final storage = TrainerStorageService();
      final pngBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0, 0]);
      final result = await storage.uploadCertification(
        userId: 'u1',
        fileName: 'my_raw_photo',
        bytes: pngBytes,
      );
      expect(result, startsWith('data:image/png;base64,'));
    });
  });

  group('CertificationAttachmentCard & Preview Dialog Widget Tests', () {
    testWidgets(
        'CertificationAttachmentCard displays PDF badge, name, size and handles callbacks',
        (tester) async {
      final attachment = CertificationAttachment(
        id: 'att-1',
        name: 'sample_doc.pdf',
        extension: 'pdf',
        size: 1024 * 100, // 100 KB
      );

      var previewTapped = false;
      var removeTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CertificationAttachmentCard(
              attachment: attachment,
              onPreview: () => previewTapped = true,
              onRemove: () => removeTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('sample_doc.pdf'), findsOneWidget);
      expect(find.text('100.0 KB'), findsOneWidget);
      expect(find.text('PDF'), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf_rounded), findsOneWidget);

      // Tap card body -> onPreview
      await tester.tap(find.text('sample_doc.pdf'));
      await tester.pumpAndSettle();
      expect(previewTapped, isTrue);

      // Tap remove icon -> onRemove
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(removeTapped, isTrue);
    });

    testWidgets(
        'CertificationPreviewDialog shows PDF document details and close button',
        (tester) async {
      final attachment = CertificationAttachment(
        id: 'att-pdf',
        name: 'nasm_certified.pdf',
        extension: 'pdf',
        size: 250 * 1024,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => CertificationPreviewDialog.show(
                  context,
                  attachment: attachment,
                ),
                child: const Text('Open Preview'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Preview'));
      await tester.pumpAndSettle();

      expect(find.text('nasm_certified.pdf'), findsWidgets);
      expect(find.text('Portable Document Format (PDF)'), findsOneWidget);
      expect(find.text('Verified Certification File'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Portable Document Format (PDF)'), findsNothing);
    });

    testWidgets(
        'CertificationAttachmentCard displays error icon and message when attachment.error is set',
        (tester) async {
      const errorAttachment = CertificationAttachment(
        id: 'att-err',
        name: 'failed_cert.pdf',
        extension: 'pdf',
        size: 1024 * 50,
        error: 'Upload timeout',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CertificationAttachmentCard(
              attachment: errorAttachment,
              onPreview: () {},
              onRemove: () {},
            ),
          ),
        ),
      );

      expect(find.text('failed_cert.pdf'), findsOneWidget);
      expect(find.text('Upload timeout'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      expect(find.text('PDF Ready'), findsNothing);
    });

    testWidgets(
        'CertificationPreviewDialog handles corrupted image bytes gracefully without crash',
        (tester) async {
      final corruptedAttachment = CertificationAttachment(
        id: 'att-corrupt',
        name: 'corrupted.png',
        extension: 'png',
        bytes: Uint8List.fromList([0, 1, 2, 3, 4, 5]), // Not a valid PNG
        size: 6,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => CertificationPreviewDialog.show(
                  context,
                  attachment: corruptedAttachment,
                ),
                child: const Text('Open Corrupted'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Corrupted'));
      await tester.pumpAndSettle();

      expect(find.text('Corrupted or unreadable image file'), findsOneWidget);
      expect(
        find.text('The file could not be decoded as a valid image.'),
        findsOneWidget,
      );
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets(
        'CertificationPreviewDialog renders without overflow on constrained mobile viewport (320x480)',
        (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final attachment = CertificationAttachment(
        id: 'att-small',
        name: 'certification_with_a_very_long_document_title_verified_2026.pdf',
        extension: 'pdf',
        size: 500 * 1024,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => CertificationPreviewDialog.show(
                  context,
                  attachment: attachment,
                ),
                child: const Text('Open Small Viewport'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Small Viewport'));
      await tester.pumpAndSettle();

      expect(find.text('Portable Document Format (PDF)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'CertificationAttachmentCard renders Image.network thumbnail when storageUrl is remote',
        (tester) async {
      const remoteImgAttachment = CertificationAttachment(
        id: 'remote-1',
        name: 'remote_cert.png',
        extension: 'png',
        storageUrl: 'https://example.com/remote_cert.png',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CertificationAttachmentCard(
              attachment: remoteImgAttachment,
              onPreview: () {},
              onRemove: () {},
            ),
          ),
        ),
      );

      expect(find.text('remote_cert.png'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets(
        'CertificationPreviewDialog renders corrupted image notice on landscape constrained viewport (480x320) without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(480, 320);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final corruptedAttachment = CertificationAttachment(
        id: 'corrupt-small',
        name: 'broken.png',
        extension: 'png',
        bytes: Uint8List.fromList([1, 2, 3]),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => CertificationPreviewDialog.show(
                  context,
                  attachment: corruptedAttachment,
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Corrupted or unreadable image file'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'CertificationPreviewDialog renders mock environment notice on constrained viewport (480x320) without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(480, 320);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const mockImgAttachment = CertificationAttachment(
        id: 'mock-img-small',
        name: 'mock_cert.png',
        extension: 'png',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => CertificationPreviewDialog.show(
                  context,
                  attachment: mockImgAttachment,
                ),
                child: const Text('Open Mock Image'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Mock Image'));
      await tester.pumpAndSettle();

      expect(find.text('Image preview unavailable in mock environment'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'CertificationPreviewDialog Remove button invokes onRemove and dismisses dialog',
        (tester) async {
      var removeCalled = false;
      final attachment = CertificationAttachment(
        id: 'removable-1',
        name: 'removable.pdf',
        extension: 'pdf',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => CertificationPreviewDialog.show(
                  context,
                  attachment: attachment,
                  onRemove: () => removeCalled = true,
                ),
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Remove'), findsOneWidget);
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(removeCalled, isTrue);
      expect(find.text('Portable Document Format (PDF)'), findsNothing);
    });

    testWidgets(
        'CertificationPreviewDialog displays error indicator in PDF preview when error is set',
        (tester) async {
      final attachment = CertificationAttachment(
        id: 'err-pdf',
        name: 'failed_cert.pdf',
        extension: 'pdf',
        error: 'Upload timeout',
        size: 1024,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CertificationPreviewDialog(attachment: attachment),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Upload timeout'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      expect(find.text('Verified Certification File'), findsNothing);
    });

    testWidgets(
        'CertificationPreviewDialog handles corrupted data URI by displaying corrupted image notice',
        (tester) async {
      final attachment = CertificationAttachment(
        id: 'corrupted-data-img',
        name: 'corrupted.png',
        extension: 'png',
        storageUrl: 'data:image/png;base64,NOT_VALID_BASE64_!!!',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CertificationPreviewDialog(attachment: attachment),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Corrupted or unreadable image file'), findsOneWidget);
      expect(
        find.text('Image preview unavailable in mock environment'),
        findsNothing,
      );
    });
  });

  group('TrainerRegistrationScreen UI & Persistence Integration Tests', () {
    testWidgets(
        'Empty credential text input: clicking (+) provides immediate informative feedback',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: TrainerRegistrationScreen(
            trainerService: _MockTrainerService(),
            authService: _MockAuthService(),
            storageService: _MockStorageService(),
            pickerService: _MockPickerService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the add icon button for credentials
      final addButton = find.byTooltip('Add credential title');
      expect(addButton, findsOneWidget);
      await tester.ensureVisible(addButton);

      // Tap (+) button with empty input field
      await tester.tap(addButton);
      await tester.pump(); // Show snackbar and error text

      // Visual feedback: error prompt / SnackBar must appear
      expect(
        find.text('Please enter a credential name before adding.'),
        findsOneWidget,
      );
      expect(find.text('Please enter a credential name.'), findsOneWidget);
    });

    testWidgets(
        'Adding text credential creates chip and clears text field and error',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: TrainerRegistrationScreen(
            trainerService: _MockTrainerService(),
            authService: _MockAuthService(),
            storageService: _MockStorageService(),
            pickerService: _MockPickerService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final addButton = find.byKey(const Key('add_certification_button'));
      await tester.ensureVisible(addButton);

      // First click empty to trigger error
      await tester.tap(addButton);
      await tester.pump();
      expect(find.text('Please enter a credential name.'), findsOneWidget);

      // Dismiss the previous snackbar so duplicate warning is immediately rendered
      ScaffoldMessenger.of(tester.element(addButton)).clearSnackBars();
      await tester.pumpAndSettle();

      // Enter valid text credential
      final certInput = find.byKey(const Key('certification_text_input'));
      await tester.enterText(certInput, 'CSCS');
      await tester.pump();

      // Error should clear as user types
      expect(find.text('Please enter a credential name.'), findsNothing);

      // Tap add
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      // Credential chip should appear
      expect(find.text('CSCS'), findsOneWidget);

      // Adding duplicate displays warning
      await tester.enterText(certInput, 'CSCS');
      await tester.tap(addButton);
      await tester.pump();
      expect(
        find.text('This credential has already been added.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'Tapping Upload Certificate / Document launches picker, attaches file, uploads to storage, and persists on submit',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockTrainerService = _MockTrainerService();
      final mockAuthService = _MockAuthService(mockUserId: 'trainer-uid-42');
      final mockStorageService = _MockStorageService(
        publicUrlToReturn:
            'https://storage.pulsefit.io/trainer-certifications/trainer-uid-42/nasm_cert.pdf',
      );
      final dummyPdfBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6]);
      final mockPickerService = _MockPickerService(
        fileToReturn: CertificationAttachment(
          id: 'picked-1',
          name: 'nasm_cert.pdf',
          bytes: dummyPdfBytes,
          size: dummyPdfBytes.length,
          extension: 'pdf',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TrainerRegistrationScreen(
            trainerService: mockTrainerService,
            authService: mockAuthService,
            storageService: mockStorageService,
            pickerService: mockPickerService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify "Upload Certificate / Document" button is present
      final uploadButton = find.byKey(const Key('upload_certificate_button'));
      expect(uploadButton, findsOneWidget);
      await tester.ensureVisible(uploadButton);

      // Add a text credential as well (Dual credential entry)
      final certInput = find.widgetWithText(
        TextField,
        'e.g. CSCS, NASM-CPT, RYT-500...',
      );
      await tester.enterText(certInput, 'CSCS-Elite');
      final addButton = find.byTooltip('Add credential title');
      await tester.ensureVisible(addButton);
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      // Tap upload certificate button
      await tester.ensureVisible(uploadButton);
      await tester.tap(uploadButton);
      await tester.pumpAndSettle();

      // Verify storage service received upload
      expect(
        mockStorageService.lastUploadedPath,
        'trainer-uid-42/nasm_cert.pdf',
      );
      expect(mockStorageService.lastUploadedBytes, dummyPdfBytes);

      // Verify attachment card renders in UI
      expect(find.text('nasm_cert.pdf'), findsOneWidget);
      expect(find.text('PDF Ready'), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf_rounded), findsWidgets);

      // Tap attachment card to launch preview modal
      final pdfCardText = find.text('nasm_cert.pdf');
      await tester.ensureVisible(pdfCardText);
      await tester.tap(pdfCardText);
      await tester.pumpAndSettle();

      // Verify preview modal dialog renders
      expect(find.text('Portable Document Format (PDF)'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      // Fill remaining required form fields: Display Name & Bio
      final nameField =
          find.widgetWithText(TextFormField, 'e.g. Alex Mercer, CSCS');
      await tester.ensureVisible(nameField);
      await tester.enterText(nameField, 'Coach Jordan');

      final bioField = find.widgetWithText(
        TextFormField,
        'Describe your coaching style and results...',
      );
      await tester.ensureVisible(bioField);
      await tester.enterText(
        bioField,
        'Elite strength coach with over 10 years of personal training experience.',
      );

      // Submit registration
      final submitButton = find.text('Complete Coach Registration');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Verify submission persisted both text credentials and uploaded document URLs
      expect(mockTrainerService.lastCertifications, isNotNull);
      expect(
        mockTrainerService.lastCertifications,
        contains('CSCS-Elite'),
      );
      expect(
        mockTrainerService.lastCertifications,
        contains(
          'https://storage.pulsefit.io/trainer-certifications/trainer-uid-42/nasm_cert.pdf',
        ),
      );
    });

    testWidgets(
        'Offline fallback: uploadCertification failure gracefully keeps local preview and persists without crash',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockTrainerService = _MockTrainerService();
      final mockAuthService = _MockAuthService(mockUserId: 'trainer-offline-1');
      // Storage service uninitialized -> uses resilient local fallback data URI
      final storageService = TrainerStorageService();

      final imgBytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
      final mockPickerService = _MockPickerService(
        fileToReturn: CertificationAttachment(
          id: 'picked-img',
          name: 'cpt_badge.png',
          bytes: imgBytes,
          size: imgBytes.length,
          extension: 'png',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TrainerRegistrationScreen(
            trainerService: mockTrainerService,
            authService: mockAuthService,
            storageService: storageService,
            pickerService: mockPickerService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Upload file
      final uploadBtn = find.byKey(const Key('upload_certificate_button'));
      await tester.ensureVisible(uploadBtn);
      await tester.tap(uploadBtn);
      await tester.pumpAndSettle();

      expect(find.text('cpt_badge.png'), findsOneWidget);
      expect(find.text('Attached'), findsOneWidget);

      // Fill required fields
      final nameField =
          find.widgetWithText(TextFormField, 'e.g. Alex Mercer, CSCS');
      await tester.ensureVisible(nameField);
      await tester.enterText(nameField, 'Offline Coach');

      final bioField = find.widgetWithText(
        TextFormField,
        'Describe your coaching style and results...',
      );
      await tester.ensureVisible(bioField);
      await tester.enterText(
        bioField,
        'Specializing in calisthenics and athletic bodyweight conditioning.',
      );

      // Submit registration
      final submitButton = find.text('Complete Coach Registration');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Verify persisted certifications contains resilient base64 preview URL
      expect(mockTrainerService.lastCertifications, isNotNull);
      expect(mockTrainerService.lastCertifications!.length, 1);
      expect(
        mockTrainerService.lastCertifications!.first
            .startsWith('data:image/png;base64,'),
        isTrue,
      );
    });

    testWidgets(
        'Editing profile: Pre-populates existing text credentials and document URLs into cards',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const existing = TrainerProfile(
        id: 'trainer-99',
        userId: 'user-99',
        displayName: 'Existing Coach',
        bio:
            'Over fifteen years coaching elite endurance athletes across marathons.',
        hourlyRate: 2000,
        experienceYears: 15,
        certifications: <String>[
          'USATF-Level-2',
          'https://supabase.pulsefit.io/storage/v1/object/public/trainer-certifications/user-99/marathon_cert.pdf',
        ],
        specialties: <String>['HIIT'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TrainerRegistrationScreen(
            existingProfile: existing,
            trainerService: _MockTrainerService(),
            authService: _MockAuthService(mockUserId: 'user-99'),
            storageService: _MockStorageService(),
            pickerService: _MockPickerService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Text credential should be in a chip
      expect(find.text('USATF-Level-2'), findsOneWidget);

      // Document URL should be parsed and rendered as an attachment card
      expect(find.text('marathon_cert.pdf'), findsOneWidget);
      expect(find.text('PDF Ready'), findsOneWidget);

      // User can remove attached document card
      final removeDocBtn = find.byTooltip('Remove document');
      await tester.ensureVisible(removeDocBtn);
      await tester.tap(removeDocBtn);
      await tester.pumpAndSettle();

      expect(find.text('marathon_cert.pdf'), findsNothing);
      expect(find.text('Removed "marathon_cert.pdf".'), findsOneWidget);
    });

    testWidgets(
        'Upload error resilience: Asynchronous storage exception is caught, updates card with error, and shows SnackBar',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockTrainerService = _MockTrainerService();
      final mockAuthService = _MockAuthService(mockUserId: 'trainer-err-1');
      final failingStorageService = _MockStorageService(shouldFail: true);
      final dummyPdfBytes = Uint8List.fromList([1, 2, 3]);
      final mockPickerService = _MockPickerService(
        fileToReturn: CertificationAttachment(
          id: 'picked-err',
          name: 'cert_will_fail.pdf',
          bytes: dummyPdfBytes,
          size: dummyPdfBytes.length,
          extension: 'pdf',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TrainerRegistrationScreen(
            trainerService: mockTrainerService,
            authService: mockAuthService,
            storageService: failingStorageService,
            pickerService: mockPickerService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final uploadBtn = find.byKey(const Key('upload_certificate_button'));
      await tester.ensureVisible(uploadBtn);
      await tester.tap(uploadBtn);
      await tester.pumpAndSettle();

      // Should show SnackBar with error message
      expect(find.textContaining('Failed to upload "cert_will_fail.pdf"'),
          findsOneWidget);

      // Card should render error icon and error text rather than 'PDF Ready'
      expect(find.text('cert_will_fail.pdf'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      expect(find.text('PDF Ready'), findsNothing);
    });

    testWidgets(
        'Submission guard: Prevents submission and warns if attachment upload is still in-flight',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockTrainerService = _MockTrainerService();
      final mockAuthService = _MockAuthService(mockUserId: 'trainer-inflight');
      final mockPickerService = _MockPickerService();

      final uploadCompleter = Completer<String>();
      final delayedStorage = _DelayedStorageService(uploadCompleter.future);
      mockPickerService.fileToReturn = CertificationAttachment(
        id: 'picked-pending',
        name: 'pending.pdf',
        bytes: Uint8List.fromList([1, 2, 3]),
        size: 3,
        extension: 'pdf',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TrainerRegistrationScreen(
            trainerService: mockTrainerService,
            authService: mockAuthService,
            storageService: delayedStorage,
            pickerService: mockPickerService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final nameField =
          find.widgetWithText(TextFormField, 'e.g. Alex Mercer, CSCS');
      await tester.ensureVisible(nameField);
      await tester.enterText(nameField, 'Coach Rapid');

      final bioField = find.widgetWithText(
        TextFormField,
        'Describe your coaching style and results...',
      );
      await tester.ensureVisible(bioField);
      await tester.enterText(
        bioField,
        'Specializing in Olympic weightlifting with ten years of coaching experience.',
      );

      // Start upload
      final uploadBtn = find.byKey(const Key('upload_certificate_button'));
      await tester.ensureVisible(uploadBtn);
      await tester.tap(uploadBtn);
      await tester.pump(); // Advance to start upload, but don't settle because completer is uncompleted

      // Verify attachment is in uploading state
      expect(find.text('Uploading...'), findsOneWidget);

      // Attempt to submit while upload is in-flight
      final submitButton = find.text('Complete Coach Registration');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pump();

      // Submission should be blocked with prompt
      expect(
        find.text('Please wait for file upload to complete before saving.'),
        findsOneWidget,
      );
      expect(mockTrainerService.registeredProfile, isNull);

      // Now complete the upload
      uploadCompleter.complete('https://storage.pulsefit.io/uploaded.pdf');
      await tester.pumpAndSettle();

      expect(find.text('pending.pdf'), findsOneWidget);
      expect(find.text('PDF Ready'), findsOneWidget);
      expect(find.text('Uploading...'), findsNothing);
    });

    testWidgets(
        'Submission guard: Prevents submission and warns if attachment has unrecovered error',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockTrainerService = _MockTrainerService();
      final mockAuthService = _MockAuthService(mockUserId: 'trainer-guard-err');
      final failingStorageService = _MockStorageService(shouldFail: true);
      final mockPickerService = _MockPickerService(
        fileToReturn: CertificationAttachment(
          id: 'picked-guard-err',
          name: 'broken.pdf',
          bytes: Uint8List.fromList([1, 2]),
          size: 2,
          extension: 'pdf',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TrainerRegistrationScreen(
            trainerService: mockTrainerService,
            authService: mockAuthService,
            storageService: failingStorageService,
            pickerService: mockPickerService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Upload file that fails
      final uploadBtn = find.byKey(const Key('upload_certificate_button'));
      await tester.ensureVisible(uploadBtn);
      await tester.tap(uploadBtn);
      await tester.pumpAndSettle();

      // Dismiss upload error snackbar
      ScaffoldMessenger.of(tester.element(uploadBtn)).clearSnackBars();
      await tester.pumpAndSettle();

      // Fill required fields
      final nameField =
          find.widgetWithText(TextFormField, 'e.g. Alex Mercer, CSCS');
      await tester.ensureVisible(nameField);
      await tester.enterText(nameField, 'Coach Valid');

      final bioField = find.widgetWithText(
        TextFormField,
        'Describe your coaching style and results...',
      );
      await tester.ensureVisible(bioField);
      await tester.enterText(
        bioField,
        'Bio exceeding twenty characters for validation test purpose.',
      );

      // Attempt to submit
      final submitButton = find.text('Complete Coach Registration');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Submission should be blocked with warning
      expect(
        find.text('Please remove failed attachments before saving.'),
        findsOneWidget,
      );
      expect(mockTrainerService.registeredProfile, isNull);
    });

    testWidgets(
        'Removing an in-flight uploading attachment suppresses late upload completion feedback',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final uploadCompleter = Completer<String>();
      final delayedStorage = _DelayedStorageService(uploadCompleter.future);
      final mockPicker = _MockPickerService(
        fileToReturn: CertificationAttachment(
          id: 'picked-to-cancel',
          name: 'cancel_me.pdf',
          bytes: Uint8List.fromList([1, 2, 3]),
          size: 3,
          extension: 'pdf',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TrainerRegistrationScreen(
            trainerService: _MockTrainerService(),
            authService: _MockAuthService(),
            storageService: delayedStorage,
            pickerService: mockPicker,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap upload
      final uploadBtn = find.byKey(const Key('upload_certificate_button'));
      await tester.ensureVisible(uploadBtn);
      await tester.tap(uploadBtn);
      await tester.pump();

      expect(find.text('cancel_me.pdf'), findsOneWidget);
      expect(find.text('Uploading...'), findsOneWidget);

      // Now remove the uploading attachment before upload completes
      final removeBtn = find.byTooltip('Remove document');
      await tester.tap(removeBtn);
      await tester.pumpAndSettle();

      expect(find.text('cancel_me.pdf'), findsNothing);
      expect(find.text('Removed "cancel_me.pdf".'), findsOneWidget);

      // Now asynchronously complete the delayed upload
      uploadCompleter.complete('https://storage.pulsefit.io/cancel_me.pdf');
      await tester.pumpAndSettle();

      // No late "Attached cancel_me.pdf successfully!" snackbar should appear!
      expect(
        find.text('Attached "cancel_me.pdf" successfully!'),
        findsNothing,
      );
    });

    testWidgets(
        'Text credential chip displays workspace_premium_rounded credential icon and rejects case-insensitive duplicates',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: TrainerRegistrationScreen(
            trainerService: _MockTrainerService(),
            authService: _MockAuthService(),
            storageService: _MockStorageService(),
            pickerService: _MockPickerService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final certInput = find.byKey(const Key('certification_text_input'));
      final addButton = find.byKey(const Key('add_certification_button'));
      await tester.ensureVisible(addButton);

      await tester.enterText(certInput, 'NASM-CES');
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      // Verify chip has credential icon
      expect(find.text('NASM-CES'), findsOneWidget);
      expect(find.byIcon(Icons.workspace_premium_rounded), findsOneWidget);

      // Attempt to enter duplicate with lower case
      await tester.enterText(certInput, 'nasm-ces');
      await tester.tap(addButton);
      await tester.pump();

      expect(
        find.text('This credential has already been added.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'Re-picking a failed attachment replaces the failed entry and passes explicit mimeType to storageService',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockStorage = _MockStorageService(shouldFail: true);
      final mockPicker = _MockPickerService(
        fileToReturn: CertificationAttachment(
          id: 'fail-1',
          name: 'retry_cert.pdf',
          bytes: Uint8List.fromList([1, 2, 3]),
          size: 3,
          extension: 'pdf',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TrainerRegistrationScreen(
            trainerService: _MockTrainerService(),
            authService: _MockAuthService(),
            storageService: mockStorage,
            pickerService: mockPicker,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final uploadBtn = find.byKey(const Key('upload_certificate_button'));
      await tester.ensureVisible(uploadBtn);
      await tester.tap(uploadBtn);
      await tester.pumpAndSettle();

      // Card is in error state
      expect(find.text('retry_cert.pdf'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);

      // Configure storage to succeed and re-pick the same file
      mockStorage.shouldFail = false;
      mockStorage.publicUrlToReturn =
          'https://supabase.pulsefit.io/storage/v1/object/public/trainer-certifications/user/retry_cert.pdf';

      // Re-create picker returning same file
      mockPicker.fileToReturn = CertificationAttachment(
        id: 'retry-success',
        name: 'retry_cert.pdf',
        bytes: Uint8List.fromList([1, 2, 3]),
        size: 3,
        extension: 'pdf',
      );

      // Tapping upload again does NOT reject with "already attached" because previous was in error state
      await tester.tap(uploadBtn);
      await tester.pumpAndSettle();

      expect(find.text('retry_cert.pdf'), findsOneWidget);
      expect(mockStorage.lastUploadedMimeType, 'application/pdf');
    });

    testWidgets(
        'Maintains consistent session userId between upload and registration in unauthenticated sessions',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockTrainerService = _MockTrainerService();
      final mockStorage = _MockStorageService();
      final mockPicker = _MockPickerService(
        fileToReturn: CertificationAttachment(
          id: 'test-session-file',
          name: 'session_cert.pdf',
          bytes: Uint8List.fromList([1, 2, 3]),
          size: 3,
          extension: 'pdf',
        ),
      );

      // Null or empty currentUserId
      final unauthService = _MockAuthService(mockUserId: '');

      await tester.pumpWidget(
        MaterialApp(
          home: TrainerRegistrationScreen(
            trainerService: mockTrainerService,
            authService: unauthService,
            storageService: mockStorage,
            pickerService: mockPicker,
            isAnonymous: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Upload file
      final uploadBtn = find.byKey(const Key('upload_certificate_button'));
      await tester.ensureVisible(uploadBtn);
      await tester.tap(uploadBtn);
      await tester.pumpAndSettle();

      expect(mockStorage.lastUploadedUserId, isNotNull);
      final uploadedUserId = mockStorage.lastUploadedUserId!;

      // Fill in required fields
      final nameField =
          find.widgetWithText(TextFormField, 'e.g. Alex Mercer, CSCS');
      await tester.ensureVisible(nameField);
      await tester.enterText(nameField, 'Coach Unauth');

      final bioField = find.widgetWithText(
        TextFormField,
        'Describe your coaching style and results...',
      );
      await tester.ensureVisible(bioField);
      await tester.enterText(
        bioField,
        'Experienced coach specializing in conditioning and functional training.',
      );

      // Submit
      final submitBtn = find.text('Complete Coach Registration');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(mockTrainerService.registeredProfile, isNotNull);
      expect(
        mockTrainerService.registeredProfile!.userId,
        equals(uploadedUserId),
      );
    });
  });
}
