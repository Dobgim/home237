import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';
import 'services/fapshi_service.dart';
import 'email_service.dart';

class TourPassScannerScreen extends StatefulWidget {
  const TourPassScannerScreen({super.key});

  @override
  State<TourPassScannerScreen> createState() => _TourPassScannerScreenState();
}

class _TourPassScannerScreenState extends State<TourPassScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isProcessing = false;
  // Once a valid pass is scanned we ignore every further camera detection —
  // otherwise stray reads fire "invalid QR" errors over the payout dialog.
  bool _scanHandled = false;

  Future<void> _processQRCode(String rawData) async {
    if (_isProcessing || _scanHandled) return;

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

      final docRef =
          FirebaseFirestore.instance.collection('tour_requests').doc(tourRequestId);
      final docSnapshot = await docRef.get();

      if (!docSnapshot.exists) {
        throw Exception('Tour request not found in database.');
      }

      final data = docSnapshot.data() as Map<String, dynamic>;

      if (data['landlordId'] != authService.userId) {
        throw Exception('Unauthorized: This pass is for a different landlord.');
      }
      if (data['escrowCode'] != escrowCode) {
        throw Exception('Security Alert: Tour pass code mismatch.');
      }
      if (data['status'] == 'completed') {
        throw Exception('This pass has already been scanned and completed.');
      }
      if (data['status'] != 'escrowed' && data['status'] != 'approved') {
        throw Exception('This tour request is not currently approved or active.');
      }

      // Valid pass — stop the camera and collect the agent's payout details.
      // From here on, ignore every further camera detection.
      _scanHandled = true;
      _scannerController.stop();
      if (mounted) {
        setState(() => _isProcessing = false);
        await _showAgentPayoutForm(docRef, data);
      }
    } catch (e) {
      _showError(e.toString());
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// After a valid scan, ask the agent for the name + Mobile Money number the
  /// fee should be sent to (the agent never stored a number before).
  Future<void> _showAgentPayoutForm(
      DocumentReference docRef, Map<String, dynamic> data) async {
    final amount = (data['amount'] ?? 0) is int ? (data['amount'] ?? 0) as int : 0;

    // Free / legacy check-in (no fee) — just mark completed.
    if (amount <= 0) {
      await docRef.update({'status': 'completed', 'completedAt': DateTime.now()});
      if (mounted) _showSuccessDialog(released: false, amount: 0);
      return;
    }

    final nameCtrl = TextEditingController(text: authService.userName ?? '');
    final phoneCtrl = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool submitting = false;
        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.verified_user, color: Color(0xFF10B981)),
                SizedBox(width: 8),
                Expanded(child: Text('Receive Visit Fee')),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Enter the name and Mobile Money number to receive the '
                    '${_money(amount)} FCFA visit fee.',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  enabled: !submitting,
                  decoration: const InputDecoration(
                    labelText: 'Agent name *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  enabled: !submitting,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile Money number *',
                    hintText: '6XXXXXXXX',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: submitting
                    ? null
                    : () async {
                        final name = nameCtrl.text.trim();
                        final phone = phoneCtrl.text.trim();
                        if (name.isEmpty) {
                          _showError('Please enter the agent name');
                          return;
                        }
                        if (phone.length < 9) {
                          _showError('Enter a valid Mobile Money number');
                          return;
                        }
                        setStateDialog(() => submitting = true);
                        try {
                          await _releasePayout(docRef, data, name, phone, amount);
                          // Close the form FIRST, then show the success dialog
                          // (otherwise the pop would dismiss the success dialog).
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            _showSuccessDialog(released: true, amount: amount);
                          }
                        } catch (e) {
                          setStateDialog(() => submitting = false);
                          _showError(e.toString().replaceAll('Exception: ', ''));
                        }
                      },
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white),
                child: submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text('Release ${_money(amount)} FCFA'),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Sends the fee to the agent's number, marks the request completed, and
  /// emails a receipt to the home-seeker.
  Future<void> _releasePayout(DocumentReference docRef, Map<String, dynamic> data,
      String agentName, String agentPhone, int amount) async {
    final last9 = agentPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final medium = (last9.startsWith('67') || last9.startsWith('65') || last9.startsWith('68'))
        ? FapshiService.mediumMTN
        : FapshiService.mediumOrange;

    final ok = await FapshiService()
        .sendPayout(amount: amount, phone: agentPhone, medium: medium)
        .timeout(const Duration(seconds: 60),
            onTimeout: () => throw Exception(
                'The transfer is taking too long. Please check your connection and try again.'));
    if (!ok) {
      throw Exception('Payout failed. Please check the Fapshi balance and try again.');
    }

    await docRef.update({
      'status': 'completed',
      'completedAt': DateTime.now(),
      'escrowPayoutStatus': 'payout_sent',
      'escrowPayoutMedium': medium,
      'escrowPayoutNumber': agentPhone,
      'agentName': agentName,
    });

    // Fire-and-forget receipt email with a hard timeout — SMTP can be slow on
    // mobile networks and must never block the payout UI.
    // ignore: unawaited_futures
    _sendReceiptEmail(docRef.id, data, agentName, agentPhone, amount);
  }

  Future<void> _sendReceiptEmail(String requestId, Map<String, dynamic> data,
      String agentName, String agentPhone, int amount) async {
    try {
      final tenantId = data['tenantId'];
      if (tenantId == null) return;
      final tenantDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(tenantId.toString())
          .get();
      final email = tenantDoc.data()?['email']?.toString();
      if (email == null || email.isEmpty) return;

      final receiptNo = requestId.substring(0, 8).toUpperCase();
      final now = DateTime.now();
      final dateStr = '${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';
      final maskedPhone = agentPhone.length >= 4
          ? '****${agentPhone.substring(agentPhone.length - 4)}'
          : agentPhone;
      final property = data['propertyTitle'] ?? 'Property';

      final html = '''
<div style="font-family: Arial, sans-serif; max-width: 520px; margin: 0 auto; border: 1px solid #e5e7eb; border-radius: 12px; overflow: hidden;">
  <div style="background: #1E3A5F; padding: 24px; text-align: center;">
    <h1 style="color: white; margin: 0; font-size: 22px;">🏠 Home237 — Visit Fee Receipt</h1>
  </div>
  <div style="padding: 28px; background: #f9fafb;">
    <p style="color: #10B981; font-weight: bold; font-size: 16px; margin-top: 0;">✅ Visit fee released &amp; received by the agent</p>
    <p style="color: #475569; font-size: 14px;">This confirms your visit fee has been released from escrow to the agent who met you.</p>
    <table style="width: 100%; border-collapse: collapse; margin-top: 16px; font-size: 14px; color: #334155;">
      <tr><td style="padding: 8px 0; color:#64748b;">Receipt No.</td><td style="padding: 8px 0; text-align:right; font-weight:bold;">$receiptNo</td></tr>
      <tr><td style="padding: 8px 0; color:#64748b;">Date</td><td style="padding: 8px 0; text-align:right;">$dateStr</td></tr>
      <tr><td style="padding: 8px 0; color:#64748b;">Property</td><td style="padding: 8px 0; text-align:right;">$property</td></tr>
      <tr><td style="padding: 8px 0; color:#64748b;">Agent</td><td style="padding: 8px 0; text-align:right; font-weight:bold;">$agentName</td></tr>
      <tr><td style="padding: 8px 0; color:#64748b;">Agent MoMo</td><td style="padding: 8px 0; text-align:right;">$maskedPhone</td></tr>
      <tr><td style="padding: 12px 0; color:#64748b; border-top:1px solid #e2e8f0;">Amount</td><td style="padding: 12px 0; text-align:right; border-top:1px solid #e2e8f0; font-weight:bold; font-size:16px;">${_money(amount)} FCFA</td></tr>
    </table>
    <p style="color: #9ca3af; font-size: 12px; margin-top: 20px;">Thank you for using Home237. If you did not attend this visit, please contact support immediately.</p>
  </div>
</div>
''';

      await EmailService.sendHtmlEmail(
              email, 'Home237 Visit Fee Receipt — $receiptNo', html)
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      // Receipt email is non-critical; swallow errors.
      debugPrint('Receipt email failed: $e');
    }
  }

  String _money(int amount) => amount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  void _showSuccessDialog({required bool released, required int amount}) {
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
          released
              ? '✅ Successfully released!\n\nThe ${_money(amount)} FCFA visit fee has been sent '
                  'to the number you entered. A receipt is being emailed to the home-seeker.'
              : 'The visit check-in has been recorded and marked as completed.',
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
