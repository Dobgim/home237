import 'package:cloud_firestore/cloud_firestore.dart';

/// Helper class to initialize Firestore collections and add sample data
/// for testing the admin dashboard
class FirestoreInitializer {
  static Future<void> initializeCollections() async {
    await _createVerificationsCollection();
    await _createReportsCollection();
    await _setupPropertyNotifications();
  }

  /// Create verifications collection with sample data
  static Future<void> _createVerificationsCollection() async {
    final verifications = FirebaseFirestore.instance.collection('verifications');

    // Sample pending verification
    await verifications.add({
      'userId': 'sample_user_123',
      'userName': 'John Smith',
      'userEmail': 'john.smith@example.com',
      'fullName': 'John Michael Smith',
      'dateOfBirth': 'October 23, 2026',
      'phone': '+1 (415) 555-0123',
      'companyName': 'Smith Properties LLC',
      'taxId': 'XX-XXXX456',
      'businessAddress': '123 Main St, Suite 100\nSan Francisco, CA 94102',
      'documents': [
        {
          'type': 'drivers_license',
          'url': 'https://example.com/license.jpg',
          'uploadedAt': FieldValue.serverTimestamp(),
        },
        {
          'type': 'tax_certificate',
          'url': 'https://example.com/tax_cert.pdf',
          'uploadedAt': FieldValue.serverTimestamp(),
        },
      ],
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Sample approved verification
    await verifications.add({
      'userId': 'sample_user_456',
      'userName': 'Sarah Jenkins',
      'userEmail': 'sarah.jenkins@example.com',
      'fullName': 'Sarah Anne Jenkins',
      'dateOfBirth': 'October 22, 2026',
      'phone': '+1 (415) 555-0456',
      'companyName': 'Jenkins Real Estate',
      'taxId': 'XX-XXXX789',
      'businessAddress': '456 Oak Ave\nSan Francisco, CA 94103',
      'status': 'approved',
      'createdAt': FieldValue.serverTimestamp(),
      'reviewedAt': FieldValue.serverTimestamp(),
    });

    print('✅ Verifications collection created with sample data');
  }

  /// Create reports collection with sample data
  static Future<void> _createReportsCollection() async {
    final reports = FirebaseFirestore.instance.collection('reports');

    // Sample open report
    await reports.add({
      'propertyId': 'sample_property_123',
      'propertyTitle': '123 Maple St - Leak',
      'landlordId': 'sample_landlord_123',
      'reportedBy': 'tenant_456',
      'reporterName': 'Mike Johnson',
      'type': 'maintenance',
      'severity': 'high',
      'description': 'Urgent property report: Active flood in basement',
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Sample resolved report
    await reports.add({
      'propertyId': 'sample_property_456',
      'propertyTitle': '456 Oak Ave - AC Issue',
      'landlordId': 'sample_landlord_456',
      'reportedBy': 'tenant_789',
      'reporterName': 'Jane Doe',
      'type': 'maintenance',
      'severity': 'medium',
      'description': 'Air conditioning not working',
      'status': 'resolved',
      'createdAt': Timestamp.fromDate(
        DateTime.now().subtract(const Duration(days: 5)),
      ),
      'resolvedAt': FieldValue.serverTimestamp(),
    });

    print('✅ Reports collection created with sample data');
  }

  /// Setup Cloud Firestore triggers for property notifications
  /// Note: This requires Cloud Functions to be set up
  static Future<void> _setupPropertyNotifications() async {
    print('''
    📝 To enable real-time notifications when landlords post properties:
    
    1. Set up Firebase Cloud Functions
    2. Add this function to your Cloud Functions:
    
    exports.notifyAdminOnNewProperty = functions.firestore
      .document('properties/{propertyId}')
      .onCreate(async (snap, context) => {
        const property = snap.data();
        
        // Get all admin users
        const adminsSnapshot = await admin.firestore()
          .collection('users')
          .where('role', '==', 'admin')
          .get();
        
        // Send notification to each admin
        const notifications = adminsSnapshot.docs.map(adminDoc => {
          return admin.firestore()
            .collection('notifications')
            .doc(adminDoc.id)
            .collection('items')
            .add({
              title: 'New Property Posted',
              message: `\${property.landlordName} posted "\${property.title}"`,
              type: 'property',
              propertyId: context.params.propertyId,
              read: false,
              timestamp: admin.firestore.FieldValue.serverTimestamp(),
            });
        });
        
        await Promise.all(notifications);
      });
    ''');
  }

  /// Update existing property to require manual approval
  static Future<void> markPropertyForManualApproval(String propertyId) async {
    await FirebaseFirestore.instance
        .collection('properties')
        .doc(propertyId)
        .update({
      'requiresManualApproval': true,
      'approvalReason': 'High-value property',
    });
  }

  /// Create a sample verification request for testing
  static Future<String> createSampleVerification({
    required String userId,
    required String userName,
    required String userEmail,
  }) async {
    final doc = await FirebaseFirestore.instance
        .collection('verifications')
        .add({
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'fullName': '$userName Full Name',
      'dateOfBirth': 'March 14, 1978',
      'phone': '+1 (415) 555-0198',
      'companyName': '$userName Property Group LLC',
      'taxId': 'XX-XXXX892',
      'businessAddress': '742 Market St, Ste 400\nSan Francisco, CA 94102',
      'documents': [
        {
          'type': 'drivers_license',
          'url': 'https://example.com/license_$userId.jpg',
          'uploadedAt': FieldValue.serverTimestamp(),
        },
        {
          'type': 'tax_certificate',
          'url': 'https://example.com/tax_cert_$userId.pdf',
          'uploadedAt': FieldValue.serverTimestamp(),
        },
      ],
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  /// Create a sample report for testing
  static Future<String> createSampleReport({
    required String propertyId,
    required String propertyTitle,
    required String description,
  }) async {
    final doc = await FirebaseFirestore.instance
        .collection('reports')
        .add({
      'propertyId': propertyId,
      'propertyTitle': propertyTitle,
      'landlordId': 'sample_landlord',
      'reportedBy': 'sample_tenant',
      'reporterName': 'Sample Reporter',
      'type': 'maintenance',
      'severity': 'high',
      'description': description,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }
}