import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';
import 'services/rent_payment_service.dart';
import 'lease_agreement_screen.dart';

class RentTrackerScreen extends StatefulWidget {
  const RentTrackerScreen({super.key});

  @override
  State<RentTrackerScreen> createState() => _RentTrackerScreenState();
}

class _RentTrackerScreenState extends State<RentTrackerScreen> {
  final RentPaymentService _rentPaymentService = RentPaymentService();
  bool _isPaying = false;
  final String _selectedTab = 'Active';

  Future<void> _processRentPayment({
    required String leaseId,
    required int amount,
    required String propertyTitle,
  }) async {
    final TextEditingController phoneController = TextEditingController();
    final String? phoneNumber = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.payment, color: Color(0xFF0EA5E9)),
            SizedBox(width: 8),
            Text('Mobile Money Payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pay $amount XAF to escrow wallet for "$propertyTitle".'),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'MoMo Number (e.g. 67XXXXXXX)',
                border: OutlineInputBorder(),
                prefixText: '+237 ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, phoneController.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9), foregroundColor: Colors.white),
            child: const Text('Confirm Pay'),
          ),
        ],
      ),
    );

    if (phoneNumber == null || phoneNumber.isEmpty) return;

    setState(() => _isPaying = true);

    try {
      final transId = await _rentPaymentService.payMonthlyRent(
        leaseId: leaseId,
        tenantId: authService.userId ?? '',
        tenantName: authService.userName ?? 'Tenant',
        amount: amount,
        phone: '237$phoneNumber',
        propertyTitle: propertyTitle,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment prompt initiated. Check your phone for verification!'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // Check payment status (simulating a polling mechanism)
      if (transId != null) {
        Future.delayed(const Duration(seconds: 15), () async {
          final res = await _rentPaymentService.checkAndRecordPaymentStatus(transId, leaseId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(res == 'paid' ? 'Rent Payment Confirmed!' : 'Payment Pending Check.'),
                backgroundColor: res == 'paid' ? Colors.green : Colors.orange,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTenant = authService.userRole == UserRole.tenant;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          'Rent Tracker',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Dashboard overview card
              _buildOverviewCard(isTenant, isDark),

              // Leases Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isTenant ? 'My Rent Contracts' : 'Active Tenancies',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Icon(Icons.receipt_long, size: 18, color: Color(0xFF64748B)),
                  ],
                ),
              ),

              // Leases List
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('leases')
                      .where(isTenant ? 'tenantId' : 'landlordId', isEqualTo: authService.userId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.house_outlined, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text(
                              isTenant ? 'You have no active leases.' : 'No properties rented out yet.',
                              style: const TextStyle(color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      itemCount: snapshot.data!.docs.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final leaseDoc = snapshot.data!.docs[index];
                        final lease = leaseDoc.data() as Map<String, dynamic>;
                        return _buildLeaseCard(lease, leaseDoc.id, isTenant, isDark);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          if (_isPaying)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF0EA5E9)),
                    SizedBox(height: 16),
                    Text('Connecting MoMo Payer Wallet...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(bool isTenant, bool isDark) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0EA5E9), Color(0xFF1E3A5F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A5F).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: isTenant
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('TENANT ESCROW WALLET', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    const Icon(Icons.security, color: Colors.white24, size: 20),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Rent Secured in Escrow',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
                const SizedBox(height: 4),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('leases')
                      .where('tenantId', isEqualTo: authService.userId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    int totalEscrow = 0;
                    if (snapshot.hasData) {
                      for (var doc in snapshot.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        if (data['status'] == 'pending') {
                          totalEscrow += (data['rentAmount'] as num).toInt();
                        }
                      }
                    }
                    return Text(
                      '$totalEscrow XAF',
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                    );
                  },
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('LANDLORD PORTFOLIO SUMMARY', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    const Icon(Icons.analytics_outlined, color: Colors.white24, size: 20),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Monthly Income', style: TextStyle(color: Colors.white, fontSize: 13)),
                        const SizedBox(height: 4),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('leases')
                              .where('landlordId', isEqualTo: authService.userId)
                              .snapshots(),
                          builder: (context, snapshot) {
                            int total = 0;
                            if (snapshot.hasData) {
                              for (var doc in snapshot.data!.docs) {
                                final data = doc.data() as Map<String, dynamic>;
                                if (data['status'] == 'active') {
                                  total += (data['rentAmount'] as num).toInt();
                                }
                              }
                            }
                            return Text('$total XAF', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold));
                          },
                        ),
                      ],
                    ),
                    Container(width: 1, height: 40, color: Colors.white30),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Leases Managed', style: TextStyle(color: Colors.white, fontSize: 13)),
                        const SizedBox(height: 4),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('leases')
                              .where('landlordId', isEqualTo: authService.userId)
                              .snapshots(),
                          builder: (context, snapshot) {
                            final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                            return Text('$count Active', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold));
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildLeaseCard(Map<String, dynamic> lease, String leaseId, bool isTenant, bool isDark) {
    final status = lease['status'] ?? 'pending';
    final rent = lease['rentAmount'] as int? ?? 0;
    final title = lease['propertyTitle'] ?? 'Rental Property';
    final landlordName = lease['landlordName'] ?? 'Agent';
    final tenantName = lease['tenantName'] ?? 'Tenant';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: status == 'active' ? Colors.green.withOpacity(0.1) : Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status.toString().toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: status == 'active' ? Colors.green : Colors.amber,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isTenant ? 'Agent' : 'Tenant', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  Text(isTenant ? landlordName : tenantName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Monthly Rent', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  Text('$rent XAF', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0EA5E9))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LeaseAgreementScreen(leaseId: leaseId, isReadOnly: true),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('View Contract', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              if (isTenant && status == 'active') ...[
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _processRentPayment(
                      leaseId: leaseId,
                      amount: rent,
                      propertyTitle: title,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0EA5E9),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Pay Monthly Rent', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
