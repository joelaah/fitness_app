import 'dart:convert';
import 'dart:typed_data';

import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/features/trainers/models/certification_attachment.dart';
import 'package:flutter/material.dart';

/// Renders an attached certification document or image as a rich visual card
/// with file-type badges, thumbnail previews, file size, tap-to-preview,
/// and remove action.
class CertificationAttachmentCard extends StatelessWidget {
  const CertificationAttachmentCard({
    required this.attachment,
    required this.onPreview,
    required this.onRemove,
    super.key,
  });

  final CertificationAttachment attachment;
  final VoidCallback onPreview;
  final VoidCallback onRemove;

  Uint8List? _resolveThumbnailBytes() {
    if (attachment.bytes != null && attachment.bytes!.isNotEmpty) {
      return attachment.bytes;
    }
    final url = attachment.storageUrl;
    if (url != null && url.startsWith('data:')) {
      final comma = url.indexOf(',');
      if (comma >= 0) {
        try {
          final cleanPayload = url
              .substring(comma + 1)
              .trim()
              .replaceAll('\n', '')
              .replaceAll('\r', '');
          return base64Decode(cleanPayload);
        } catch (_) {}
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thumbBytes = _resolveThumbnailBytes();

    return Material(
      color: AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPreview,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.border,
            ),
          ),
          child: Row(
            children: [
              _buildLeadingBadge(thumbBytes),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      attachment.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (attachment.formattedSize.isNotEmpty) ...[
                          Text(
                            attachment.formattedSize,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            '•',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (attachment.isUploading) ...[
                          const SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Uploading...',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                            ),
                          ),
                        ] else if (attachment.error != null) ...[
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 12,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              attachment.error!,
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ] else ...[
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 12,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            attachment.isPdf ? 'PDF Ready' : 'Attached',
                            style: const TextStyle(
                              color: AppColors.success,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                tooltip: 'Remove document',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: onRemove,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeadingBadge(Uint8List? thumbBytes) {
    if (attachment.isPdf) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.redAccent.withValues(alpha: 0.3),
          ),
        ),
        alignment: Alignment.center,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.picture_as_pdf_rounded,
              color: Colors.redAccent,
              size: 20,
            ),
            Text(
              'PDF',
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 8,
                fontWeight: FontWeight.bold,
                height: 1.0,
              ),
            ),
          ],
        ),
      );
    }

    if (thumbBytes != null && thumbBytes.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          thumbBytes,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildGenericImageBadge(),
        ),
      );
    }

    if (attachment.isImage &&
        attachment.storageUrl != null &&
        (attachment.storageUrl!.startsWith('http') ||
            attachment.storageUrl!.startsWith('blob:'))) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          attachment.storageUrl!,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildGenericImageBadge(),
        ),
      );
    }

    return _buildGenericImageBadge();
  }

  Widget _buildGenericImageBadge() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_rounded,
        color: AppColors.primary,
        size: 20,
      ),
    );
  }
}
