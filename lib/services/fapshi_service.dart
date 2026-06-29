import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Fapshi Payment Service
/// Supports MTN Mobile Money and Orange Money (Cameroon).
///
/// All Fapshi calls go through the `fapshi` Supabase Edge Function
/// (supabase/functions/fapshi). That function holds the API key as a server
/// secret and talks to Fapshi server-to-server — which keeps the key off the
/// device and avoids the TLS handshake failures seen when calling
/// live.fapshi.com directly from a mobile network.
class FapshiService {
  // ─────────────────────────────────────────────────────────────────────────
  // Payment medium constants
  // ─────────────────────────────────────────────────────────────────────────
  static const String mediumMTN    = 'mobile money';
  static const String mediumOrange = 'orange money';

  /// Name of the deployed Supabase Edge Function.
  static const String _functionName = 'fapshi';

  /// Holds the failure reason or message from the last checked payment status.
  String? lastStatusReason;

  SupabaseClient get _sb => Supabase.instance.client;

  /// Returns true if [message] indicates insufficient balance.
  bool _isInsufficientBalance(String message) {
    final lower = message.toLowerCase();
    return lower.contains('insufficient') ||
        lower.contains('solde insuffisant') ||
        lower.contains('not enough') ||
        (lower.contains('balance') && lower.contains('low'));
  }

  /// Invokes the Edge Function and returns its decoded JSON body as a Map.
  ///
  /// The Edge Function always responds HTTP 200 with `{ ok: bool, ... }`, so a
  /// thrown [FunctionException] here means a genuine transport/auth failure
  /// reaching Supabase — surfaced as a [FapshiException].
  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    try {
      final res = await _sb.functions.invoke(_functionName, body: body);
      final data = res.data;
      if (data is Map) return Map<String, dynamic>.from(data);
      if (data is String && data.trim().isNotEmpty) {
        final decoded = json.decode(data);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      }
      return <String, dynamic>{};
    } on FunctionException catch (e) {
      debugPrint('FapshiService: FunctionException ${e.status}: ${e.details}');
      throw FapshiException(
        'Cannot reach payment server. Please check your internet connection.',
        e.status,
      );
    } catch (e) {
      debugPrint('FapshiService: invoke error: $e');
      throw FapshiException(
        'Cannot reach payment server. Please check your internet connection.',
        0,
      );
    }
  }

  /// Initiates a Direct Pay (MoMo push) and returns the transId.
  Future<String?> directPay({
    required int amount,
    required String phone,
    required String medium,
    String message = 'Home237 Premium Subscription',
    String? userId,
    String? externalId,
  }) async {
    debugPrint('FapshiService: directPay amount=$amount medium=$medium');

    final body = <String, dynamic>{
      'action': 'direct-pay',
      'amount': amount,
      'phone': phone,
      'medium': medium,
      'message': message,
    };
    if (userId != null) body['userId'] = userId;
    if (externalId != null) body['externalId'] = externalId;

    final data = await _invoke(body);

    if (data['ok'] == true) {
      final transId = data['transId'] as String?;
      debugPrint('FapshiService: directPay success transId=$transId');
      return transId;
    }

    final msg = (data['message'] ?? 'Payment could not be initiated.').toString();
    if (_isInsufficientBalance(msg)) throw FapshiInsufficientBalanceException();
    final httpStatus = (data['httpStatus'] as num?)?.toInt() ?? 0;
    if (httpStatus == 401 || httpStatus == 403) {
      throw FapshiException(
          'Authentication failed. Please contact support.', httpStatus);
    }
    debugPrint('FapshiService: directPay failed ($httpStatus): $msg');
    throw FapshiException(msg, httpStatus);
  }

  /// Polls payment status. Returns created/pending/successful/failed/expired.
  Future<FapshiStatus> getPaymentStatus(String transId) async {
    lastStatusReason = null;
    try {
      final data = await _invoke({
        'action': 'payment-status',
        'transId': transId,
      });

      if (data['ok'] != true) {
        // Surface Fapshi's own message (e.g. validation / operator reason)
        // so the UI can show something better than the generic fallback.
        final msg = (data['message'] as String? ?? '');
        if (msg.isNotEmpty) lastStatusReason = msg;
        return FapshiStatus.failed;
      }

      final status  = (data['status']  as String? ?? '').toUpperCase();
      final reason  = (data['reason']  as String? ?? '');
      final message = (data['message'] as String? ?? '');
      lastStatusReason = reason.isNotEmpty ? reason : message;

      if (status == 'FAILED' && _isInsufficientBalance(lastStatusReason ?? '')) {
        throw FapshiInsufficientBalanceException();
      }
      switch (status) {
        case 'SUCCESSFUL': return FapshiStatus.successful;
        case 'FAILED':     return FapshiStatus.failed;
        case 'EXPIRED':    return FapshiStatus.expired;
        case 'PENDING':    return FapshiStatus.pending;
        default:           return FapshiStatus.created;
      }
    } on FapshiInsufficientBalanceException { rethrow; }
    on FapshiException { rethrow; }
    catch (e) {
      debugPrint('FapshiService: getPaymentStatus error: $e');
      lastStatusReason = e.toString();
      return FapshiStatus.failed;
    }
  }

  /// Sends a payout to a mobile money number.
  Future<bool> sendPayout({
    required int amount,
    required String phone,
    required String medium,
  }) async {
    final data = await _invoke({
      'action': 'payout',
      'amount': amount,
      'phone': phone,
      'medium': medium,
    });

    if (data['ok'] == true) return true;

    final msg = (data['message'] ?? 'Payout failed.').toString();
    if (_isInsufficientBalance(msg)) throw FapshiInsufficientBalanceException();
    throw FapshiException(msg, (data['httpStatus'] as num?)?.toInt() ?? 0);
  }
}

/// Fapshi transaction statuses
enum FapshiStatus { created, pending, successful, failed, expired }

/// Generic Fapshi exception
class FapshiException implements Exception {
  final String message;
  final int statusCode;
  const FapshiException(this.message, this.statusCode);
  @override
  String toString() => message;
}

/// Thrown when the payer has insufficient MoMo balance.
class FapshiInsufficientBalanceException implements Exception {
  @override
  String toString() => 'Insufficient balance';
}
