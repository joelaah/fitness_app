import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/core/theme/app_spacing.dart';
import 'package:fitness_app/core/widgets/elevated_card.dart';
import 'package:fitness_app/core/widgets/empty_state_widget.dart';
import 'package:fitness_app/features/payments/bloc/payment_bloc.dart';
import 'package:fitness_app/features/payments/bloc/payment_event.dart';
import 'package:fitness_app/features/payments/bloc/payment_state.dart';
import 'package:fitness_app/features/payments/models/payment_transaction.dart';
import 'package:fitness_app/features/payments/services/payment_service.dart';
import 'package:fitness_app/features/payments/widgets/transaction_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Payment History Screen:
/// Tabbed view presenting user coaching payments and trainer net earnings
/// ledger. Includes status filters (All, Paid, Pending, Failed), search input,
/// and live 10% platform fee transparency metrics.
class PaymentHistoryScreen extends StatelessWidget {
  const PaymentHistoryScreen({
    super.key,
    this.isTrainerMode = false,
    this.paymentService,
  });

  final bool isTrainerMode;
  final PaymentService? paymentService;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PaymentBloc>(
      create: (ctx) => PaymentBloc(
        paymentService: paymentService ?? PaymentService(),
      )..add(LoadPaymentHistory(isTrainerMode: isTrainerMode)),
      child: _PaymentHistoryView(initialTrainerMode: isTrainerMode),
    );
  }
}

class _PaymentHistoryView extends StatefulWidget {
  const _PaymentHistoryView({required this.initialTrainerMode});

  final bool initialTrainerMode;

  @override
  State<_PaymentHistoryView> createState() => _PaymentHistoryViewState();
}

class _PaymentHistoryViewState extends State<_PaymentHistoryView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _filters = const ['All', 'Paid', 'Pending', 'Failed'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTrainerMode ? 1 : 0,
    );
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    context.read<PaymentBloc>().add(
      LoadPaymentHistory(
        isTrainerMode: _tabController.index == 1,
        filterStatus: _selectedFilter,
      ),
    );
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<PaymentTransaction> _applyFilters(
    List<PaymentTransaction> transactions,
  ) {
    return transactions.where((tx) {
      // 1. Status Filter
      if (_selectedFilter == 'Paid' && !tx.isCaptured) return false;
      if (_selectedFilter == 'Pending' && !tx.isPending) return false;
      if (_selectedFilter == 'Failed' && !tx.isFailed) return false;

      // 2. Search Query Filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final nameMatch = tx.trainerName?.toLowerCase().contains(q) ?? false;
        final orderMatch = tx.orderId.toLowerCase().contains(q);
        final txIdMatch = tx.id.toLowerCase().contains(q);
        if (!nameMatch && !orderMatch && !txIdMatch) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Payment & Payout History',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorWeight: 3,
          tabs: const [
            Tab(
              icon: Icon(Icons.shopping_bag_outlined, size: 20),
              text: 'My Payments',
            ),
            Tab(
              icon: Icon(Icons.account_balance_wallet_outlined, size: 20),
              text: 'Coach Earnings',
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Filter Chips & Search Bar Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            color: AppColors.surfaceElevated.withAlpha(50),
            child: Column(
              children: [
                // Search Input
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) =>
                        setState(() => _searchQuery = val.trim()),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search by coach name or order ID...',
                      hintStyle: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Status Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filters.map((filter) {
                      final isSelected = _selectedFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            filter,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? Colors.black
                                  : AppColors.textSecondary,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          backgroundColor: AppColors.surfaceElevated,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.border,
                            ),
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedFilter = filter);
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Main Tab Views
          Expanded(
            child: BlocBuilder<PaymentBloc, PaymentState>(
              builder: (context, state) {
                if (state is PaymentHistoryLoading) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  );
                }

                if (state is PaymentHistoryError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 48,
                            color: AppColors.error,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Failed to Load Transactions',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.error,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            state.message,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.black,
                            ),
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Retry'),
                            onPressed: () {
                              context.read<PaymentBloc>().add(
                                LoadPaymentHistory(
                                  isTrainerMode: _tabController.index == 1,
                                  forceRefresh: true,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (state is PaymentHistoryLoaded) {
                  final filteredList = _applyFilters(state.transactions);
                  final isTrainerTab = _tabController.index == 1;

                  return RefreshIndicator(
                    color: AppColors.primary,
                    backgroundColor: AppColors.surface,
                    onRefresh: () async {
                      context.read<PaymentBloc>().add(
                        LoadPaymentHistory(
                          isTrainerMode: isTrainerTab,
                          forceRefresh: true,
                          filterStatus: _selectedFilter,
                        ),
                      );
                    },
                    child: ListView(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      children: [
                        // Trainer Mode: Earnings Metrics Banner
                        if (isTrainerTab)
                          _buildEarningsBanner(
                            state.totalAmount,
                            state.totalTrainerEarnings,
                            state.totalPlatformFees,
                            state.transactions.length,
                          ),

                        if (filteredList.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 48),
                            child: EmptyStateWidget(
                              icon: Icons.receipt_long_outlined,
                              title: 'No Transactions Found',
                              description: _searchQuery.isNotEmpty
                                  ? 'No payment records match "$_searchQuery".'
                                  : (isTrainerTab
                                      ? 'You have not received any client '
                                          'session bookings yet.'
                                      : 'You have not booked any coaching '
                                          'sessions yet.'),
                            ),
                          )
                        else
                          ...filteredList.map(
                            (tx) => TransactionCard(
                              transaction: tx,
                              isTrainerMode: isTrainerTab,
                            ),
                          ),
                      ],
                    ),
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsBanner(
    double totalGross,
    double totalPayout,
    double totalFee,
    int totalCount,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: ElevatedCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'COACH PAYOUT SUMMARY',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(35),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$totalCount Session${totalCount == 1 ? "" : "s"}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    'Net Payout (90%)',
                    '₹${totalPayout.toStringAsFixed(2)}',
                    color: AppColors.primary,
                  ),
                ),
                Container(width: 1, height: 36, color: AppColors.border),
                Expanded(
                  child: _buildMetricTile(
                    'Gross Bookings',
                    '₹${totalGross.toStringAsFixed(2)}',
                    color: AppColors.textPrimary,
                  ),
                ),
                Container(width: 1, height: 36, color: AppColors.border),
                Expanded(
                  child: _buildMetricTile(
                    'Platform Fee (10%)',
                    '-₹${totalFee.toStringAsFixed(2)}',
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, {required Color color}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
