import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/features/chat/bloc/chat_bloc.dart';
import 'package:fitness_app/features/chat/bloc/chat_event.dart';
import 'package:fitness_app/features/chat/bloc/chat_state.dart';
import 'package:fitness_app/features/chat/models/chat_conversation.dart';
import 'package:fitness_app/features/chat/models/chat_message.dart';
import 'package:fitness_app/features/chat/widgets/chat_message_bubble.dart';
import 'package:fitness_app/features/chat/widgets/e2ee_security_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// 1-on-1 End-to-End Encrypted Chat Screen with auto-scroll, date dividers,
/// lock indicator badge, typing status, and responsive send input bar.
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    required this.conversationId,
    required this.trainerId,
    required this.trainerName,
    super.key,
    this.trainerUserId,
    this.trainerSpecialty,
    this.initialConversation,
    this.chatBloc,
  });

  final String conversationId;
  final String trainerId;
  final String? trainerUserId;
  final String trainerName;
  final String? trainerSpecialty;
  final ChatConversation? initialConversation;
  final ChatBloc? chatBloc;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);

    // Initial load / subscription
    WidgetsBinding.instance.addPostFrameCallback((_) {
      (widget.chatBloc ?? context.read<ChatBloc>()).add(
        OpenConversation(
          conversationId: widget.conversationId,
          trainerId: widget.trainerId,
          trainerUserId: widget.trainerUserId,
          trainerName: widget.trainerName,
        ),
      );
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _textController
      ..removeListener(_onTextChanged)
      ..dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _textController.text.trim();
    if (text.isNotEmpty != _canSend) {
      setState(() {
        _canSend = text.isNotEmpty;
      });
    }
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        if (animated) {
          _scrollController.animateTo(
            maxScroll,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(maxScroll);
        }
      }
    });
  }

  void _onSendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    (widget.chatBloc ?? context.read<ChatBloc>()).add(
      SendMessage(
        conversationId: widget.conversationId,
        plaintext: text,
        recipientUserId: widget.trainerUserId ?? widget.trainerId,
      ),
    );
    _scrollToBottom();
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty
        ? name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase()
        : 'PT';
  }

  String _formatDateSeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else if (now.year == date.year) {
      return DateFormat('EEEE, MMM d').format(date);
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials(widget.trainerName);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () {
            // Strictly adhering to flutter-navigation-rules: clean pop
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            // Coach Avatar with Online / E2EE Accent
            Stack(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: AppColors.coverPull,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: AppColors.secondaryAccent,
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.surface,
                        width: 1.8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.trainerName,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.verified_rounded,
                        size: 15,
                        color: AppColors.secondaryAccent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const E2eeSecurityBanner(compact: true),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.shield_outlined),
            color: AppColors.primary,
            tooltip: 'Encryption Verification',
            onPressed: () => E2eeSecurityBanner.showDetails(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: BlocConsumer<ChatBloc, ChatState>(
        bloc: widget.chatBloc,
        listener: (context, state) {
          if (state is ChatRoomActive) {
            _scrollToBottom();
          }
        },
        builder: (context, state) {
          var messages = const <ChatMessage>[];
          var isOtherUserTyping = false;
          var isLoading = false;

          if (state is ChatRoomLoading) {
            isLoading = true;
          } else if (state is ChatRoomActive) {
            messages = state.messages;
            isOtherUserTyping = state.isOtherUserTyping;
          }

          return Column(
            children: [
              // Top informational zero-knowledge pill
              const E2eeSecurityBanner(),

              // Chat Messages Stream List
              Expanded(
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                      )
                    : messages.isEmpty
                    ? _buildEmptyChatPrompt()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final isFirst = index == 0;
                          final prevMessage = !isFirst
                              ? messages[index - 1]
                              : null;

                          final showDateDivider =
                              isFirst ||
                              (prevMessage != null &&
                                  (prevMessage.createdAt.day !=
                                          message.createdAt.day ||
                                      prevMessage.createdAt.month !=
                                          message.createdAt.month ||
                                      prevMessage.createdAt.year !=
                                          message.createdAt.year));

                          return Column(
                            children: [
                              if (showDateDivider)
                                _buildDateSeparator(message.createdAt),
                              ChatMessageBubble(
                                message: message,
                                senderName: widget.trainerName,
                                onRetry: () {
                                  (widget.chatBloc ?? context.read<ChatBloc>())
                                      .add(
                                    RetrySendMessage(
                                      clientUuid: message.clientUuid,
                                    ),
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),
              ),

              // Ephemeral Typing Indicator Bubble
              if (isOtherUserTyping) _buildTypingIndicator(),

              // Bottom Input Bar
              _buildInputBar(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
          width: 0.8,
        ),
      ),
      child: Text(
        _formatDateSeparator(date),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildEmptyChatPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Secure Channel Established',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start your conversation with ${widget.trainerName}. '
              'Your workout plans, check-ins, and questions are secured.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${widget.trainerName} is typing',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(width: 6),
                const SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.secondaryAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(
            color: AppColors.border,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: AppColors.border,
                  ),
                ),
                child: TextField(
                  controller: _textController,
                  minLines: 1,
                  maxLines: 4,
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Message end-to-end encrypted...',
                    hintStyle: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onSubmitted: (_) => _onSendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _canSend ? AppColors.primary : AppColors.surfaceElevated,
                shape: BoxShape.circle,
                boxShadow: _canSend
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: IconButton(
                icon: Icon(
                  Icons.arrow_upward_rounded,
                  color: _canSend
                      ? const Color(0xFF0F172A)
                      : AppColors.textSecondary,
                  size: 22,
                ),
                tooltip: 'Send Encrypted Message',
                onPressed: _canSend ? _onSendMessage : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
