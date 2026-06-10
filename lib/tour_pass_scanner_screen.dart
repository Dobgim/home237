import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';
import 'services/fapshi_service.dart';

class TourPassScannerScreen extends StatefulWidget {
  const TourPassScannerScreen({super.key});

  @override
  State<TourPassScannerScreen> createState() => _TourPassScannerScreenState();
}

class _TourPassScannerScreenState extends State<TourPassScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isProcessing = false;

  Future<void> _processQRCode(String rawData) async {
    if (_isProcessing) return;
    
    // Expected format: home237_escrow:TOUR_REQUEST_ID:ESCROW_CODE
    if (!rawData.startsWith('home237_escrow:')) {
      _showError('Invalid QR Code. This is not a Home237 Tour Pass.');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final parts = rawData.split(':');
      if (parts.length != 3) throw Exception('Malformed QR data');

      final tourRequestId = parts[1];
      final escrowCode = parts[2];

      // Verify the tour request
      final docRef = FirebaseFirestore.instance.collection('tour_requests').doc(tourRequestId);
      final docSnapshot = await docRef.get();

      if (!docSnapshot.exists) {
        throw Exception('Tour request not found in database.');
      }

      final data = docSnapshot.data() as Map<String, dynamic>;

      // Check if this landlord owns the request
      if (data['landlordId'] != authService.userId) {
        throw Exception('Unauthorized: This pass is for a different landlord.');
      }

      // Check tour pass code
      if (data['escrowCode'] != escrowCode) {
        throw Exception('Security Alert: Tour pass code mismatch.');
      }

      // Check status
      if (data['status'] == 'completed') {
        throw Exception('This pass has already been scanned and completed.');
      }

      if (data['status'] != 'escrowed' && data['status'] != 'approved') {
        throw Exception('This tour request is not currently approved or active.');
      }

      final transId = data['transId'];
      final amount = data['amount'] ?? 0;
      
      String? payoutMedium;
      String? landlordPhone;

      if (transId != null && amount > 0) {
        // --- Automated Payout to Landlord (legacy paid tours only) ---
        final landlordDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(data['landlordId'])
            .get();

        if (!landlordDoc.exists) {
          throw Exception('Landlord profile not found. Cannot payout.');
        }

        landlordPhone = landlordDoc.data()?['phone'] as String?;
        if (landlordPhone == null || landlordPhone.isEmpty) {
          throw Exception('Landlord has no registered phone number in their profile to receive the payout.');
        }

        payoutMedium = landlordPhone.startsWith('67') || landlordPhone.startsWith('65') || landlordPhone.startsWith('68')
            ? FapshiService.mediumMTN
            : FapshiService.mediumOrange;

        final FapshiService fapshiService = FapshiService();
        
        final payoutSuccess = await fapshiService.sendPayout(
          amount: amount,
          phone: landlordPhone,
          medium: payoutMedium,
        );

        if (!payoutSuccess) {
          throw Exception('Payout transfer failed. Please check Fapshi balance.');
        }
      }

      // Update to completed!
      final updates = <String, dynamic>{
        'status': 'completed',
        'completedAt': DateTime.now(),
      };
      
      if (transId != null && amount > 0) {
        updates['escrowPayoutStatus'] = 'payout_sent';
        if (payoutMedium != null) updates['escrowPayoutMedium'] = payoutMedium;
        if (landlordPhone != null) updates['escrowPayoutNumber'] = landlordPhone;
      }
      
      await docRef.update(updates);

      if (mounted) {
        _scannerController.stop();
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF10B981)),
                SizedBox(width: 8),
                Text('Visit Verified!'),
              ],
            ),
            content: Text(
              transId != null && amount > 0
                  ? 'Successfully verified! The viewing fee has been released to your account.'
                  : 'Successfully verified! The tour check-in has been recorded and marked as completed.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context); // close scanner
                },
                child: const Text('Great'),
              )
            ],
          ),
        );
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }



  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Scan Tenant Pass', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _processQRCode(barcode.rawValue!);
                  break;
                }
              }
            },
          ),
          
          // Scanner Overlay
          Container(
            decoration: ShapeDecoration(
              shape: QrScannerOverlayShape(
                borderColor: const Color(0xFF10B981),
                borderRadius: 24,
                borderLength: 40,
                borderWidth: 8,
                cutOutSize: MediaQuery.of(context).size.width * 0.75,
              ),
            ),
          ),

          // Glassmorphic Bottom Panel
          Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white24, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.qr_code_scanner, color: Color(0xFF10B981)),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Scan Tour Pass',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Point your camera at the tenant\'s tour pass QR code to verify their visit.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (_isProcessing)
            Container(
              color: Colors.black.withValues(alpha: 0.8),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF10B981)),
                    SizedBox(height: 24),
                    Text(
                      'Verifying Tour Pass...', 
                      style: TextStyle(
                        color: Colors.white, 
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 1.1,
                      )
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  const QrScannerOverlayShape({
    this.borderColor = Colors.white,
    this.borderWidth = 3.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 80),
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
  });

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10.0);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path getLeftTopPath(Rect rect) {
      return Path()
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.top)
        ..lineTo(rect.right, rect.top);
    }
    return getLeftTopPath(rect)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..lineTo(rect.left, rect.top);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final height = rect.height;
    final borderOffset = borderWidth / 2;
    final localBorderLength = borderLength > cutOutSize / 2 + borderOffset
        ? cutOutSize / 2 + borderOffset
        : borderLength;
    final localCutOutSize = cutOutSize;

    final backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final boxPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.dstOut;

    final cutOutRect = Rect.fromLTWH(
      rect.left + width / 2 - localCutOutSize / 2,
      rect.top + height / 2 - localCutOutSize / 2,
      localCutOutSize,
      localCutOutSize,
    );

    canvas
      ..saveLayer(rect, backgroundPaint)
      ..drawRect(rect, backgroundPaint)
      ..drawRRect(
        RRect.fromRectAndCorners(
          cutOutRect,
          topLeft: Radius.circular(borderRadius),
          topRight: Radius.circular(borderRadius),
          bottomLeft: Radius.circular(borderRadius),
          bottomRight: Radius.circular(borderRadius),
        ),
        boxPaint,
      )
      ..restore();

    canvas
      ..drawPath(
        Path()
          ..moveTo(cutOutRect.left, cutOutRect.top + localBorderLength)
          ..lineTo(cutOutRect.left, cutOutRect.top + borderRadius)
          ..arcToPoint(
            Offset(cutOutRect.left + borderRadius, cutOutRect.top),
            radius: Radius.circular(borderRadius),
          )
          ..lineTo(cutOutRect.left + localBorderLength, cutOutRect.top),
        borderPaint,
      )
      ..drawPath(
        Path()
          ..moveTo(cutOutRect.right, cutOutRect.top + localBorderLength)
          ..lineTo(cutOutRect.right, cutOutRect.top + borderRadius)
          ..arcToPoint(
            Offset(cutOutRect.right - borderRadius, cutOutRect.top),
            radius: Radius.circular(borderRadius),
          )
          ..lineTo(cutOutRect.right - localBorderLength, cutOutRect.top),
        borderPaint,
      )
      ..drawPath(
        Path()
          ..moveTo(cutOutRect.left, cutOutRect.bottom - localBorderLength)
          ..lineTo(cutOutRect.left, cutOutRect.bottom - borderRadius)
          ..arcToPoint(
            Offset(cutOutRect.left + borderRadius, cutOutRect.bottom),
            radius: Radius.circular(borderRadius),
            clockwise: false,
          )
          ..lineTo(cutOutRect.left + localBorderLength, cutOutRect.bottom),
        borderPaint,
      )
      ..drawPath(
        Path()
          ..moveTo(cutOutRect.right, cutOutRect.bottom - localBorderLength)
          ..lineTo(cutOutRect.right, cutOutRect.bottom - borderRadius)
          ..arcToPoint(
            Offset(cutOutRect.right - borderRadius, cutOutRect.bottom),
            radius: Radius.circular(borderRadius),
          )
          ..lineTo(cutOutRect.right - localBorderLength, cutOutRect.bottom),
        borderPaint,
      );
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth,
      overlayColor: overlayColor,
    );
  }
}
