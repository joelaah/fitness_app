import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Modern collapsible Navigation Rail for PulseFit AI on desktop/wide screens (>= 900px).
class AdaptiveNavigationRail extends StatelessWidget {
  const AdaptiveNavigationRail({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.isExtended,
    required this.onToggleExtended,
    required this.onOpenChat,
    required this.onOpenPayments,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool isExtended;
  final VoidCallback onToggleExtended;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenPayments;

  static const List<_RailDestinationItem> _destinations = [
    _RailDestinationItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: 'Home',
    ),
    _RailDestinationItem(
      icon: Icons.fitness_center_outlined,
      selectedIcon: Icons.fitness_center_rounded,
      label: 'Routines',
    ),
    _RailDestinationItem(
      icon: Icons.auto_awesome_outlined,
      selectedIcon: Icons.auto_awesome_rounded,
      label: 'AI Coach',
    ),
    _RailDestinationItem(
      icon: Icons.sports_gymnastics_outlined,
      selectedIcon: Icons.sports_gymnastics_rounded,
      label: 'Trainers',
    ),
    _RailDestinationItem(
      icon: Icons.list_alt,
      selectedIcon: Icons.list_alt_rounded,
      label: 'Exercises',
    ),
    _RailDestinationItem(
      icon: Icons.history_outlined,
      selectedIcon: Icons.history_rounded,
      label: 'History',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final width = isExtended ? 240.0 : 76.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: width,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          right: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: ClipRect(
        child: OverflowBox(
          minWidth: 0,
          maxWidth: 240,
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: Column(
              crossAxisAlignment: isExtended
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                _buildHeader(context),
                const Divider(color: AppColors.border, height: 1),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemCount: _destinations.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (ctx, index) {
                      final dest = _destinations[index];
                      final isSelected = selectedIndex == index;
                      return _buildDestinationTile(
                        context,
                        dest: dest,
                        index: index,
                        isSelected: isSelected,
                      );
                    },
                  ),
                ),
                const Divider(color: AppColors.border, height: 1),
                _buildFooterActions(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    if (!isExtended) {
      return Container(
        height: 64,
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        child: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withAlpha(80)),
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          tooltip: 'Expand Sidebar',
          onPressed: onToggleExtended,
        ),
      );
    }

    return Container(
      height: 64,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withAlpha(80)),
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'PulseFit AI',
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.chevron_left_rounded,
              color: AppColors.textSecondary,
            ),
            tooltip: 'Collapse Sidebar',
            onPressed: onToggleExtended,
          ),
        ],
      ),
    );
  }

  Widget _buildDestinationTile(
    BuildContext context, {
    required _RailDestinationItem dest,
    required int index,
    required bool isSelected,
  }) {
    final icon = isSelected ? dest.selectedIcon : dest.icon;
    final iconColor = isSelected ? AppColors.primary : AppColors.textSecondary;

    return Material(
      color: isSelected ? AppColors.primary.withAlpha(28) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onDestinationSelected(index),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: AppColors.primary.withAlpha(80))
                : Border.all(color: Colors.transparent),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isExtended ? 12 : 8,
            vertical: 12,
          ),
          child: Row(
            mainAxisAlignment:
                isExtended ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              if (isSelected && isExtended)
                Container(
                  width: 3.5,
                  height: 20,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: index % 2 == 0
                        ? AppColors.primary
                        : const Color(0xFF06B6D4), // Mint or Cyan
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              Icon(icon, color: iconColor, size: 22),
              if (isExtended) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    dest.label,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooterActions(BuildContext context) {
    if (!isExtended) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            IconButton(
              key: const Key('chat_rail_action'),
              icon: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: AppColors.textPrimary,
                size: 22,
              ),
              tooltip: 'Encrypted Messages',
              onPressed: onOpenChat,
            ),
            const SizedBox(height: 6),
            IconButton(
              key: const Key('payments_rail_action'),
              icon: const Icon(
                Icons.receipt_long_outlined,
                color: AppColors.textPrimary,
                size: 22,
              ),
              tooltip: 'Payment History',
              onPressed: onOpenPayments,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              key: const Key('chat_rail_action'),
              borderRadius: BorderRadius.circular(10),
              onTap: onOpenChat,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Messages',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'E2EE',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              key: const Key('payments_rail_action'),
              borderRadius: BorderRadius.circular(10),
              onTap: onOpenPayments,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.receipt_long_outlined,
                      color: Color(0xFF06B6D4),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Payments',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RailDestinationItem {
  const _RailDestinationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}
