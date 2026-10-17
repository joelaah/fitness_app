import 'dart:async';
import 'package:fitness_app/features/auth/services/auth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Exception thrown when an anonymous guest or free user exceeds their daily quota of 5 queries.
class AiQuotaExceededException implements Exception {
  const AiQuotaExceededException([
    this.message = 'Daily AI Coach query limit reached (5/5). Upgrade your account for unlimited queries.',
  ]);

  final String message;

  @override
  String toString() => message;
}

/// Service managing rate limiting and daily usage quotas for AI queries.
///
/// Rules:
/// - Anonymous guests and free users are restricted to 5 AI Coach queries per 24 hours.
/// - Upgraded / authenticated premium accounts enjoy unrestricted (unlimited) access.
/// - Quota resets automatically every 24 hours or at 00:00 UTC.
/// - Immune to concurrency race conditions and clock tampering (backward time shifts).
class AiQuotaService {
  AiQuotaService({
    SharedPreferences? prefs,
    AuthService? authService,
    DateTime Function()? clock,
  })  : _prefs = prefs,
        _authService = authService ?? AuthService(),
        _clock = clock ?? DateTime.now;

  final SharedPreferences? _prefs;
  final AuthService _authService;
  final DateTime Function() _clock;

  /// Free tier daily query limit
  static const int maxDailyFreeQueries = 5;

  /// SharedPreferences key for stored query count
  static const String prefKeyCount = 'pulsefit_ai_quota_used_count';

  /// SharedPreferences key for current quota window start time
  static const String prefKeyWindowStart = 'pulsefit_ai_quota_window_start';

  // In-memory fallbacks when SharedPreferences is completely unavailable
  int _inMemoryCount = 0;
  DateTime? _inMemoryWindowStart;

  // Asynchronous queue lock to guarantee serial execution and prevent race conditions
  Future<void> _lock = Future<void>.value();

  Future<T> _synchronized<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _lock = _lock.then((_) async {
      try {
        final result = await action();
        completer.complete(result);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  /// Lazily obtains SharedPreferences if not supplied in constructor
  Future<SharedPreferences?> _getPrefs() async {
    if (_prefs != null) return _prefs;
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  /// Checks if the given user or current auth session is upgraded / premium.
  ///
  /// Criteria for unlimited access:
  /// - Explicit `isUpgraded == true` parameter.
  /// - User has `is_premium: true` or `is_upgraded: true` in user metadata.
  /// - User has `tier: 'premium'`, `tier: 'pro'`, or `subscription: 'pro'` in user metadata.
  /// - User is an authenticated permanent account (`isAnonymous == false` and not explicitly marked `is_free: true` or `tier: 'free'`).
  bool isUpgradedUser({User? user, bool? isUpgraded}) {
    if (isUpgraded != null) return isUpgraded;

    final currentUser = user ?? _authService.currentUser;
    if (currentUser == null) {
      if (!_authService.isAnonymous) {
        return true;
      }
      return false;
    }

    // Anonymous guests are subject to the 5-query quota
    if (currentUser.isAnonymous) {
      return false;
    }

    final meta = currentUser.userMetadata ?? const <String, dynamic>{};

    // Explicit premium / upgraded indicators grant unlimited access
    if (meta['is_premium'] == true ||
        meta['is_upgraded'] == true ||
        meta['tier'] == 'premium' ||
        meta['tier'] == 'pro' ||
        meta['subscription'] == 'pro') {
      return true;
    }

    // Explicit free account flag or free tier in metadata restricts access even if authenticated
    if (meta['is_free'] == true || meta['tier'] == 'free') {
      return false;
    }

    // Permanent authenticated accounts without free flags are unrestricted
    return true;
  }

  /// Internal helper to check and apply 24h / 00:00 UTC reset.
  /// Robust against device clock adjustments and negative time shifts.
  Future<void> _checkAndApplyReset(DateTime now) async {
    final windowStart = await _getWindowStart();

    if (windowStart == null) {
      await _setWindowStart(now);
      await _setUsedCount(0);
      return;
    }

    // If clock shifted backwards into the past (device tampering or NTP correction)
    if (now.isBefore(windowStart)) {
      // Re-anchor window start to current time so user isn't locked in the future,
      // but strictly PRESERVE used count (prevents infinite queries by winding clock back).
      await _setWindowStart(now);
      return;
    }

    final isPast24Hours = now.difference(windowStart) >= const Duration(hours: 24);
    final nowUtc = now.toUtc();
    final startUtc = windowStart.toUtc();
    final isNewerUtcDay = nowUtc.isAfter(startUtc) &&
        (nowUtc.year != startUtc.year ||
            nowUtc.month != startUtc.month ||
            nowUtc.day != startUtc.day);

    if (isPast24Hours || isNewerUtcDay) {
      debugPrint(
        'AiQuotaService: 24-hour / 00:00 UTC reset triggered. Resetting quota count from window start $windowStart to $now.',
      );
      await _setUsedCount(0);
      await _setWindowStart(now);
    }
  }

  /// Checks whether an AI Coach query is allowed under the current quota.
  Future<bool> canMakeQuery({
    User? user,
    bool? isUpgraded,
    DateTime? now,
  }) {
    return _synchronized(() async {
      final currentTime = now ?? _clock();
      await _checkAndApplyReset(currentTime);

      if (isUpgradedUser(user: user, isUpgraded: isUpgraded)) {
        return true;
      }

      final used = await _getUsedCountInternal();
      return used < maxDailyFreeQueries;
    });
  }

  /// Consumes a single AI Coach query from the quota atomically.
  /// Throws [AiQuotaExceededException] if the daily limit is exhausted.
  Future<void> consumeQuery({
    User? user,
    bool? isUpgraded,
    DateTime? now,
  }) {
    return _synchronized(() async {
      final currentTime = now ?? _clock();
      await _checkAndApplyReset(currentTime);

      if (isUpgradedUser(user: user, isUpgraded: isUpgraded)) {
        // Upgraded users are unrestricted - do not count against free quota
        return;
      }

      final used = await _getUsedCountInternal();
      if (used >= maxDailyFreeQueries) {
        throw const AiQuotaExceededException();
      }

      await _setUsedCount(used + 1);
    });
  }

  /// Refunds a previously consumed query (e.g. when an AI request fails due to network/server errors).
  /// Safe against underflow: count will not drop below 0.
  Future<void> refundQuery({
    User? user,
    bool? isUpgraded,
    DateTime? now,
  }) {
    return _synchronized(() async {
      if (isUpgradedUser(user: user, isUpgraded: isUpgraded)) {
        return;
      }
      final currentTime = now ?? _clock();
      await _checkAndApplyReset(currentTime);

      final used = await _getUsedCountInternal();
      if (used > 0) {
        await _setUsedCount(used - 1);
      }
    });
  }

  /// Returns the remaining free queries for today.
  /// For upgraded/premium users, returns -1 (indicating unlimited access).
  Future<int> getRemainingQueries({
    User? user,
    bool? isUpgraded,
    DateTime? now,
  }) {
    return _synchronized(() async {
      final currentTime = now ?? _clock();
      await _checkAndApplyReset(currentTime);

      if (isUpgradedUser(user: user, isUpgraded: isUpgraded)) {
        return -1; // Unlimited
      }

      final used = await _getUsedCountInternal();
      final remaining = maxDailyFreeQueries - used;
      return remaining.clamp(0, maxDailyFreeQueries);
    });
  }

  /// Returns the number of queries consumed in the current 24-hour cycle.
  Future<int> getUsedQueries({DateTime? now}) {
    return _synchronized(() async {
      final currentTime = now ?? _clock();
      await _checkAndApplyReset(currentTime);
      return _getUsedCountInternal();
    });
  }

  /// Calculates the next scheduled quota reset time (24h from window start or 00:00 UTC).
  Future<DateTime> getNextResetTime({DateTime? now}) {
    return _synchronized(() async {
      final currentTime = now ?? _clock();
      await _checkAndApplyReset(currentTime);
      final windowStart = await _getWindowStart() ?? currentTime;

      final rollingReset = windowStart.add(const Duration(hours: 24));
      final currentUtc = currentTime.toUtc();
      final nextUtcMidnight = DateTime.utc(
        currentUtc.year,
        currentUtc.month,
        currentUtc.day + 1,
      );

      if (nextUtcMidnight.isBefore(rollingReset)) {
        return nextUtcMidnight;
      }
      return rollingReset;
    });
  }

  /// Resets quota counters immediately.
  Future<void> resetQuota() {
    return _synchronized(() async {
      await _setUsedCount(0);
      final now = _clock();
      await _setWindowStart(now);
    });
  }

  // ── Storage Helpers ──────────────────────────────────────────────────

  Future<int> _getUsedCountInternal() async {
    final prefs = await _getPrefs();
    if (prefs != null) {
      return prefs.getInt(prefKeyCount) ?? 0;
    }
    return _inMemoryCount;
  }

  Future<DateTime?> _getWindowStart() async {
    final prefs = await _getPrefs();
    if (prefs != null) {
      final isoStr = prefs.getString(prefKeyWindowStart);
      if (isoStr != null) {
        return DateTime.tryParse(isoStr);
      }
      return null;
    }
    return _inMemoryWindowStart;
  }

  Future<void> _setWindowStart(DateTime date) async {
    final prefs = await _getPrefs();
    if (prefs != null) {
      await prefs.setString(prefKeyWindowStart, date.toIso8601String());
    } else {
      _inMemoryWindowStart = date;
    }
  }

  Future<void> _setUsedCount(int count) async {
    final prefs = await _getPrefs();
    if (prefs != null) {
      await prefs.setInt(prefKeyCount, count);
    } else {
      _inMemoryCount = count;
    }
  }
}
