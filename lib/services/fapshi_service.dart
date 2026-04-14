import 'dart:convert';
import 'package:http/http.dart' as http;

/// Fapshi Payment Service
/// Supports MTN Mobile Money and Orange Money (Cameroon)
///
/// ⚠️  IMPORTANT: Replace the placeholder credentials below with your
///     real Fapshi API credentials from https://dashboard.fapshi.com
///     Settings → API Keys
class FapshiService {
  // ─────────────────────────────────────────────────────────────────────────
  // CREDENTIALS — paste your Fapshi API keys here
  // ─────────────────────────────────────────────────────────────────────────
  static const String _apiUser = 'YOUR_FAPSHI_API_USER'; // e.g. "abc123"
  static const String _apiKey  = 'YOUR_FAPSHI_API_KEY';  // e.g. "xyz789..."

  // Use live endpoint for production; sandbox for testing (check Fapshi docs)
  static const String _baseUrl = 'https://live.fapshi.com';

  // ─────────────────────────────────────────────────────────────────────────
  // Payment medium constants
  // ─────────────────────────────────────────────────────────────────────────
  static const String mediumMTN    = 'mobile money';
  static const String mediumOrange = 'orange money';

  // ─────────────────────────────────────────────────────────────────────────
  // Common auth headers
  // ─────────────────────────────────────────────────────────────────────────
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'apiuser': _apiUser,
        'apikey': _apiKey,
      };

  /// Initiates a Direct Pay request (push payment to user's phone).
  ///
  /// [amount]     — amount in XAF (min 100)
  /// [phone]      — payer's phone number (e.g. "237670000000")
  /// [medium]     — [mediumMTN] or [mediumOrange]
  /// [message]    — reason shown to payer (optional)
  /// [userId]     — internal user ID for reconciliation (optional)
  /// [externalId] — your order/transaction ID (optional)
  ///
  /// Returns the Fapshi `transId` on success, or null on failure.
  Future<String?> directPay({
    required int amount,
    required String phone,
    required String medium,
    String message = 'Home237 Premium Subscription',
    String? userId,
    String? externalId,
  }) async {
    // Normalize phone: strip leading + or spaces, ensure starts with 237
    String cleanPhone = phone.replaceAll(RegExp(r'[\s\-\+]'), '');
    if (!cleanPhone.startsWith('237')) {
      cleanPhone = '237$cleanPhone';
    }

    final body = <String, dynamic>{
      'amount': amount,
      'phone': cleanPhone,
      'medium': medium,
      'message': message,
    };
    if (userId != null) body['userId'] = userId;
    if (externalId != null) body['externalId'] = externalId;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/direct-pay'),
        headers: _headers,
        body: json.encode(body),
      );

      final data = json.decode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final transId = data['transId'] as String?;
        return transId;
      } else {
        final msg = data['message'] ?? 'Payment initiation failed';
        throw FapshiException(msg.toString(), response.statusCode);
      }
    } on FapshiException {
      rethrow;
    } catch (e) {
      throw FapshiException('Network error: $e', 0);
    }
  }

  /// Polls the status of a Fapshi transaction.
  ///
  /// Returns one of: `CREATED`, `PENDING`, `SUCCESSFUL`, `FAILED`, `EXPIRED`
  Future<FapshiStatus> getPaymentStatus(String transId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/payment-status/$transId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Response may be a list or object depending on API version
        Map<String, dynamic> item;
        if (data is List && data.isNotEmpty) {
          item = data[0] as Map<String, dynamic>;
        } else if (data is Map<String, dynamic>) {
          item = data;
        } else {
          return FapshiStatus.failed;
        }

        final status = (item['status'] as String? ?? '').toUpperCase();
        switch (status) {
          case 'SUCCESSFUL':
            return FapshiStatus.successful;
          case 'FAILED':
            return FapshiStatus.failed;
          case 'EXPIRED':
            return FapshiStatus.expired;
          case 'PENDING':
            return FapshiStatus.pending;
          case 'CREATED':
          default:
            return FapshiStatus.created;
        }
      } else {
        return FapshiStatus.failed;
      }
    } catch (_) {
      return FapshiStatus.failed;
    }
  }
}

/// Fapshi transaction statuses
enum FapshiStatus { created, pending, successful, failed, expired }

/// Exception thrown when Fapshi returns an error response
class FapshiException implements Exception {
  final String message;
  final int statusCode;
  const FapshiException(this.message, this.statusCode);

  @override
  String toString() => message;
}
