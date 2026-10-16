import 'package:equatable/equatable.dart';

/// Supported lifecycle statuses for a payment transaction.
enum PaymentStatus {
  created,
  authorized,
  captured,
  failed,
  refunded;

  static PaymentStatus fromString(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'authorized':
        return PaymentStatus.authorized;
      case 'captured':
      case 'success':
      case 'paid':
        return PaymentStatus.captured;
      case 'failed':
        return PaymentStatus.failed;
      case 'refunded':
        return PaymentStatus.refunded;
      case 'created':
      default:
        return PaymentStatus.created;
    }
  }

  String get dbValue => name;
}

/// Platform Fee Calculation Engine strictly enforcing the mathematical
/// invariant: amount == platformFee + trainerAmount.
class PlatformFeeCalculator {
  static const double defaultFeePct = 10;

  /// Computes split amounts ensuring Amount == PlatformFee + TrainerAmount.
  static ({double amount, double platformFee, double trainerAmount})
  calculateSplit({
    required double amount,
    double feePercent = defaultFeePct,
  }) {
    if (amount <= 0) {
      throw ArgumentError('Amount must be positive');
    }
    if (feePercent < 0 || feePercent > 100) {
      throw ArgumentError('Platform fee percentage must be between 0 and 100');
    }

    final rawFee = amount * (feePercent / 100.0);
    final platformFee = double.parse(rawFee.toStringAsFixed(2));
    final trainerAmount = double.parse(
      (amount - platformFee).toStringAsFixed(2),
    );

    return (
      amount: amount,
      platformFee: platformFee,
      trainerAmount: trainerAmount,
    );
  }

  /// Converts standard currency amount to Paise for Razorpay Route transfers.
  static int toPaise(double amountInr) {
    return (amountInr * 100).round();
  }

  /// Converts integer Paise back to standard currency amount.
  static double fromPaise(int paise) {
    return double.parse((paise / 100.0).toStringAsFixed(2));
  }
}

/// Payment Gateway Configuration returned by GET /payments/config.
class PaymentConfig extends Equatable {
  const PaymentConfig({
    required this.platformFeePercentage,
    required this.currency,
    required this.razorpayKeyId,
  });

  factory PaymentConfig.fromJson(Map<String, dynamic> json) => PaymentConfig(
    platformFeePercentage:
        (json['platform_fee_percentage'] as num?)?.toDouble() ?? 10.0,
    currency: (json['currency'] as String?) ?? 'INR',
    razorpayKeyId:
        (json['razorpay_key_id'] as String?) ?? 'rzp_test_mock_key_12345',
  );

  factory PaymentConfig.defaultMock() => const PaymentConfig(
    platformFeePercentage: 10,
    currency: 'INR',
    razorpayKeyId: 'rzp_test_mock_key_12345',
  );

  final double platformFeePercentage;
  final String currency;
  final String razorpayKeyId;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'platform_fee_percentage': platformFeePercentage,
    'currency': currency,
    'razorpay_key_id': razorpayKeyId,
  };

  @override
  List<Object?> get props => [platformFeePercentage, currency, razorpayKeyId];
}

/// Payload sent to POST /payments/create-order.
class PaymentOrderPayload {
  const PaymentOrderPayload({
    required this.trainerId,
    required this.amount,
    required this.idempotencyKey,
    this.currency = 'INR',
    this.notes,
  });

  factory PaymentOrderPayload.fromJson(Map<String, dynamic> json) =>
      PaymentOrderPayload(
        trainerId: json['trainer_id'] as String,
        amount: (json['amount'] as num).toDouble(),
        idempotencyKey: json['idempotency_key'] as String,
        currency: (json['currency'] as String?) ?? 'INR',
        notes: json['notes'] as Map<String, dynamic>?,
      );

  final String trainerId;
  final double amount;
  final String idempotencyKey;
  final String currency;
  final Map<String, dynamic>? notes;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'trainer_id': trainerId,
    'amount': amount,
    'idempotency_key': idempotencyKey,
    'currency': currency,
    if (notes != null) 'notes': notes,
  };
}

/// Response returned from POST /payments/create-order.
class PaymentOrderResponse extends Equatable {
  const PaymentOrderResponse({
    required this.transactionId,
    required this.orderId,
    required this.amount,
    required this.platformFeeAmount,
    required this.trainerAmount,
    required this.replayed,
  });

  factory PaymentOrderResponse.fromJson(Map<String, dynamic> json) =>
      PaymentOrderResponse(
        transactionId: (json['transaction_id'] ?? json['id'] ?? '') as String,
        orderId:
            (json['order_id'] ?? json['razorpay_order_id'] ?? '') as String,
        amount: (json['amount'] as num).toDouble(),
        platformFeeAmount:
            ((json['platform_fee_amount'] ?? json['platform_fee']) as num)
                .toDouble(),
        trainerAmount: (json['trainer_amount'] as num).toDouble(),
        replayed: (json['replayed'] as bool?) ?? false,
      );

  final String transactionId;
  final String orderId;
  final double amount;
  final double platformFeeAmount;
  final double trainerAmount;
  final bool replayed;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'transaction_id': transactionId,
    'order_id': orderId,
    'amount': amount,
    'platform_fee_amount': platformFeeAmount,
    'trainer_amount': trainerAmount,
    'replayed': replayed,
  };

  @override
  List<Object?> get props => [
    transactionId,
    orderId,
    amount,
    platformFeeAmount,
    trainerAmount,
    replayed,
  ];
}

/// Verification payload sent to POST /payments/verify.
class PaymentVerifyPayload {
  const PaymentVerifyPayload({
    required this.razorpayOrderId,
    required this.razorpayPaymentId,
    required this.razorpaySignature,
  });

  final String razorpayOrderId;
  final String razorpayPaymentId;
  final String razorpaySignature;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'razorpay_order_id': razorpayOrderId,
    'razorpay_payment_id': razorpayPaymentId,
    'razorpay_signature': razorpaySignature,
  };
}

/// Full Payment Transaction entity matching Supabase DB `payment_transactions`.
class PaymentTransaction extends Equatable {
  const PaymentTransaction({
    required this.id,
    required this.idempotencyKey,
    required this.userId,
    required this.trainerId,
    required this.orderId,
    required this.amount,
    required this.platformFee,
    required this.trainerAmount,
    this.razorpayOrderId,
    this.paymentId,
    this.razorpayPaymentId,
    this.razorpaySignature,
    this.currency = 'INR',
    this.platformFeeAmount,
    this.platformFeePercent = 10.0,
    this.status = PaymentStatus.created,
    this.metadata,
    this.encryptedMetadata,
    this.createdAt,
    this.updatedAt,
    this.trainerName,
    this.trainerAvatar,
    this.isReplayed = false,
  });

  factory PaymentTransaction.fromJson(Map<String, dynamic> json) {
    // Resolve trainer display name from joined trainer_profiles if available
    String? trainerName;
    String? trainerAvatar;
    if (json['trainer_profiles'] is Map) {
      final tp = json['trainer_profiles'] as Map<String, dynamic>;
      trainerName = tp['display_name'] as String?;
      trainerAvatar = tp['avatar_url'] as String?;
      if (trainerName == null && tp['profiles'] is Map) {
        trainerName = (tp['profiles'] as Map)['display_name'] as String?;
      }
    } else if (json['trainer_name'] is String) {
      trainerName = json['trainer_name'] as String;
    }

    final feeRaw = json['platform_fee_amount'] ?? json['platform_fee'];
    final feeVal = (feeRaw is num) ? feeRaw.toDouble() : 0.0;

    return PaymentTransaction(
      id: (json['id'] ?? json['transaction_id'] ?? '') as String,
      idempotencyKey: (json['idempotency_key'] as String?) ?? '',
      userId: (json['user_id'] as String?) ?? '',
      trainerId: (json['trainer_id'] as String?) ?? '',
      orderId:
          ((json['order_id'] ?? json['razorpay_order_id']) as String?) ?? '',
      razorpayOrderId: json['razorpay_order_id'] as String?,
      paymentId: (json['payment_id'] ?? json['razorpay_payment_id']) as String?,
      razorpayPaymentId: json['razorpay_payment_id'] as String?,
      razorpaySignature: json['razorpay_signature'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: (json['currency'] as String?) ?? 'INR',
      platformFee: feeVal,
      platformFeeAmount: feeVal,
      platformFeePercent:
          (json['platform_fee_percent'] as num?)?.toDouble() ?? 10.0,
      trainerAmount: (json['trainer_amount'] as num?)?.toDouble() ?? 0.0,
      status: PaymentStatus.fromString(json['status'] as String?),
      metadata: json['metadata'] is Map<String, dynamic>
          ? json['metadata'] as Map<String, dynamic>
          : null,
      encryptedMetadata: json['encrypted_metadata'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      trainerName: trainerName,
      trainerAvatar: trainerAvatar,
      isReplayed: (json['replayed'] as bool?) ?? false,
    );
  }

  final String id;
  final String idempotencyKey;
  final String userId;
  final String trainerId;
  final String orderId;
  final String? razorpayOrderId;
  final String? paymentId;
  final String? razorpayPaymentId;
  final String? razorpaySignature;
  final double amount;
  final String currency;
  final double platformFee;
  final double? platformFeeAmount;
  final double platformFeePercent;
  final double trainerAmount;
  final PaymentStatus status;
  final Map<String, dynamic>? metadata;
  final String? encryptedMetadata;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? trainerName;
  final String? trainerAvatar;
  final bool isReplayed;

  // Convenience state getters
  bool get isCaptured => status == PaymentStatus.captured;
  bool get isPending =>
      status == PaymentStatus.created || status == PaymentStatus.authorized;
  bool get isFailed => status == PaymentStatus.failed;
  bool get isRefunded => status == PaymentStatus.refunded;
  bool get isCreated => status == PaymentStatus.created;

  // Aliases for signature and formatted amounts
  String? get signature => razorpaySignature;
  String get formattedAmount => '₹${amount.toStringAsFixed(2)}';
  String get formattedPlatformFee => '₹${platformFee.toStringAsFixed(2)}';
  String get formattedTrainerAmount => '₹${trainerAmount.toStringAsFixed(2)}';

  // Formatted display helpers
  String get displayAmount => '₹${amount.toStringAsFixed(2)}';
  String get displayFee => '₹${platformFee.toStringAsFixed(2)}';
  String get displayTrainerPayout => '₹${trainerAmount.toStringAsFixed(2)}';

  String get displayStatus {
    switch (status) {
      case PaymentStatus.captured:
        return 'Paid';
      case PaymentStatus.authorized:
        return 'Authorized';
      case PaymentStatus.failed:
        return 'Failed';
      case PaymentStatus.refunded:
        return 'Refunded';
      case PaymentStatus.created:
        return 'Pending';
    }
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'idempotency_key': idempotencyKey,
    'user_id': userId,
    'trainer_id': trainerId,
    'order_id': orderId,
    if (razorpayOrderId != null) 'razorpay_order_id': razorpayOrderId,
    if (paymentId != null) 'payment_id': paymentId,
    if (razorpayPaymentId != null) 'razorpay_payment_id': razorpayPaymentId,
    if (razorpaySignature != null) 'razorpay_signature': razorpaySignature,
    'amount': amount,
    'currency': currency,
    'platform_fee': platformFee,
    'platform_fee_amount': platformFeeAmount ?? platformFee,
    'platform_fee_percent': platformFeePercent,
    'trainer_amount': trainerAmount,
    'status': status.dbValue,
    if (metadata != null) 'metadata': metadata,
    if (encryptedMetadata != null) 'encrypted_metadata': encryptedMetadata,
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    if (trainerName != null) 'trainer_name': trainerName,
    'replayed': isReplayed,
  };

  PaymentTransaction copyWith({
    String? id,
    String? idempotencyKey,
    String? userId,
    String? trainerId,
    String? orderId,
    String? razorpayOrderId,
    String? paymentId,
    String? razorpayPaymentId,
    String? razorpaySignature,
    double? amount,
    String? currency,
    double? platformFee,
    double? platformFeeAmount,
    double? platformFeePercent,
    double? trainerAmount,
    PaymentStatus? status,
    Map<String, dynamic>? metadata,
    String? encryptedMetadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? trainerName,
    String? trainerAvatar,
    bool? isReplayed,
  }) {
    return PaymentTransaction(
      id: id ?? this.id,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      userId: userId ?? this.userId,
      trainerId: trainerId ?? this.trainerId,
      orderId: orderId ?? this.orderId,
      razorpayOrderId: razorpayOrderId ?? this.razorpayOrderId,
      paymentId: paymentId ?? this.paymentId,
      razorpayPaymentId: razorpayPaymentId ?? this.razorpayPaymentId,
      razorpaySignature: razorpaySignature ?? this.razorpaySignature,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      platformFee: platformFee ?? this.platformFee,
      platformFeeAmount: platformFeeAmount ?? this.platformFeeAmount,
      platformFeePercent: platformFeePercent ?? this.platformFeePercent,
      trainerAmount: trainerAmount ?? this.trainerAmount,
      status: status ?? this.status,
      metadata: metadata ?? this.metadata,
      encryptedMetadata: encryptedMetadata ?? this.encryptedMetadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      trainerName: trainerName ?? this.trainerName,
      trainerAvatar: trainerAvatar ?? this.trainerAvatar,
      isReplayed: isReplayed ?? this.isReplayed,
    );
  }

  @override
  List<Object?> get props => [
    id,
    idempotencyKey,
    userId,
    trainerId,
    orderId,
    razorpayOrderId,
    paymentId,
    razorpayPaymentId,
    razorpaySignature,
    amount,
    currency,
    platformFee,
    platformFeeAmount,
    platformFeePercent,
    trainerAmount,
    status,
    metadata,
    createdAt,
    updatedAt,
    trainerName,
    isReplayed,
  ];
}
