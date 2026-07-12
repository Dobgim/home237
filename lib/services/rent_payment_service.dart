import 'package:cloud_firestore/cloud_firestore.dart';
import 'fapshi_service.dart';

class RentPaymentService {
  final FapshiService _fapshiService = FapshiService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Initiates a rent payment using Fapshi direct pay (MTN/Orange MoMo push prompt)
  /// Writes a pending transaction record to Firestore
  Future<String?> payMonthlyRent({
    required String leaseId,
    required String tenantId,
    required String tenantName,
    required int amount,
    required String phone,
    required String propertyTitle,
  }) async {
    try {
      final String medium = phone.startsWith('67') || phone.startsWith('65') || phone.startsWith('68')
          ? FapshiService.mediumMTN
          : FapshiService.mediumOrange;

      // 1. Trigger the payment prompt via Fapshi
      final String? transId = await _fapshiService.directPay(
        amount: amount,
        phone: phone,
        medium: medium,
        message: 'Rent for $propertyTitle',
        userId: tenantId,
        externalId: leaseId,
      );

      if (transId == null) {
        throw Exception('Failed to initiate payment prompt.');
      }

      // 2. Write a pending transaction log in Firestore
      await _db.collection('rent_transactions').doc(transId).set({
        'leaseId': leaseId,
        'tenantId': tenantId,
        'tenantName': tenantName,
        'amount': amount,
        'phone': phone,
        'medium': medium,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'reference': transId,
        'propertyTitle': propertyTitle,
      });

      return transId;
    } catch (e) {
      print('❌ RentPaymentService Error: $e');
      rethrow;
    }
  }

  /// Polls status of rent payment and updates the transaction and lease records.
  Future<String> checkAndRecordPaymentStatus(String transId, String leaseId) async {
    try {
      final statusEnum = await _fapshiService.getPaymentStatus(transId);
      String statusStr = 'pending';

      if (statusEnum == FapshiStatus.successful) {
        statusStr = 'paid';
      } else if (statusEnum == FapshiStatus.failed) {
        statusStr = 'failed';
      } else if (statusEnum == FapshiStatus.expired) {
        statusStr = 'expired';
      }

      if (statusStr != 'pending') {
        // Update transaction status
        await _db.collection('rent_transactions').doc(transId).update({
          'status': statusStr,
          'resolvedAt': FieldValue.serverTimestamp(),
        });

        if (statusStr == 'paid') {
          // Update the lease's last payment date or status
          await _db.collection('leases').doc(leaseId).update({
            'lastPaidAt': FieldValue.serverTimestamp(),
            'status': 'active',
          });
        }
      }

      return statusStr;
    } catch (e) {
      print('❌ Error checking payment status: $e');
      return 'pending';
    }
  }

  /// Default platform commission on rent collected through the app, in
  /// percent. Overridable via Firestore admin_settings/fees.rentCommissionPercent.
  static const int defaultCommissionPercent = 5;

  /// Reads the platform commission percent set by the admin (0–20 allowed).
  Future<int> getCommissionPercent() async {
    try {
      final doc = await _db.collection('admin_settings').doc('fees').get();
      final raw = doc.data()?['rentCommissionPercent'];
      if (raw is num) return raw.toInt().clamp(0, 20);
    } catch (_) {}
    return defaultCommissionPercent;
  }

  /// Transfer funds to landlord's account (automated payout upon verification).
  ///
  /// Deducts the platform commission before the payout and records the
  /// commission in `platform_earnings` so revenue is auditable.
  Future<bool> payoutToLandlord({
    required int amount,
    required String landlordPhone,
    required String leaseId,
  }) async {
    try {
      final String medium = landlordPhone.startsWith('67') || landlordPhone.startsWith('65') || landlordPhone.startsWith('68')
          ? FapshiService.mediumMTN
          : FapshiService.mediumOrange;

      final commissionPercent = await getCommissionPercent();
      final commission = (amount * commissionPercent) ~/ 100;
      final netAmount = amount - commission;

      final success = await _fapshiService.sendPayout(
        amount: netAmount,
        phone: landlordPhone,
        medium: medium,
      );

      if (success) {
        await _db.collection('leases').doc(leaseId).update({
          'payoutStatus': 'completed',
          'payoutAt': FieldValue.serverTimestamp(),
          'payoutGross': amount,
          'payoutNet': netAmount,
          'platformCommission': commission,
        });
        if (commission > 0) {
          await _db.collection('platform_earnings').add({
            'type': 'rent_commission',
            'leaseId': leaseId,
            'grossAmount': amount,
            'commissionPercent': commissionPercent,
            'commission': commission,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      return success;
    } catch (e) {
      print('❌ Landlord Payout Error: $e');
      return false;
    }
  }
}
