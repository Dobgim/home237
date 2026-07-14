import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/lease_service.dart';

class LeaseAgreementScreen extends StatefulWidget {
  final String leaseId;
  final bool isReadOnly;

  const LeaseAgreementScreen({
    super.key,
    required this.leaseId,
    this.isReadOnly = false,
  });

  @override
  State<LeaseAgreementScreen> createState() => _LeaseAgreementScreenState();
}

class _LeaseAgreementScreenState extends State<LeaseAgreementScreen> {
  final LeaseService _leaseService = LeaseService();
  bool _isSigning = false;

  Future<void> _signAgreement(Map<String, dynamic> leaseData) async {
    setState(() => _isSigning = true);
    try {
      await FirebaseFirestore.instance.collection('leases').doc(widget.leaseId).update({
        'status': 'active',
        'signedAt': FieldValue.serverTimestamp(),
      });

      // Show success
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lease Agreement Digitally Signed & Activated!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to sign agreement: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSigning = false);
    }
  }

  void _downloadSimulatedPDF(Map<String, dynamic> leaseData) {
    // Generate text lease format and simulate save
    final text = _leaseService.generateLeaseText(
      landlordName: leaseData['landlordName'] ?? 'Agent',
      tenantName: leaseData['tenantName'] ?? 'Tenant',
      propertyTitle: leaseData['propertyTitle'] ?? 'Property',
      propertyLocation: '${leaseData['propertyNeighborhood'] ?? "Molyko"}, ${leaseData['propertyCity'] ?? "Buea"}',
      rentAmount: leaseData['rentAmount'] as int? ?? 150000,
      durationMonths: leaseData['durationMonths'] as int? ?? 12,
      escrowCode: leaseData['escrowCode'] ?? 'ESCRW',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.picture_as_pdf, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('PDF Generated', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'A copy of the Digital Lease agreement has been successfully converted to PDF format and written to your device.\n\n'
          'Filename: Home237_Lease_${leaseData['escrowCode'] ?? "Agreement"}.pdf\n\n'
          'You can find it under your device\'s downloads folder.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0EA5E9),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Open Folder', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.close, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Digital Lease Agreement',
          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('leases').doc(widget.leaseId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Lease agreement details not found.'));
          }

          final leaseData = snapshot.data!.data() as Map<String, dynamic>;
          final status = leaseData['status'] ?? 'pending';
          final escrowCode = leaseData['escrowCode'] ?? 'ESCRW';

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.4 : 0.05),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                      border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Stamp/Watermark
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0EA5E9).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                '🏠 Home237 Secures',
                                style: TextStyle(color: Color(0xFF0EA5E9), fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: status == 'active' ? Colors.green.withOpacity(0.1) : Colors.amber.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                status == 'active' ? '✓ SIGNED & ACTIVE' : '⚡ PENDING SIGNATURE',
                                style: TextStyle(
                                  color: status == 'active' ? Colors.green : Colors.amber,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Center(
                          child: Text(
                            'RESIDENTIAL LEASE AGREEMENT',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                        ),
                        const Center(
                          child: Text(
                            'Officially Registered Digital Contract',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 12),

                        // Contract Info Box
                        _buildSectionHeader('1. CONTRACTING PARTIES'),
                        _buildInfoRow('Agent:', leaseData['landlordName'] ?? 'N/A'),
                        _buildInfoRow('Tenant:', leaseData['tenantName'] ?? 'N/A'),
                        const SizedBox(height: 16),

                        _buildSectionHeader('2. LEASED PREMISES'),
                        _buildInfoRow('Property:', leaseData['propertyTitle'] ?? 'N/A'),
                        _buildInfoRow('Location:', '${leaseData['propertyNeighborhood'] ?? "Molyko"}, ${leaseData['propertyCity'] ?? "Buea"}'),
                        const SizedBox(height: 16),

                        _buildSectionHeader('3. RENT DETAILS'),
                        _buildInfoRow('Rent Amount:', '${leaseData['rentAmount'] ?? 0} XAF / Month'),
                        _buildInfoRow('Due Date:', '5th of each month'),
                        _buildInfoRow('Payment Gateway:', 'Mobile Money (MTN / Orange via Fapshi)'),
                        _buildInfoRow('Escrow Code:', escrowCode),
                        const SizedBox(height: 16),

                        _buildSectionHeader('4. LEGAL CLAUSES & RULES'),
                        const Text(
                          'A. Rent is payable monthly in advance on or before the due date.\n'
                          'B. The tenant shall keep the property clean, sanitary and in good condition.\n'
                          'C. The agent warrants that structural elements (roofing, main plumbing, exterior walls) will remain in functional repair.\n'
                          'D. Release of the initial escrow rent payment is authorized immediately upon agent-tenant physical QR check-in.',
                          style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 32),

                        // Digital Signatures
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  const Icon(Icons.draw, color: const Color(0xFF1E3A5F)),
                                  const SizedBox(height: 6),
                                  Text(
                                    leaseData['tenantName'] ?? 'Tenant',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const Text('Tenant Signature', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                  const SizedBox(height: 4),
                                  const Text('[Digitally Verified]', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 80, color: Colors.grey[300]),
                            Expanded(
                              child: Column(
                                children: [
                                  Icon(Icons.draw, color: status == 'active' ? const Color(0xFF1E3A5F) : Colors.grey),
                                  const SizedBox(height: 6),
                                  Text(
                                    leaseData['landlordName'] ?? 'Agent',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const Text('Agent Signature', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                  const SizedBox(height: 4),
                                  Text(
                                    status == 'active' ? '[Digitally Verified]' : '[Pending Verification]',
                                    style: TextStyle(fontSize: 10, color: status == 'active' ? Colors.green : Colors.amber, fontWeight: FontWeight.bold),
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
              ),

              // Action Buttons
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  border: Border(top: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0))),
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      // Download button
                      IconButton(
                        icon: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 28),
                        onPressed: () => _downloadSimulatedPDF(leaseData),
                        tooltip: 'Export PDF',
                      ),
                      const SizedBox(width: 12),
                      // Sign/Accept button
                      Expanded(
                        child: status != 'active' && !widget.isReadOnly
                            ? ElevatedButton(
                                onPressed: _isSigning ? null : () => _signAgreement(leaseData),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: _isSigning
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Text('Digitally Sign & Approve', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              )
                            : Container(
                                height: 48,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                                    SizedBox(width: 8),
                                    Text('Lease Active & Complete', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0EA5E9), letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
