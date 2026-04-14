import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';
import 'services/fapshi_service.dart';
import 'dart:async';

class PremiumSubscriptionScreen extends StatefulWidget {
  const PremiumSubscriptionScreen({super.key});

  @override
  State<PremiumSubscriptionScreen> createState() =>
      _PremiumSubscriptionScreenState();
}

class _PremiumSubscriptionScreenState
    extends State<PremiumSubscriptionScreen> {
  bool _isLoading = false;
  String _loadingMessage = 'Processing Payment...';
  final FapshiService _fapshi = FapshiService();

  // ── Phone number dialog ────────────────────────────────────────────────────

  void _showPhoneDialog(String provider) {
    final TextEditingController phoneCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMTN = provider == 'MTN';
    final primaryColor =
        isMTN ? const Color(0xFFFFCC00) : const Color(0xFFFF7900);
    final medium = isMTN ? FapshiService.mediumMTN : FapshiService.mediumOrange;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor:
            isDark ? const Color(0xFF1E2937) : Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            // Provider logo / color indicator
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  isMTN ? 'MTN' : 'OM',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isMTN ? Colors.black87 : Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Pay with ${isMTN ? 'MTN MoMo' : 'Orange Money'}',
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Amount summary
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: primaryColor.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: primaryColor.withAlpha(60), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total to pay',
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.white60
                              : Colors.grey[600])),
                  const SizedBox(height: 4),
                  const Text('5,000 FCFA',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold)),
                  const Text('1 month Premium subscription',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Your ${isMTN ? 'MTN' : 'Orange'} number',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              autofocus: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 16),
              decoration: InputDecoration(
                hintText: '6XX XXX XXX',
                hintStyle: TextStyle(
                    color: isDark ? Colors.white38 : Colors.grey[400]),
                prefixIcon: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '+237',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color:
                              isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                          height: 20,
                          width: 1,
                          color: Colors.grey.withAlpha(80)),
                    ],
                  ),
                ),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 0, minHeight: 0),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withAlpha(12)
                    : Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      BorderSide(color: primaryColor.withAlpha(80)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      BorderSide(color: primaryColor.withAlpha(60)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.info_outline,
                    size: 13, color: Colors.grey[500]),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'A payment prompt will be sent to your phone.',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey[500]),
                  ),
                ),
              ],
            ),
          ],
        ),
        actionsPadding:
            const EdgeInsets.fromLTRB(24, 0, 24, 24),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(
                    color: isDark
                        ? Colors.white60
                        : Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              final phone = phoneCtrl.text.trim();
              if (phone.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content:
                          Text('Please enter your phone number')),
                );
                return;
              }
              Navigator.pop(ctx);
              _processPayment(provider: provider, phone: phone, medium: medium);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor:
                  isMTN ? Colors.black87 : Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
            ),
            child: const Text('Confirm & Pay',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Payment logic ─────────────────────────────────────────────────────────

  Future<void> _processPayment({
    required String provider,
    required String phone,
    required String medium,
  }) async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Sending payment request...';
    });

    try {
      final userId = authService.userId;
      if (userId == null) throw Exception('Not signed in. Please sign in again.');

      final externalId =
          'home237_premium_${userId}_${DateTime.now().millisecondsSinceEpoch}';

      // ── 1. Initiate Direct Pay via Fapshi ───────────────────────
      final transId = await _fapshi.directPay(
        amount: 5000,
        phone: phone,
        medium: medium,
        message: 'Home237 Premium Subscription – 1 Month',
        userId: userId,
        externalId: externalId,
      );

      if (transId == null) {
        throw Exception('Failed to initiate payment. Please try again.');
      }

      setState(() =>
          _loadingMessage = 'Waiting for your approval on your phone…');

      // ── 2. Poll for payment status (max 2 min) ───────────────────
      const maxAttempts = 40; // 40 × 3s = 2 min
      int attempts = 0;
      bool done = false;

      while (!done && attempts < maxAttempts) {
        await Future.delayed(const Duration(seconds: 3));
        attempts++;

        final status = await _fapshi.getPaymentStatus(transId);

        switch (status) {
          case FapshiStatus.successful:
            done = true;
            break;
          case FapshiStatus.failed:
            throw Exception(
                'Payment failed or was rejected. Please try again.');
          case FapshiStatus.expired:
            throw Exception(
                'Payment request expired. Please try again.');
          case FapshiStatus.created:
          case FapshiStatus.pending:
            // Show countdown to user
            final remaining = maxAttempts - attempts;
            setState(() => _loadingMessage =
                'Waiting for approval… (~${remaining * 3}s left)');
            break;
        }
      }

      if (!done) {
        throw Exception(
            'Payment timed out. If you were charged, please contact support.');
      }

      // ── 3. Update Firestore on success ───────────────────────────
      final expiry = DateTime.now().add(const Duration(days: 30));
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'subscriptionStatus': 'premium',
        'subscriptionExpiry': expiry,
        'lastPaymentTransId': transId,
        'lastPaymentProvider': provider,
      });

      // Update local session
      authService.restoreSession(
        userId: authService.userId!,
        userEmail: authService.userEmail!,
        userName: authService.userName!,
        userRole: authService.userRole,
        profileImage: authService.profileImage,
        subscriptionStatus: 'premium',
        subscriptionExpiry: expiry,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        _showSuccessDialog(provider);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorDialog(e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  // ── Success dialog ────────────────────────────────────────────────────────

  void _showSuccessDialog(String provider) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  color: Colors.white, size: 48),
            ),
            const SizedBox(height: 20),
            const Text(
              'Payment Successful!',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Paid via $provider. You are now a '
              'Premium Landlord for 30 days!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], height: 1.5),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified, color: Color(0xFF10B981), size: 18),
                  SizedBox(width: 6),
                  Text('Premium Badge Active',
                      style: TextStyle(
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Go to Dashboard',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Error dialog ──────────────────────────────────────────────────────────

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline,
                  color: Color(0xFFEF4444), size: 36),
            ),
            const SizedBox(height: 16),
            const Text('Payment Failed',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Try Again')),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAlreadyPremium =
        authService.subscriptionStatus == 'premium';

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Upgrade to Premium',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose your plan',
                  style: TextStyle(
                      fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Unlock unlimited property listings and boost your visibility.',
                  style: TextStyle(
                      color: isDark
                          ? Colors.white60
                          : Colors.grey[600],
                      height: 1.5),
                ),
                const SizedBox(height: 28),

                // Free plan card
                _buildPlanCard(
                  title: 'Free',
                  price: '0 FCFA',
                  period: 'forever',
                  features: const [
                    'Post up to 1 property',
                    'Standard search visibility',
                    'Basic support',
                  ],
                  isPremium: false,
                  isCurrent: !isAlreadyPremium,
                  isDark: isDark,
                ),

                const SizedBox(height: 20),

                // Premium plan card
                _buildPlanCard(
                  title: 'Premium',
                  price: '5,000 FCFA',
                  period: '/month',
                  features: const [
                    'Unlimited property listings',
                    'Featured "Premium" badge',
                    'Priority in search results',
                    'Priority customer support',
                    'Advanced analytics dashboard',
                  ],
                  isPremium: true,
                  isCurrent: isAlreadyPremium,
                  isDark: isDark,
                ),
              ],
            ),
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black.withAlpha(140),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1F2937)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                          color: Color(0xFF3B82F6)),
                      const SizedBox(height: 20),
                      Text(
                        _loadingMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white
                              : Colors.black87,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Plan card builder ─────────────────────────────────────────────────────

  Widget _buildPlanCard({
    required String title,
    required String price,
    required String period,
    required List<String> features,
    required bool isPremium,
    required bool isCurrent,
    required bool isDark,
  }) {
    final cardColor =
        isDark ? const Color(0xFF1F2937) : Colors.white;
    final borderColor = isPremium
        ? const Color(0xFF3B82F6)
        : (isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB));

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: borderColor, width: isPremium ? 2 : 1),
        boxShadow: isPremium
            ? [
                BoxShadow(
                    color: const Color(0xFF3B82F6).withAlpha(25),
                    blurRadius: 24,
                    offset: const Offset(0, 8))
              ]
            : [
                BoxShadow(
                    color: Colors.black.withAlpha(12),
                    blurRadius: 16,
                    offset: const Offset(0, 4))
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: badge + current indicator
          Row(
            children: [
              if (isPremium)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'RECOMMENDED',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5),
                  ),
                ),
              const Spacer(),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withAlpha(15)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Current Plan',
                    style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? Colors.white60
                            : Colors.grey[600]),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          Text(title,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold)),

          const SizedBox(height: 4),

          // Price
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(price,
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: isPremium
                          ? const Color(0xFF3B82F6)
                          : null)),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(period,
                    style: TextStyle(
                        color: isDark
                            ? Colors.white54
                            : Colors.grey[500],
                        fontSize: 14)),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Divider(
              color: isDark ? Colors.white12 : Colors.grey[200]),

          const SizedBox(height: 20),

          // Feature list
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: isPremium
                          ? const Color(0xFF10B981)
                          : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(f,
                            style: TextStyle(
                                color: isDark
                                    ? Colors.white70
                                    : Colors.black87))),
                  ],
                ),
              )),

          const SizedBox(height: 24),

          // CTA
          if (isPremium && !isCurrent) ...[
            Text(
              'Pay with Mobile Money:',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.grey[700]),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                    child: _buildProviderButton(
                        'MTN', const Color(0xFFFFCC00), isDark)),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildProviderButton(
                        'Orange', const Color(0xFFFF7900), isDark)),
              ],
            ),
          ] else if (isPremium && isCurrent)
            _buildCurrentPlanBanner(isDark)
          else
            ElevatedButton(
              onPressed: null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark
                    ? Colors.white12
                    : Colors.grey[200],
                foregroundColor: Colors.grey,
                minimumSize: const Size(double.infinity, 52),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Current Plan',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  // ── Provider payment button ───────────────────────────────────────────────

  Widget _buildProviderButton(
      String provider, Color color, bool isDark) {
    final isMTN = provider == 'MTN';
    return InkWell(
      onTap: () => _showPhoneDialog(provider),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withAlpha(isDark ? 20 : 15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(80), width: 1.5),
        ),
        child: Column(
          children: [
            // Colored icon badge
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Image.asset(
                  isMTN
                      ? 'assets/images/mtn_logo.png'
                      : 'assets/images/orange_logo.png',
                  height: 36,
                  width: 36,
                  fit: BoxFit.contain,
                  errorBuilder: (e, s, t) => Text(
                    isMTN ? 'MTN' : 'OM',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isMTN ? Colors.black87 : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isMTN ? 'MTN MoMo' : 'Orange Money',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text('Tap to pay',
                style: TextStyle(
                    fontSize: 10,
                    color:
                        isDark ? Colors.white38 : Colors.grey[400])),
          ],
        ),
      ),
    );
  }

  // ── Premium active banner ─────────────────────────────────────────────────

  Widget _buildCurrentPlanBanner(bool isDark) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_rounded,
              color: Colors.white, size: 22),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('You are Premium!',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
              Text('Enjoy all premium benefits',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
