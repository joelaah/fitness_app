import 'package:file_picker/file_picker.dart';
import 'package:fitness_app/features/trainers/models/certification_attachment.dart';
import 'package:flutter/foundation.dart';

/// Service responsible for picking certification documents and images
/// (PDF, PNG, JPG, JPEG) on both Web and Mobile platforms.
class CertificationPickerService {
  const CertificationPickerService();

  Future<CertificationAttachment?> pickCertification() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return null;

      final file = result.files.first;
      final name = file.name;
      final bytes = file.bytes;
      final size = file.size;
      final ext = file.extension ??
          (name.contains('.') ? name.split('.').last : 'pdf');

      return CertificationAttachment(
        id: 'cert-${DateTime.now().millisecondsSinceEpoch}-${name.hashCode}',
        name: name,
        bytes: bytes,
        size: size,
        extension: ext.toLowerCase(),
      );
    } catch (e) {
      debugPrint('CertificationPickerService error: $e');
      return null;
    }
  }
}
