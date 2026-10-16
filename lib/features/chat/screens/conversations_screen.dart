import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/core/widgets/empty_state_widget.dart';
import 'package:fitness_app/features/chat/bloc/chat_bloc.dart';
import 'package:fitness_app/features/chat/bloc/chat_event.dart';
import 'package:fitness_app/features/chat/bloc/chat_state.dart';
import 'package:fitness_app/features/chat/models/chat_conversation.dart';
import 'package:fitness_app/features/chat/screens/chat_screen.dart';
import 'package:fitness_app/features/trainers/screens/trainer_discovery_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Conversation list inbox displaying active coach chats, unread badges,
/// last message timestamp, search filtering, and empty states.
class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({
    super.key,
    this.chatBloc,
  });

  final ChatBloc? chatBloc;

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      (widget.chatBloc ?? context.read<ChatBloc>())
          .add(const LoadConversations());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatRelativeTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final local = timestamp.toLocal();
    final difference = now.difference(local);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (now.day == local.day &&
        now.month == local.month &&
        now.year == local.year) {
      return DateFormat('h:mm a').format(local);
    } else if (now.subtract(const Duration(days: 1)).day == local.day) {
      return 'Yesterday';
    } else if (now.year == local.year) {
      return DateFormat('MMM d').format(local);
    } else {
      return DateFormat('MM/dd/yy').format(local);
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Encrypted Messages',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Row(
              children: [
                const Icon(
                  Icons.lock_rounded,
                  size: 11,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Signal-Style E2EE Active',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Search coach or message...',
                  hintStyle: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: _searchController.clear,
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),

          // Conversation List
          Expanded(
            child: BlocBuilder<ChatBloc, ChatState>(
              bloc: widget.chatBloc,
              builder: (context, state) {
                if (state is ChatConversationsLoading) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  );
                }

                var conversations = const <ChatConversation>[];
                if (state is ChatConversationsLoaded) {
                  conversations = state.conversations;
                }

                // Filter by search query
                final filtered = conversations.where((c) {
                  if (_searchQuery.isEmpty) return true;
                  final name = (c.trainerName ?? '').toLowerCase();
                  final lastMsg = (c.lastMessagePreview ?? '').toLowerCase();
                  return name.contains(_searchQuery) ||
                      lastMsg.contains(_searchQuery);
                }).toList();

                if (conversations.isEmpty) {
                  return Center(
                    child: EmptyStateWidget(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'No Active Chats',
                      description:
                          'Connect with personal fitness coaches to receive '
                          'custom workout plans and direct encrypted support.',
                      buttonText: 'Browse Trainers',
                      onButtonPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute<dynamic>(
                            builder: (context) =>
                                const TrainerDiscoveryScreen(),
                          ),
                        );
                      },
                    ),
                  );
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      'No conversations found for "$_searchQuery"',
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  onRefresh: () async {
                    (widget.chatBloc ?? context.read<ChatBloc>())
                        .add(const LoadConversations(forceRefresh: true));
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => const Divider(
                      color: AppColors.border,
                      height: 1,
                    ),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final name = item.trainerName ?? 'Coach';
                      final initials = _getInitials(name);
                      final unread = item.unreadCount;
                      final timestampStr = _formatRelativeTimestamp(
                        item.updatedAt,
                      );

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            ChatBloc? bloc = widget.chatBloc;
                            if (bloc == null || bloc.isClosed) {
                              try {
                                bloc = context.read<ChatBloc>();
                              } catch (_) {}
                            }

                            final isTemplate = item.trainerId.startsWith('trainer-') ||
                                item.trainerId.startsWith('mock-') ||
                                (item.trainerUserId ?? '').startsWith('user-coach-') ||
                                name == 'Bob Trainer' ||
                                name == 'Charlie Yoga' ||
                                name == 'Diana Vance';

                            Navigator.push(
                              context,
                              MaterialPageRoute<dynamic>(
                                builder: (context) => ChatScreen(
                                  conversationId: item.id,
                                  trainerId: item.trainerId,
                                  trainerUserId: item.trainerUserId,
                                  trainerName: name,
                                  initialConversation: item,
                                  chatBloc: bloc,
                                  isTemplateCoach: isTemplate,
                                ),
                              ),
                            ).then((_) {
                              if (mounted) {
                                final activeBloc = bloc ??
                                    () {
                                      try {
                                        return context.read<ChatBloc>();
                                      } catch (_) {
                                        return null;
                                      }
                                    }();
                                if (activeBloc != null && !activeBloc.isClosed) {
                                  activeBloc.add(
                                    const LoadConversations(forceRefresh: true),
                                  );
                                }
                              }
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 8,
                            ),
                            child: Row(
                              children: [
                                // Avatar with neon outline
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: AppColors.coverPull,
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    border: Border.all(
                                      color: unread > 0
                                          ? AppColors.primary
                                          : AppColors.border,
                                      width: 1.5,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    initials,
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              name,
                                              style: GoogleFonts.poppins(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.textPrimary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Text(
                                            timestampStr,
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: unread > 0
                                                  ? AppColors.primary
                                                  : AppColors.textSecondary,
                                              fontWeight: unread > 0
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.lastMessagePreview ??
                                                  '🔒 Encrypted conversation',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                color: unread > 0
                                                    ? AppColors.textPrimary
                                                    : AppColors.textSecondary,
                                                fontWeight: unread > 0
                                                    ? FontWeight.w600
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                          ),
                                          if (unread > 0) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 7,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                unread > 99
                                                    ? '99+'
                                                    : unread.toString(),
                                                style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: const Color(
                                                    0xFF0F172A,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
