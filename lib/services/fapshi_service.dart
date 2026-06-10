import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Fapshi Payment Service
/// Supports MTN Mobile Money and Orange Money (Cameroon)
///
/// ⚠️  IMPORTANT: Set your Fapshi API credentials in Firestore at:
///     admin_settings/fapshi  →  { apiUser, apiKey, mode }
///
///     • mode: "sandbox" (testing) or "live" (production)
///     • Sandbox URL: https://sandbox.fapshi.com
///     • Live URL:    https://live.fapshi.com
///     • Sandbox and live credentials are DIFFERENT — get them from
///       https://dashboard.fapshi.com → your service → Developers tab
///
///     ⚠️  IP whitelisting on the Fapshi dashboard applies to:
///         initiate-pay, direct-pay, payout.
///         Disable it or whitelist your server IP, otherwise you get 403.
class FapshiService {
  // ─────────────────────────────────────────────────────────────────────────
  // CREDENTIALS — loaded from Firestore; fallback to hardcoded defaults
  // ─────────────────────────────────────────────────────────────────────────
  String _apiUser = '';
  String _apiKey  = '';

  // Default to live for production use
  String _baseUrl = 'https://live.fapshi.com';

  // Cache flag to avoid hitting Firestore on every call
  bool _credentialsLoaded = false;

  // ─────────────────────────────────────────────────────────────────────────
  // Hardcoded fallback credentials (used when Firestore doc is missing)
  // ─────────────────────────────────────────────────────────────────────────
  static const String _fallbackApiUser = 'ba01f9ab-b79c-4a6c-b256-787fcb716705';
  static const String _fallbackApiKey  = 'FAK_87900457310b82601c123b0909a182c3';

  // ─────────────────────────────────────────────────────────────────────────
  // Payment medium constants
  // ─────────────────────────────────────────────────────────────────────────
  static const String mediumMTN    = 'mobile money';
  static const String mediumOrange = 'orange money';

  /// Helper to read a field from Firestore data, trying multiple key variants.
  /// Tries: camelCase (apiUser), snake_case (api_user), lowercase (apiuser)
  String _readField(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '';
  }

  /// Loads API credentials from Firestore (cached after first load).
  ///
  /// Firestore document: admin_settings/fapshi
  /// Accepted field names (tries all variants):
  ///   - apiUser / api_user / apiuser  — your Fapshi API user ID
  ///   - apiKey  / api_key  / apikey   — your Fapshi API key
  ///   - mode    (String) — "sandbox" or "live"
  ///
  /// Falls back to hardcoded credentials if Firestore doc is missing.
  Future<void> _initCredentials() async {
    if (_credentialsLoaded) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('admin_settings')
          .doc('fapshi')
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          // Try multiple field name variants for apiUser
          _apiUser = _readField(data, ['apiUser', 'api_user', 'apiuser', 'ApiUser', 'APIUSER']);
          // Try multiple field name variants for apiKey
          _apiKey  = _readField(data, ['apiKey', 'api_key', 'apikey', 'ApiKey', 'APIKEY', 'api']);
          // Read mode
          final mode = _readField(data, ['mode', 'Mode', 'MODE']);
          final effectiveMode = mode.isNotEmpty ? mode : 'live';

          _baseUrl = effectiveMode == 'sandbox'
              ? 'https://sandbox.fapshi.com'
              : 'https://live.fapshi.com';

          debugPrint('FapshiService: Loaded credentials from Firestore — '
              'mode=$effectiveMode, '
              'apiUser=${_apiUser.isNotEmpty ? "${_apiUser.substring(0, 8)}..." : "(empty)"}, '
              'baseUrl=$_baseUrl');
          debugPrint('FapshiService: Firestore doc fields found: ${data.keys.toList()}');
        }
      } else {
        debugPrint('FapshiService: ⚠️ Firestore doc admin_settings/fapshi '
            'not found — using hardcoded fallback credentials.');
      }
    } catch (e) {
      debugPrint('FapshiService: Error loading credentials from Firestore: $e');
    }

    // Fall back to hardcoded credentials if Firestore didn't provide them
    if (_apiUser.isEmpty) {
      _apiUser = _fallbackApiUser;
      debugPrint('FapshiService: Using fallback apiUser: ${_apiUser.substring(0, 8)}...');
    }
    if (_apiKey.isEmpty) {
      _apiKey = _fallbackApiKey;
      debugPrint('FapshiService: Using fallback apiKey: ${_apiKey.substring(0, 8)}...');
    }

    _credentialsLoaded = true;

    debugPrint('FapshiService: Final config — '
        'baseUrl=$_baseUrl, '
        'apiUser=${_apiUser.substring(0, 8)}..., '
        'apiKey=${_apiKey.substring(0, 8)}...');
  }

  /// Force re-load credentials (e.g. after admin updates them in Firestore).
  void resetCredentials() {
    _credentialsLoaded = false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Common auth headers
  // ─────────────────────────────────────────────────────────────────────────
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'apiuser': _apiUser,
        'apikey': _apiKey,
      };

  /// Makes an HTTP request with retry logic for transient DNS/socket errors.
  Future<http.Response> _requestWithRetry(
    Future<http.Response> Function() requestFn, {
    int maxRetries = 2,
  }) async {
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        return await requestFn().timeout(const Duration(seconds: 30));
      } on SocketException catch (e) {
        debugPrint('FapshiService: SocketException (attempt ${attempt + 1}/${maxRetries + 1}): $e');
        if (attempt == maxRetries) {
          throw FapshiException(
            'Cannot reach Fapshi servers ($_baseUrl). '
            'Please check your internet connection and try again.',
            0,
          );
        }
        // Wait before retrying
        await Future.delayed(Duration(seconds: 1 * (attempt + 1)));
      } on http.ClientException catch (e) {
        debugPrint('FapshiService: ClientException (attempt ${attempt + 1}/${maxRetries + 1}): $e');
        if (attempt == maxRetries) {
          throw FapshiException(
            'Cannot reach Fapshi servers ($_baseUrl). '
            'Please check your internet connection and try again.',
            0,
          );
        }
        await Future.delayed(Duration(seconds: 1 * (attempt + 1)));
      }
    }
    // Should not reach here
    throw FapshiException('Request failed after retries', 0);
  }

  /// Parses a Fapshi error response and throws a descriptive exception.
  Never _handleErrorResponse(http.Response response) {
    String msg;
    try {
      final data = json.decode(response.body) as Map<String, dynamic>;
      msg = (data['message'] ?? 'Unknown error').toString();
    } catch (_) {
      msg = response.body.isNotEmpty ? response.body : 'Unknown error';
    }

    // Provide more helpful messages for common errors
    if (response.statusCode == 403) {
      msg = '$msg — This may be caused by IP whitelisting on your '
          'Fapshi dashboard. Disable IP whitelisting or add your IP.';
    } else if (msg.toLowerCase().contains('invalid apiuser') ||
               msg.toLowerCase().contains('invalid apikey')) {
      msg = '$msg — Check that your apiUser and apiKey in Firestore '
          '(admin_settings/fapshi) match the credentials on your '
          'Fapshi dashboard for the "${_baseUrl.contains("sandbox") ? "sandbox" : "live"}" environment.';
    }

    debugPrint('FapshiService: API error ${response.statusCode}: $msg');
    throw FapshiException(msg, response.statusCode);
  }

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
    await _initCredentials();

    // Validate credentials before making the request
    if (_apiUser.isEmpty || _apiKey.isEmpty) {
      throw FapshiException(
        'Fapshi API credentials not configured. '
        'Please set apiUser and apiKey in Firestore (admin_settings/fapshi).',
        0,
      );
    }

    // Normalize phone: strip everything except digits, remove country code
    // Fapshi expects 9-digit local format (e.g., 671234567)
    String cleanPhone = phone.replaceAll(RegExp(r'[\s\-\+]'), '');
    // Remove 237 country code prefix if present
    if (cleanPhone.startsWith('237') && cleanPhone.length > 9) {
      cleanPhone = cleanPhone.substring(3);
    }
    // Remove leading 0 if present (e.g., 0671234567 → 671234567)
    if (cleanPhone.startsWith('0') && cleanPhone.length > 9) {
      cleanPhone = cleanPhone.substring(1);
    }

    final body = <String, dynamic>{
      'amount': amount,
      'phone': cleanPhone,
      'medium': medium,
      'message': message,
    };
    if (userId != null) body['userId'] = userId;
    if (externalId != null) body['externalId'] = externalId;

    debugPrint('FapshiService: directPay → $_baseUrl/direct-pay '
        '(amount=$amount, phone=$cleanPhone, medium=$medium)');

    try {
      final response = await _requestWithRetry(() => http.post(
        Uri.parse('$_baseUrl/direct-pay'),
        headers: _headers,
        body: json.encode(body),
      ));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final transId = data['transId'] as String?;
        debugPrint('FapshiService: directPay success — transId=$transId');
        return transId;
      } else {
        _handleErrorResponse(response);
      }
    } on FapshiException {
      rethrow;
    } catch (e) {
      throw FapshiException('Network error: $e', 0);
    }
  }

  /// Sends a Payout to a mobile money number.
  /// 
  /// [amount]  — amount in XAF
  /// [phone]   — recipient's phone number
  /// [medium]  — [mediumMTN] or [mediumOrange]
  /// 
  /// Returns true if the payout request was successful.
  Future<bool> sendPayout({
    required int amount,
    required String phone,
    required String medium,
  }) async {
    await _initCredentials();

    if (_apiUser.isEmpty || _apiKey.isEmpty) {
      throw FapshiException(
        'Fapshi API credentials not configured. '
        'Please set apiUser and apiKey in Firestore (admin_settings/fapshi).',
        0,
      );
    }

    // Normalize phone: strip everything except digits, remove country code
    // Fapshi expects 9-digit local format (e.g., 671234567)
    String cleanPhone = phone.replaceAll(RegExp(r'[\s\-\+]'), '');
    // Remove 237 country code prefix if present
    if (cleanPhone.startsWith('237') && cleanPhone.length > 9) {
      cleanPhone = cleanPhone.substring(3);
    }
    // Remove leading 0 if present
    if (cleanPhone.startsWith('0') && cleanPhone.length > 9) {
      cleanPhone = cleanPhone.substring(1);
    }

    final body = <String, dynamic>{
      'amount': amount,
      'phone': cleanPhone,
      'medium': medium,
    };

    debugPrint('FapshiService: sendPayout → $_baseUrl/payout '
        '(amount=$amount, phone=$cleanPhone, medium=$medium)');

    try {
      final response = await _requestWithRetry(() => http.post(
        Uri.parse('$_baseUrl/payout'),
        headers: _headers,
        body: json.encode(body),
      ));

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('FapshiService: payout success');
        return true;
      } else {
        _handleErrorResponse(response);
      }
    } on FapshiException {
      rethrow;
    } catch (e) {
      throw FapshiException('Network error: $e', 0);
    }
  }

  /// Polls the status of a Fapshi transaction.
  ///
  /// Returns one of: created, pending, successful, failed, expired
  Future<FapshiStatus> getPaymentStatus(String transId) async {
    await _initCredentials();
    try {
      final response = await _requestWithRetry(() => http.get(
        Uri.parse('$_baseUrl/payment-status/$transId'),
        headers: _headers,
      ));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Response is an object per the OpenAPI spec
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
        debugPrint('FapshiService: getPaymentStatus error ${response.statusCode}: ${response.body}');
        return FapshiStatus.failed;
      }
    } catch (e) {
      debugPrint('FapshiService: getPaymentStatus exception: $e');
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

