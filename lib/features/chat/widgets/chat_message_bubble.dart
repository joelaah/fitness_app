import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/features/chat/models/chat_message.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Message bubble displaying outgoing vs incoming layout, message plaintext,
/// formatted timestamp, and delivery status checkmarks.
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    required this.message,
    super.key,
    this.isOutgoing,
    this.showSenderLabel = false,
    this.senderName,
    this.onRetry,
  });

  final ChatMessage message;
  final bool? isOutgoing;
  final bool showSenderLabel;
  final String? senderName;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final outgoing = isOutgoing ?? message.isOutgoing;
    final timeStr = DateFormat('h:mm a').format(message.createdAt.toLocal());
    final displayText = message.plaintext ?? '••• Decrypting message •••';
    final isFailed = message.deliveryStatus == MessageDeliveryStatus.failed;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: outgoing
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (showSenderLabel && !outgoing && senderName != null)
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 3),
              child: Text(
                senderName!,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondaryAccent,
                ),
              ),
            ),
          Row(
            mainAxisAlignment: outgoing
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (outgoing && isFailed) ...[
                IconButton(
                  icon: const Icon(
                    Icons.replay_rounded,
                    color: AppColors.error,
                    size: 18,
                  ),
                  tooltip: 'Retry sending message',
                  onPressed: onRetry,
                ),
              ],
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.78,
                    minWidth: 70,
                  ),
                  padding: const EdgeInsets.only(
                    left: 14,
                    right: 14,
                    top: 10,
                    bottom: 8,
                  ),
                  decoration: BoxDecoration(
                    color: outgoing ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(outgoing ? 18 : 4),
                      bottomRight: Radius.circular(outgoing ? 4 : 18),
                    ),
                    border: outgoing
                        ? null
                        : Border.all(
                            color: AppColors.secondaryAccent.withValues(
                              alpha: 0.35,
                            ),
                            width: 1.2,
                          ),
                    boxShadow: [
                      BoxShadow(
                        color: outgoing
                            ? AppColors.primary.withValues(alpha: 0.22)
                            : Colors.black.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: outgoing
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        displayText,
                        style: GoogleFonts.inter(
                          fontSize: 14.5,
                          height: 1.42,
                          // Dark Slate 900 for AAA contrast
                          color: outgoing
                              ? const Color(0xFF0F172A)
                              : AppColors.textPrimary,
                          fontWeight: outgoing
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            timeStr,
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              color: outgoing
                                  ? const Color(
                                      0xFF0F172A,
                                    ).withValues(alpha: 0.75)
                                  : AppColors.textSecondary,
                            ),
                          ),
                          if (outgoing) ...[
                            const SizedBox(width: 4),
                            _buildDeliveryStatusIcon(
                              message.deliveryStatus,
                              isRead: message.isRead,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (isFailed)
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 6),
              child: Text(
                'Delivery failed. Tap icon to retry.',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: AppColors.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDeliveryStatusIcon(
    MessageDeliveryStatus status, {
    required bool isRead,
  }) {
    const iconColor = Color(0xFF0F172A);

    if (isRead || status == MessageDeliveryStatus.read) {
      return const Icon(
        Icons.done_all_rounded,
        size: 14,
        color: iconColor,
      );
    }

    switch (status) {
      case MessageDeliveryStatus.sending:
        return const SizedBox(
          width: 10,
          height: 10,
          child: CircularProgressIndicator(
            strokeWidth: 1.4,
            valueColor: AlwaysStoppedAnimation<Color>(iconColor),
          ),
        );
      case MessageDeliveryStatus.sent:
        return const Icon(
          Icons.check_rounded,
          size: 14,
          color: iconColor,
        );
      case MessageDeliveryStatus.delivered:
        return const Icon(
          Icons.done_all_rounded,
          size: 14,
          color: iconColor,
        );
      case MessageDeliveryStatus.failed:
        return const Icon(
          Icons.error_outline_rounded,
          size: 14,
          color: AppColors.error,
        );
      case MessageDeliveryStatus.read:
        return const Icon(
          Icons.done_all_rounded,
          size: 14,
          color: iconColor,
        );
    }
  }
}
