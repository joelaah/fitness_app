import 'dart:convert';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// Represents an attached certification document or image.
class CertificationAttachment extends Equatable {
  const CertificationAttachment({
    required this.id,
    required this.name,
    this.bytes,
    this.size = 0,
    required this.extension,
    this.storageUrl,
    this.isUploading = false,
    this.error,
  });

  /// Factory constructor to reconstruct an attachment from an existing URL
  /// (e.g. Supabase Storage public URL or base64 data URI).
  factory CertificationAttachment.fromUrl(String rawUrl, {String? id}) {
    final url = rawUrl.trim();
    var fileName = 'certification';
    var ext = 'pdf';
    Uint8List? parsedBytes;

    if (url.startsWith('data:')) {
      final commaIndex = url.indexOf(',');
      final rawHeader =
          url.substring(0, commaIndex >= 0 ? commaIndex : url.length);
      final header = rawHeader.toLowerCase();

      final nameMatch = RegExp(r'name=([^;]+)', caseSensitive: false)
          .firstMatch(rawHeader);
      if (nameMatch != null) {
        fileName = Uri.decodeComponent(nameMatch.group(1)!);
        if (fileName.contains('.')) {
          ext = fileName.split('.').last.toLowerCase();
        }
      }

      if (header.contains('image/png')) {
        ext = 'png';
        if (fileName == 'certification') fileName = 'certificate.png';
      } else if (header.contains('image/jpeg') || header.contains('image/jpg')) {
        ext = 'jpeg';
        if (fileName == 'certification') fileName = 'certificate.jpg';
      } else if (header.contains('image/webp')) {
        ext = 'webp';
        if (fileName == 'certification') fileName = 'certificate.webp';
      } else if (header.contains('application/pdf')) {
        ext = 'pdf';
        if (fileName == 'certification') fileName = 'certificate.pdf';
      }

      if (commaIndex >= 0) {
        try {
          final cleanPayload = url
              .substring(commaIndex + 1)
              .trim()
              .replaceAll('\n', '')
              .replaceAll('\r', '');
          parsedBytes = base64Decode(cleanPayload);
        } catch (_) {}
      }
    } else {
      final uri = Uri.tryParse(url);
      if (uri != null && uri.pathSegments.isNotEmpty) {
        final last = uri.pathSegments.where((s) => s.isNotEmpty).lastOrNull;
        if (last != null) {
          fileName = Uri.decodeComponent(last);
          if (last.contains('.')) {
            ext = last.split('.').last.toLowerCase();
          }
        }
      }
    }

    return CertificationAttachment(
      id: id ?? 'url-${url.hashCode}',
      name: fileName,
      bytes: parsedBytes,
      size: parsedBytes?.length ?? 0,
      extension: ext,
      storageUrl: url,
    );
  }

  final String id;
  final String name;
  final Uint8List? bytes;
  final int size;
  final String extension;
  final String? storageUrl;
  final bool isUploading;
  final String? error;

  bool get isPdf => extension.toLowerCase() == 'pdf';
  bool get isImage =>
      const ['png', 'jpg', 'jpeg', 'webp'].contains(extension.toLowerCase());

  String get formattedSize {
    if (size <= 0) return '';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  CertificationAttachment copyWith({
    String? id,
    String? name,
    Uint8List? bytes,
    int? size,
    String? extension,
    String? storageUrl,
    bool? isUploading,
    String? error,
  }) {
    return CertificationAttachment(
      id: id ?? this.id,
      name: name ?? this.name,
      bytes: bytes ?? this.bytes,
      size: size ?? this.size,
      extension: extension ?? this.extension,
      storageUrl: storageUrl ?? this.storageUrl,
      isUploading: isUploading ?? this.isUploading,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        bytes,
        size,
        extension,
        storageUrl,
        isUploading,
        error,
      ];
}
