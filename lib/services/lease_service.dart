import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../email_service.dart';

class LeaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Creates a lease agreement in Firestore
  Future<String> createLease({
    required String propertyId,
    required String propertyTitle,
    required String propertyCity,
    required String propertyNeighborhood,
    required String landlordId,
    required String landlordName,
    required String landlordEmail,
    required String tenantId,
    required String tenantName,
    required String tenantEmail,
    required int rentAmount,
    required int durationMonths,
  }) async {
    try {
      final leaseId = const Uuid().v4();
      final escrowCode = const Uuid().v4().substring(0, 8).toUpperCase();

      await _db.collection('leases').doc(leaseId).set({
        'id': leaseId,
        'propertyId': propertyId,
        'propertyTitle': propertyTitle,
        'propertyCity': propertyCity,
        'propertyNeighborhood': propertyNeighborhood,
        'landlordId': landlordId,
        'landlordName': landlordName,
        'landlordEmail': landlordEmail,
        'tenantId': tenantId,
        'tenantName': tenantName,
        'tenantEmail': tenantEmail,
        'rentAmount': rentAmount,
        'durationMonths': durationMonths,
        'status': 'pending', // pending, active, ended
        'escrowCode': escrowCode,
        'createdAt': FieldValue.serverTimestamp(),
        'signedAt': null,
      });

      // Send automated lease email
      await sendLeaseEmail(
        tenantEmail: tenantEmail,
        landlordEmail: landlordEmail,
        tenantName: tenantName,
        landlordName: landlordName,
        propertyTitle: propertyTitle,
        propertyLocation: '$propertyNeighborhood, $propertyCity',
        rentAmount: rentAmount,
        durationMonths: durationMonths,
        escrowCode: escrowCode,
      );

      return leaseId;
    } catch (e) {
      print('❌ LeaseService Error: $e');
      rethrow;
    }
  }

  /// Sends the lease agreement content as an email using the established EmailService configuration
  Future<void> sendLeaseEmail({
    required String tenantEmail,
    required String landlordEmail,
    required String tenantName,
    required String landlordName,
    required String propertyTitle,
    required String propertyLocation,
    required int rentAmount,
    required int durationMonths,
    required String escrowCode,
  }) async {
    try {
      // Create HTML content for the email
      final htmlContent = '''
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; border: 1px solid #e5e7eb; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.05);">
        <div style="background: #0EA5E9; padding: 24px; text-align: center; color: white;">
          <h1 style="margin: 0; font-size: 22px; font-weight: bold; letter-spacing: 0.5px;">🏡 Home237 Digital Lease</h1>
          <p style="margin: 6px 0 0 0; opacity: 0.9; font-size: 14px;">Contract Reference: #$escrowCode</p>
        </div>
        <div style="background: white; padding: 32px; color: #1e293b; line-height: 1.6;">
          <h2 style="font-size: 18px; color: #0EA5E9; border-bottom: 2px solid #f1f5f9; padding-bottom: 8px; margin-top: 0;">Residential Tenancy Agreement</h2>
          
          <p>This document serves as a binding digital agreement between the following parties:</p>
          
          <table style="width: 100%; border-collapse: collapse; margin: 16px 0;">
            <tr>
              <td style="padding: 8px 0; font-weight: bold; width: 35%;">Landlord:</td>
              <td style="padding: 8px 0;">$landlordName</td>
            </tr>
            <tr>
              <td style="padding: 8px 0; font-weight: bold;">Tenant:</td>
              <td style="padding: 8px 0;">$tenantName</td>
            </tr>
            <tr>
              <td style="padding: 8px 0; font-weight: bold;">Property Details:</td>
              <td style="padding: 8px 0;">$propertyTitle ($propertyLocation)</td>
            </tr>
            <tr>
              <td style="padding: 8px 0; font-weight: bold;">Monthly Rent:</td>
              <td style="padding: 8px 0; color: #0EA5E9; font-weight: bold;">$rentAmount XAF / Month</td>
            </tr>
            <tr>
              <td style="padding: 8px 0; font-weight: bold;">Duration:</td>
              <td style="padding: 8px 0;">$durationMonths Months</td>
            </tr>
            <tr>
              <td style="padding: 8px 0; font-weight: bold;">Escrow Security Pin:</td>
              <td style="padding: 8px 0; font-family: monospace; font-size: 16px; font-weight: bold; color: #10B981;">$escrowCode</td>
            </tr>
          </table>

          <div style="background: #f8fafc; border-left: 4px solid #0EA5E9; padding: 16px; margin: 24px 0; border-radius: 4px;">
            <h3 style="margin: 0 0 8px 0; font-size: 14px; font-weight: bold; color: #0f172a;">Key Terms & Conditions</h3>
            <ol style="margin: 0; padding-left: 20px; font-size: 13px; color: #475569;">
              <li>The Tenant agrees to pay the monthly rent through the Home237 application by the 5th of each month.</li>
              <li>The Landlord agrees to maintain the property in a tenantable condition.</li>
              <li>Escrow release of the first month's rent deposit will occur upon physical check-in using the QR code handshake.</li>
              <li>Either party must provide a 1-month notice prior to terminating this agreement.</li>
            </ol>
          </div>

          <div style="text-align: center; margin-top: 32px;">
            <div style="display: inline-block; padding: 12px 24px; background: #10B981; color: white; border-radius: 8px; font-weight: bold; font-size: 14px;">
              ✓ Digitally Signed & Escrow Verified
            </div>
            <p style="font-size: 11px; color: #94a3b8; margin-top: 8px;">Secured and verified via Home237 trust networks.</p>
          </div>
        </div>
        <div style="background: #f1f5f9; padding: 16px; text-align: center; font-size: 12px; color: #94a3b8;">
          This is an auto-generated legal document sent from Home237.<br>
          © 2026 Home237. Yaoundé & Douala, Cameroon.
        </div>
      </div>
      ''';

      // Dispatch the HTML lease agreement to both tenant and landlord
      await EmailService.sendHtmlEmail(tenantEmail, 'Your Home237 Digital Lease Agreement (#$escrowCode)', htmlContent);
      await EmailService.sendHtmlEmail(landlordEmail, 'New Home237 Tenant Digital Lease Agreement (#$escrowCode)', htmlContent);
      print('✅ HTML Lease Agreement emails sent successfully!');
    } catch (e) {
      print('❌ Failed to email lease: $e');
    }
  }

  /// Generates plain-text printable contract terms
  String generateLeaseText({
    required String landlordName,
    required String tenantName,
    required String propertyTitle,
    required String propertyLocation,
    required int rentAmount,
    required int durationMonths,
    required String escrowCode,
  }) {
    return '''
============================================================
              RESIDENTIAL LEASE AGREEMENT
============================================================
Ref: #$escrowCode
Date: ${DateTime.now().toLocal().toString().split(' ')[0]}

1. PARTIES:
This agreement is made between:
Landlord: $landlordName
Tenant: $tenantName

2. PROPERTY:
The Landlord agrees to rent to the Tenant the property located at:
Property: $propertyTitle
Location: $propertyLocation

3. RENT & FEES:
- Rent Amount: $rentAmount XAF per Month
- Payment Due: 5th of every month
- Payment Channel: Home237 Mobile Money Wallet (MTN/Orange)

4. DURATION:
This tenancy shall begin on the date of physical QR verification and
will continue for a period of $durationMonths Months.

5. TERMS & CONDITIONS:
A. The Tenant agrees to pay rent on time. Late payments will incur a 5% fee.
B. The Tenant will maintain the interior of the premises in clean and good condition.
C. The Landlord agrees to handle structural repairs (plumbing, electrical wiring) within 72 hours of notification.
D. The initial deposit is secured in the Home237 Escrow Wallet and is released immediately when the Landlord scans the Tenant's QR check-in code.

SIGNATURES:
Landlord: [Digitally Signed via QR Check-in]
Tenant: [Digitally Signed via Escrow Verification]

Verified by: Home237 Escrow Ledger
============================================================
''';
  }
}
