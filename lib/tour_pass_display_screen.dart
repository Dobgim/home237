import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TourPassDisplayScreen extends StatelessWidget {
  final String tourRequestId;
  final String escrowCode;
  final String propertyTitle;

  const TourPassDisplayScreen({
    super.key,
    required this.tourRequestId,
    required this.escrowCode,
    required this.propertyTitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // The data we encode into the QR code
    final String qrData = 'home237_escrow:$tourRequestId:$escrowCode';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Tour Pass', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark 
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Main Pass Card
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.white,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'APPROVED TOUR PASS',
                              style: TextStyle(
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            propertyTitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Present this QR code to the agent when you arrive for your property tour.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14, 
                              color: isDark ? Colors.white60 : Colors.grey[600],
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 32),
                          // QR Code
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: QrImageView(
                              data: qrData,
                              version: QrVersions.auto,
                              size: 220.0,
                              backgroundColor: Colors.white,
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: Color(0xFF1E293B),
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.verified_rounded, size: 20, color: Color(0xFF10B981)),
                              SizedBox(width: 8),
                              Text(
                                'Free tour — verified by Home237',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('tour_requests')
                          .doc(tourRequestId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          final data = snapshot.data!.data() as Map<String, dynamic>?;
                          final status = data?['status'] as String?;
                          
                          if (status == 'completed') {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _showSuccessDialog(context);
                            });
                          }
                        }
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: isDark ? Colors.white54 : Colors.grey[500],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Waiting for agent to scan...',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white70 : Colors.grey[600],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF10B981)),
            SizedBox(width: 8),
            Text('Tour Completed!'),
          ],
        ),
        content: const Text(
          'Your tour check-in was successfully scanned and completed!'
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // close dialog
              Navigator.pop(context); // close QR screen
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
