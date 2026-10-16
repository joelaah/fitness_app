import 'dart:math' as math;
import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/features/payments/services/payment_signature_helper.dart';
import 'package:fitness_app/features/payments/services/razorpay_bridge.dart';
import 'package:flutter/material.dart';

/// Razorpay Web Sandbox Dialog:
/// Replicates the official Razorpay checkout modal for test/sandbox web demo environments.
/// Enables recruiters and users to test UPI, Cards, and NetBanking flows with
/// cryptographically valid HMAC-SHA256 signatures matching the backend secret.
class RazorpaySandboxDialog extends StatefulWidget {
  const RazorpaySandboxDialog({required this.options, super.key});

  final RazorpayCheckoutOptions options;

  @override
  State<RazorpaySandboxDialog> createState() => _RazorpaySandboxDialogState();
}

class _RazorpaySandboxDialogState extends State<RazorpaySandboxDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedCard = '4111 1111 1111 1111';
  final String _selectedUpi = 'success@razorpay';
  String _selectedBank = 'HDFC Bank';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _simulateSuccess() {
    final randHex =
        math.Random().nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
    final timestampHex =
        DateTime.now().millisecondsSinceEpoch.toRadixString(16);
    final paymentId = 'pay_test_$randHex$timestampHex';
    final signature = PaymentSignatureHelper.computeRazorpaySignature(
      orderId: widget.options.orderId,
      paymentId: paymentId,
    );

    Navigator.of(context).pop(<String, dynamic>{
      'status': 'success',
      'order_id': widget.options.orderId,
      'payment_id': paymentId,
      'signature': signature,
      'method': _tabController.index == 0
          ? 'upi'
          : (_tabController.index == 1 ? 'card' : 'netbanking'),
    });
  }

  void _simulateFailure() {
    Navigator.of(context).pop(<String, dynamic>{
      'status': 'failed',
      'message':
          'Payment authorization declined by issuing bank (Test Simulation).',
      'code': PaymentFailureResponse.codePaymentFailed,
    });
  }

  void _cancel() {
    Navigator.of(context).pop(<String, dynamic>{
      'status': 'cancelled',
      'message': 'Payment cancelled by user.',
      'code': PaymentFailureResponse.codeCancelled,
    });
  }

  @override
  Widget build(BuildContext context) {
    const razorpayNavy = Color(0xFF0C2340);
    const razorpayBlue = Color(0xFF3395FF);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(150),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Razorpay Brand Header
              Container(
                color: razorpayNavy,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.shield_rounded,
                          color: razorpayBlue,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Razorpay',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'SECURE',
                          style: TextStyle(
                            color: razorpayBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withAlpha(40),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.amber.withAlpha(120)),
                      ),
                      child: const Text(
                        'TEST MODE',
                        style: TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                      ),
                      onPressed: _cancel,
                      splashRadius: 18,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // Order Summary Banner
              Container(
                padding: const EdgeInsets.all(16),
                color: AppColors.surfaceElevated.withAlpha(100),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.options.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.options.description,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Order: ${widget.options.orderId}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '₹${widget.options.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),

              // Payment Method Tabs
              TabBar(
                controller: _tabController,
                indicatorColor: razorpayBlue,
                labelColor: razorpayBlue,
                unselectedLabelColor: AppColors.textSecondary,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.qr_code_2_rounded, size: 18),
                    text: 'UPI / QR',
                  ),
                  Tab(
                    icon: Icon(Icons.credit_card_rounded, size: 18),
                    text: 'Cards',
                  ),
                  Tab(
                    icon: Icon(Icons.account_balance_rounded, size: 18),
                    text: 'NetBanking',
                  ),
                ],
              ),

              // Tab Views
              SizedBox(
                height: 180,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // UPI Tab
                    _buildUpiTab(),
                    // Cards Tab
                    _buildCardsTab(),
                    // NetBanking Tab
                    _buildNetBankingTab(),
                  ],
                ),
              ),

              const Divider(color: AppColors.border, height: 1),

              // Interactive Simulation Action Buttons
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 18,
                        ),
                        label: Text(
                          'Simulate Payment Success '
                          '(₹${widget.options.amount.toStringAsFixed(0)})',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        onPressed: _simulateSuccess,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.cancel_outlined, size: 16),
                            label: const Text(
                              'Simulate Decline',
                              style: TextStyle(fontSize: 12),
                            ),
                            onPressed: _simulateFailure,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: _cancel,
                            child: const Text(
                              'Cancel Payment',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
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
  }

  Widget _buildUpiTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Scan QR code or use Instant VPA handle:',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.qr_code_rounded,
                  color: Colors.black,
                  size: 48,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedUpi,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Supports GPay • PhonePe • Paytm • BHIM',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Test Cards Preset:',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('Success Card'),
                  selected: _selectedCard.startsWith('4111'),
                  onSelected: (val) {
                    setState(() => _selectedCard = '4111 1111 1111 1111');
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Text('Declined Card'),
                  selected: _selectedCard.startsWith('4000'),
                  onSelected: (val) {
                    setState(() => _selectedCard = '4000 0000 0000 0002');
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedCard,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Text(
                  'EXP: 12/28  CVV: 123',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetBankingTab() {
    final banks = [
      'HDFC Bank',
      'ICICI Bank',
      'State Bank of India',
      'Axis Bank',
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Simulated Retail Bank:',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: banks.map((bank) {
              return ChoiceChip(
                label: Text(bank, style: const TextStyle(fontSize: 11)),
                selected: _selectedBank == bank,
                onSelected: (val) {
                  if (val) setState(() => _selectedBank = bank);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
