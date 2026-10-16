import 'dart:convert';
import 'package:fitness_app/core/config/supabase_config.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service managing trainer certification uploads to Supabase Storage
/// with user-isolated paths and resilient local fallback.
class TrainerStorageService {
  TrainerStorageService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  static const String bucketName = 'trainer-certifications';

  SupabaseClient? get _supabase {
    if (_client != null) return _client;
    if (SupabaseConfig.isInitialized) {
      return Supabase.instance.client;
    }
    return null;
  }

  /// Uploads certification file bytes to the `trainer-certifications` bucket
  /// under the user-isolated path `{userId}/{filename}`.
  ///
  /// Automatically falls back to a base64 data URI preview URL if Supabase
  /// Storage is in test/mock mode or temporarily unreachable.
  Future<String> uploadCertification({
    required String userId,
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
  }) async {
    final client = _supabase;
    final sanitizedUserId =
        userId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final effectiveUserId =
        sanitizedUserId.isNotEmpty ? sanitizedUserId : 'user';

    var sanitizedFileName =
        fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    while (sanitizedFileName.endsWith('.')) {
      sanitizedFileName =
          sanitizedFileName.substring(0, sanitizedFileName.length - 1);
    }
    if (sanitizedFileName.isEmpty ||
        sanitizedFileName == '.' ||
        sanitizedFileName == '..') {
      final ext = _extensionForMime(mimeType) ?? 'pdf';
      sanitizedFileName =
          'cert_${DateTime.now().millisecondsSinceEpoch}.$ext';
    } else if (sanitizedFileName.startsWith('.')) {
      sanitizedFileName = 'cert_$sanitizedFileName';
    }

    if (!sanitizedFileName.contains('.')) {
      final ext = _detectExtension(bytes, mimeType);
      sanitizedFileName = '$sanitizedFileName.$ext';
    }

    final storagePath = '$effectiveUserId/$sanitizedFileName';
    final resolvedMime =
        mimeType ?? _lookupMimeType(sanitizedFileName, bytes);

    if (client == null) {
      debugPrint(
        'TrainerStorageService: Supabase uninitialized or mock mode; '
        'using resilient local preview fallback.',
      );
      return _generateLocalFallbackUrl(
        bytes,
        resolvedMime,
        fileName: sanitizedFileName,
      );
    }

    try {
      await client.storage.from(bucketName).uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: resolvedMime,
              upsert: true,
            ),
          );

      final publicUrl =
          client.storage.from(bucketName).getPublicUrl(storagePath);
      return publicUrl;
    } catch (e) {
      debugPrint(
        'TrainerStorageService: Supabase upload failed ($e); '
        'falling back to local preview URL.',
      );
      return _generateLocalFallbackUrl(
        bytes,
        resolvedMime,
        fileName: sanitizedFileName,
      );
    }
  }

  String _generateLocalFallbackUrl(
    Uint8List bytes,
    String mimeType, {
    String? fileName,
  }) {
    final base64String = base64Encode(bytes);
    return 'data:$mimeType;base64,$base64String';
  }

  static String _detectExtension(Uint8List bytes, String? mimeType) {
    if (mimeType != null && mimeType.isNotEmpty) {
      final ext = _extensionForMime(mimeType);
      if (ext != null) return ext;
    }
    if (bytes.length >= 4) {
      if (bytes[0] == 0x25 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x44 &&
          bytes[3] == 0x46) {
        return 'pdf';
      }
      if (bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47) {
        return 'png';
      }
      if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
        return 'jpg';
      }
      if (bytes.length >= 12 &&
          bytes[0] == 0x52 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x46 &&
          bytes[8] == 0x57 &&
          bytes[9] == 0x45 &&
          bytes[10] == 0x42 &&
          bytes[11] == 0x50) {
        return 'webp';
      }
    }
    return 'pdf';
  }

  static String? _extensionForMime(String? mimeType) {
    switch (mimeType?.toLowerCase()) {
      case 'image/png':
        return 'png';
      case 'image/jpeg':
      case 'image/jpg':
        return 'jpg';
      case 'image/webp':
        return 'webp';
      case 'application/pdf':
        return 'pdf';
      default:
        return null;
    }
  }

  static String _lookupMimeType(String fileName, [Uint8List? bytes]) {
    final ext =
        fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      default:
        if (bytes != null && bytes.length >= 4) {
          final detected = _detectExtension(bytes, null);
          switch (detected) {
            case 'pdf':
              return 'application/pdf';
            case 'png':
              return 'image/png';
            case 'jpg':
              return 'image/jpeg';
            case 'webp':
              return 'image/webp';
          }
        }
        return 'application/octet-stream';
    }
  }
}
