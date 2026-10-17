import 'package:file_picker/file_picker.dart';
import 'package:fitness_app/features/trainers/models/certification_attachment.dart';
import 'package:flutter/foundation.dart';

typedef FilePickerHandler = Future<FilePickerResult?> Function({
  FileType type,
  List<String>? allowedExtensions,
  bool withData,
  bool cancelUploadOnWindowBlur,
});

/// Service responsible for picking certification documents and images
/// (PDF, PNG, JPG, JPEG) on both Web and Mobile platforms.
class CertificationPickerService {
  CertificationPickerService({
    this.allowedExtensions = defaultAllowedExtensions,
    this.pickFilesHandler,
  });

  final List<String> allowedExtensions;
  final FilePickerHandler? pickFilesHandler;
  Object? lastError;

  static const List<String> defaultAllowedExtensions = <String>[
    'pdf',
    'png',
    'jpg',
    'jpeg',
  ];

  /// Sanitizes allowed extensions by stripping leading/trailing dots, wildcards (*),
  /// whitespace, lowercasing, and ensuring only alphanumeric tokens are retained.
  static List<String> sanitizeExtensions(List<String> extensions) {
    return extensions
        .map(
          (ext) => ext
              .trim()
              .replaceAll(RegExp(r'^[*.\s]+'), '')
              .replaceAll(RegExp(r'[*.\s]+$'), '')
              .replaceAll(RegExp(r'\s+'), '')
              .toLowerCase(),
        )
        .where((ext) => ext.isNotEmpty && RegExp(r'^[a-z0-9]+$').hasMatch(ext))
        .toSet()
        .toList();
  }

  /// Formats a list of file extensions into a clean HTML accept string
  /// without leading whitespace or invalid filter formatting for Windows Shell / Edge.
  /// Example: ['pdf', 'png', 'jpg', 'jpeg'] -> '.pdf,.png,.jpg,.jpeg'
  static String formatAcceptString(List<String> extensions) {
    final sanitized = sanitizeExtensions(extensions);
    if (sanitized.isEmpty) return '';
    return sanitized.map((ext) => '.$ext').join(',');
  }

  Future<CertificationAttachment?> pickCertification() async {
    lastError = null;
    try {
      if (kIsWeb) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
      final sanitized = sanitizeExtensions(allowedExtensions);
      final result = await (pickFilesHandler != null
          ? pickFilesHandler!(
              type: FileType.custom,
              allowedExtensions: sanitized,
              withData: true,
              cancelUploadOnWindowBlur: false,
            )
          : FilePicker.pickFiles(
              type: FileType.custom,
              allowedExtensions: sanitized,
              withData: true,
              cancelUploadOnWindowBlur: false,
            ));

      if (result == null || result.files.isEmpty) return null;

      final file = result.files.first;
      var rawName = file.name.trim();
      while (rawName.endsWith('.')) {
        rawName = rawName.substring(0, rawName.length - 1).trim();
      }
      final bytes = file.bytes;
      final size = file.size > 0 ? file.size : (bytes?.length ?? 0);

      String ext = '';
      if (rawName.contains('.')) {
        final candidate = rawName.split('.').last.trim().toLowerCase();
        if (candidate.isNotEmpty &&
            (const ['pdf', 'png', 'jpg', 'jpeg', 'webp'].contains(candidate) ||
                sanitized.contains(candidate))) {
          ext = candidate;
        }
      }

      if (ext.isEmpty && bytes != null && bytes.length >= 3) {
        if (bytes.length >= 4 &&
            bytes[0] == 0x25 &&
            bytes[1] == 0x50 &&
            bytes[2] == 0x44 &&
            bytes[3] == 0x46) {
          ext = 'pdf';
        } else if (bytes.length >= 4 &&
            bytes[0] == 0x89 &&
            bytes[1] == 0x50 &&
            bytes[2] == 0x4E &&
            bytes[3] == 0x47) {
          ext = 'png';
        } else if (bytes[0] == 0xFF &&
            bytes[1] == 0xD8 &&
            bytes[2] == 0xFF) {
          ext = 'jpg';
        } else if (bytes.length >= 12 &&
            bytes[0] == 0x52 &&
            bytes[1] == 0x49 &&
            bytes[2] == 0x46 &&
            bytes[3] == 0x46 &&
            bytes[8] == 0x57 &&
            bytes[9] == 0x45 &&
            bytes[10] == 0x42 &&
            bytes[11] == 0x50) {
          ext = 'webp';
        }
      }

      if (ext.isEmpty &&
          file.extension != null &&
          file.extension != file.name &&
          file.extension!.trim().isNotEmpty) {
        final cleanExt = file.extension!
            .trim()
            .replaceAll(RegExp(r'^[*.\s]+'), '')
            .replaceAll(RegExp(r'[*.\s]+$'), '')
            .toLowerCase();
        if (cleanExt.isNotEmpty && RegExp(r'^[a-z0-9]+$').hasMatch(cleanExt)) {
          ext = cleanExt;
        }
      }

      if (ext.isEmpty && rawName.contains('.')) {
        final candidate = rawName.split('.').last.trim().toLowerCase();
        if (candidate.isNotEmpty &&
            RegExp(r'^[a-z0-9]+$').hasMatch(candidate)) {
          ext = candidate;
        }
      }

      if (ext.isEmpty) {
        ext = 'pdf';
      }

      final resolvedName = rawName.isNotEmpty ? rawName : 'certificate.$ext';

      return CertificationAttachment(
        id:
            'cert-${DateTime.now().millisecondsSinceEpoch}-${resolvedName.hashCode}',
        name: resolvedName,
        bytes: bytes,
        size: size,
        extension: ext,
      );
    } catch (e) {
      lastError = e;
      debugPrint('CertificationPickerService error: $e');
      return null;
    }
  }
}

