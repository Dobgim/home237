import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class MomoService {
  // ─────────────────────────────────────────────────────────────
  // CREDENTIALS - PASTE YOUR KEYS HERE
  // ─────────────────────────────────────────────────────────────
  static const String mtnUserId = '066137d2-a29b-4486-8cd0-69a5432b2261';
  static const String mtnApiKey = '2cad2baa7b794a9cbb341bff946f2a78';
  static const String mtnSubscriptionKey = '9849668f1a2b46e2915f632fd63ae59b';
  
  static const String baseUrl = 'https://sandbox.momodeveloper.mtn.com';
  static const String targetEnvironment = 'sandbox';

  /// Generates a temporary OAuth 2.0 access token
  Future<String?> getAccessToken() async {
    final String auth = base64Encode(utf8.encode('$mtnUserId:$mtnApiKey'));
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/collection/token/'),
        headers: {
          'Authorization': 'Basic $auth',
          'Ocp-Apim-Subscription-Key': mtnSubscriptionKey,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['access_token'];
      } else {
        print('❌ Momo Auth Error: ${response.statusCode}');
        print('❌ Momo Auth Response: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Momo Auth Exception: $e');
      return null;
    }
  }

  /// Initiates a payment request (Request to Pay)
  /// Returns a 'momoReferenceId' (UUID) if successful
  Future<String?> requestPayment({
    required String amount,
    required String phoneNumber,
    required String currency,
    required String externalId,
    required String payerMessage,
    required String payeeNote,
  }) async {
    final token = await getAccessToken();
    if (token == null) return null;

    // We need a unique reference ID for this specific transaction
    final String momoReferenceId = const Uuid().v4();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/collection/v1_0/requesttopay'),
        headers: {
          'Authorization': 'Bearer $token',
          'X-Reference-Id': momoReferenceId,
          'X-Target-Environment': targetEnvironment,
          'Ocp-Apim-Subscription-Key': mtnSubscriptionKey,
          'Content-Type': 'application/json',
        },
        body: json.encode({
          "amount": amount,
          "currency": currency,
          "externalId": externalId,
          "payer": {
            "partyIdType": "MSISDN",
            "partyId": phoneNumber // e.g. "2376XXXXXXXX"
          },
          "payerMessage": payerMessage,
          "payeeNote": payeeNote
        }),
      );

      if (response.statusCode == 202) {
        return momoReferenceId;
      } else {
        print('❌ Momo Payment Error: ${response.statusCode}');
        print('❌ Momo Payment Response: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Momo Payment Exception: $e');
      return null;
    }
  }

  /// Checks the status of a payment request
  /// Returns 'SUCCESSFUL', 'FAILED', or 'PENDING'
  Future<String> getPaymentStatus(String momoReferenceId) async {
    final token = await getAccessToken();
    if (token == null) return 'FAILED';

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/collection/v1_0/requesttopay/$momoReferenceId'),
        headers: {
          'Authorization': 'Bearer $token',
          'X-Target-Environment': targetEnvironment,
          'Ocp-Apim-Subscription-Key': mtnSubscriptionKey,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'] ?? 'PENDING';
      } else {
        return 'FAILED';
      }
    } catch (e) {
      return 'FAILED';
    }
  }
}
