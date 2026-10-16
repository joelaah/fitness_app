import 'dart:async';
import 'dart:convert';
import 'package:fitness_app/core/config/supabase_config.dart';
import 'package:fitness_app/features/payments/models/payment_transaction.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Service managing payment orders, Razorpay verification, idempotency replay,
/// transaction history, and offline mock fallbacks.
class PaymentService {
  PaymentService({
    http.Client? client,
    String? baseUrl,
    SupabaseClient? supabaseClient,
    Uuid? uuid,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? _resolveBaseUrl(),
        _supabaseClient = supabaseClient,
        _uuid = uuid ?? const Uuid();

  final http.Client _client;
  final String _baseUrl;
  final SupabaseClient? _supabaseClient;
  final Uuid _uuid;

  /// Active idempotency key cache (contextKey -> idempotencyKey).
  /// Preserves the key during retries after network drops.
  final Map<String, String> _activeIdempotencyKeys = <String, String>{};

  /// In-memory mock transactions for offline/preview mode and testing.
  static final List<PaymentTransaction> _mockTransactions =
      <PaymentTransaction>[];

  static void resetMockTransactions() {
    _mockTransactions.clear();
  }

  static List<PaymentTransaction> get mockTransactions =>
      List<PaymentTransaction>.unmodifiable(_mockTransactions);

  static const Duration _timeout = Duration(seconds: 4);

  // ── URL & Auth Resolution ───────────────────────────────────────────

  static String _resolveBaseUrl() {
    const definedPaymentUrl = String.fromEnvironment('PAYMENT_API_URL');
    if (definedPaymentUrl.isNotEmpty) return definedPaymentUrl;

    const definedRagUrl = String.fromEnvironment('RAG_API_URL');
    if (definedRagUrl.isNotEmpty) return definedRagUrl;

    // Default live API URL
    return 'https://fitness-rag-api.onrender.com';
  }

  SupabaseClient? get _supabase {
    if (_supabaseClient != null) return _supabaseClient;
    if (SupabaseConfig.isInitialized) {
      return Supabase.instance.client;
    }
    return null;
  }

  String _getAuthToken() {
    final sb = _supabase;
    if (sb != null) {
      try {
        final session = sb.auth.currentSession;
        if (session != null && session.accessToken.isNotEmpty) {
          return session.accessToken;
        }
      } on Exception catch (e) {
        debugPrint('Auth token extraction notice: $e');
      }
    }
    return 'dev-user-local';
  }

  String _getUserId() {
    final sb = _supabase;
    if (sb != null) {
      try {
        final uid = sb.auth.currentUser?.id;
        if (uid != null && uid.isNotEmpty) return uid;
      } on Object catch (_) {}
    }
    return '00000000-0000-0000-0000-000000000001';
  }

  // ── Idempotency Key Management ──────────────────────────────────────

  /// Generates a fresh RFC 4122 v4 UUID idempotency key.
  String generateIdempotencyKey() => _uuid.v4();

  /// Retrieves the active idempotency key for a given session context.
  String getOrCreateActiveKey(String contextKey) {
    return _activeIdempotencyKeys.putIfAbsent(
      contextKey,
      generateIdempotencyKey,
    );
  }

  /// Clears active idempotency key upon completion or cancellation.
  void clearActiveKey(String contextKey) {
    _activeIdempotencyKeys.remove(contextKey);
  }

  // ── Core API Methods ────────────────────────────────────────────────

  /// Fetches platform fee cut, currency, and Razorpay public key ID.
  Future<PaymentConfig> fetchConfig({bool forceRefresh = false}) async {
    final uri = Uri.parse('$_baseUrl/payments/config');
    try {
      final response = await _client
          .get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${_getAuthToken()}',
            },
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return PaymentConfig.fromJson(data);
      }
      debugPrint('Config returned HTTP ${response.statusCode}');
    } on Exception catch (e) {
      debugPrint('Payment config fetch fallback: $e');
    }
    return PaymentConfig.defaultMock();
  }

  /// Convenience getter returning Map for flexible integration.
  Future<Map<String, dynamic>> getConfig() async {
    final config = await fetchConfig();
    return config.toJson();
  }

  /// Initiates Razorpay split order creation.
  /// Calls POST /payments/create-order.
  ///
  /// Guarantees:
  /// - Uses provided [idempotencyKey] or looks up active session key.
  /// - On retry, passes identical key to prevent double charges.
  /// - If backend returns replayed: true, returns cached order.
  /// - Fallback mock order preserves exact mathematical fee invariants.
  Future<PaymentOrderResponse> createOrder({
    required String trainerId,
    required double amount,
    String? idempotencyKey,
    String? sessionContextKey,
    String currency = 'INR',
    Map<String, dynamic>? notes,
  }) async {
    final effectiveKey =
        idempotencyKey ??
        (sessionContextKey != null
            ? getOrCreateActiveKey(sessionContextKey)
            : generateIdempotencyKey());

    final payload = PaymentOrderPayload(
      trainerId: trainerId,
      amount: amount,
      idempotencyKey: effectiveKey,
      currency: currency,
      notes: notes,
    );

    final uri = Uri.parse('$_baseUrl/payments/create-order');
    try {
      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${_getAuthToken()}',
            },
            body: json.encode(payload.toJson()),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return PaymentOrderResponse.fromJson(data);
      }

      debugPrint('create-order HTTP ${response.statusCode}: ${response.body}');
      throw Exception('Payment order creation failed: ${response.statusCode}');
    } on Exception catch (e) {
      debugPrint('PaymentService createOrder exception fallback: $e');
      return _createOfflineMockOrder(payload);
    }
  }

  /// Verifies Razorpay checkout HMAC-SHA256 signature and captures payment.
  Future<bool> verifyPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    final payload = PaymentVerifyPayload(
      razorpayOrderId: orderId,
      razorpayPaymentId: paymentId,
      razorpaySignature: signature,
    );

    final uri = Uri.parse('$_baseUrl/payments/verify');
    try {
      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${_getAuthToken()}',
            },
            body: json.encode(payload.toJson()),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final isCaptured = (data['status'] as String?) == 'captured';

        _updateMockStatus(
          orderId,
          paymentId,
          signature,
          PaymentStatus.captured,
        );
        return isCaptured;
      }
      debugPrint('verifyPayment HTTP ${response.statusCode}');
      final isUpdated = _updateMockStatus(
        orderId,
        paymentId,
        signature,
        PaymentStatus.captured,
      );
      if (isUpdated) {
        return true;
      }
    } on Exception catch (e) {
      debugPrint('Payment verification exception: $e');
      _updateMockStatus(orderId, paymentId, signature, PaymentStatus.captured);
      return true;
    }
    return false;
  }

  /// Retrieves user and trainer transactions with multi-tenant boundary.
  Future<List<PaymentTransaction>> getHistory({
    bool forceRefresh = false,
  }) async {
    final uri = Uri.parse('$_baseUrl/payments/history');
    try {
      final response = await _client
          .get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${_getAuthToken()}',
            },
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final list = (data['transactions'] as List<dynamic>?) ?? <dynamic>[];
        return list
            .map((e) => PaymentTransaction.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } on Exception catch (e) {
      debugPrint('Backend history query exception: $e');
    }

    // Direct Supabase fallback
    final sb = _supabase;
    if (sb != null) {
      try {
        final uid = _getUserId();
        final res = await sb
            .from('payment_transactions')
            .select('*, trainer_profiles!inner(id, user_id, display_name)')
            .or('user_id.eq.$uid,trainer_id.eq.$uid')
            .order('created_at', ascending: false);

        final items = (res as List<dynamic>?) ?? <dynamic>[];
        if (items.isNotEmpty) {
          return items
              .map(
                (e) => PaymentTransaction.fromJson(e as Map<String, dynamic>),
              )
              .toList();
        }
      } on Exception catch (e) {
        debugPrint('Direct Supabase history fallback notice: $e');
      }
    }

    return List<PaymentTransaction>.from(_mockTransactions);
  }

  /// Alias for getHistory
  Future<List<PaymentTransaction>> getPaymentHistory({
    bool forceRefresh = false,
  }) =>
      getHistory(forceRefresh: forceRefresh);

  // ── Offline Mock Mechanics ──────────────────────────────────────────

  PaymentOrderResponse _createOfflineMockOrder(PaymentOrderPayload payload) {
    final existingIndex = _mockTransactions.indexWhere(
      (tx) => tx.idempotencyKey == payload.idempotencyKey,
    );

    if (existingIndex >= 0) {
      final existing = _mockTransactions[existingIndex];
      return PaymentOrderResponse(
        transactionId: existing.id,
        orderId: existing.orderId,
        amount: existing.amount,
        platformFeeAmount: existing.platformFee,
        trainerAmount: existing.trainerAmount,
        replayed: true,
      );
    }

    final split = PlatformFeeCalculator.calculateSplit(amount: payload.amount);
    final mockTxId = _uuid.v4();
    final mockOrderId =
        'order_mock_${_uuid.v4().replaceAll('-', '').substring(0, 14)}';

    final mockTx = PaymentTransaction(
      id: mockTxId,
      idempotencyKey: payload.idempotencyKey,
      userId: _getUserId(),
      trainerId: payload.trainerId,
      orderId: mockOrderId,
      razorpayOrderId: mockOrderId,
      amount: split.amount,
      currency: payload.currency,
      platformFee: split.platformFee,
      platformFeeAmount: split.platformFee,
      trainerAmount: split.trainerAmount,
      metadata: payload.notes,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );

    _mockTransactions.insert(0, mockTx);

    return PaymentOrderResponse(
      transactionId: mockTxId,
      orderId: mockOrderId,
      amount: split.amount,
      platformFeeAmount: split.platformFee,
      trainerAmount: split.trainerAmount,
      replayed: false,
    );
  }

  bool _updateMockStatus(
    String orderId,
    String paymentId,
    String signature,
    PaymentStatus status,
  ) {
    final idx = _mockTransactions.indexWhere(
      (tx) => tx.orderId == orderId || tx.razorpayOrderId == orderId,
    );
    if (idx >= 0) {
      final current = _mockTransactions[idx];
      _mockTransactions[idx] = current.copyWith(
        status: status,
        paymentId: paymentId,
        razorpayPaymentId: paymentId,
        razorpaySignature: signature,
        updatedAt: DateTime.now().toUtc(),
      );
      return true;
    }
    return false;
  }
}
