import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';
import 'chat_screen.dart';
import 'tour_pass_display_screen.dart';
import 'tour_pass_scanner_screen.dart';
import 'services/fapshi_service.dart';

class TourRequestsScreen extends StatefulWidget {
  const TourRequestsScreen({super.key});

  @override
  State<TourRequestsScreen> createState() => _TourRequestsScreenState();
}

class _TourRequestsScreenState extends State<TourRequestsScreen> {
  String _selectedFilter = 'All';
  String _searchQuery = '';
  final List<String> _filters = ['All', 'Pending', 'Approved', 'Declined'];
  final TextEditingController _searchController = TextEditingController();
  bool _isProcessingRefund = false;

  Future<void> _requestEscrowRefund(String requestId, Map<String, dynamic> request) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('Request Refund', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'The agent didn\'t show up? Request your refund.\n\n'
          'Your full 10,000 FCFA visit fee will be returned to your Mobile Money instantly.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange, 
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Request Refund', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessingRefund = true);

    try {
      String? tenantPhone = request['tenantPhone'] as String?;
      final tenantId = request['tenantId'] as String?;

      if (tenantPhone == null || tenantPhone.isEmpty) {
        if (tenantId != null) {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(tenantId).get();
          if (userDoc.exists) {
            tenantPhone = userDoc.data()?['phone'] as String?;
          }
        }
      }

      if (tenantPhone == null || tenantPhone.isEmpty) {
        throw Exception('Could not find your phone number to process the refund. Please update your profile or contact support.');
      }

      final amount = request['amount'] as int? ?? 10000;

      final payoutMedium = tenantPhone.startsWith('67') || tenantPhone.startsWith('65') || tenantPhone.startsWith('68')
          ? FapshiService.mediumMTN
          : FapshiService.mediumOrange;

      final FapshiService fapshiService = FapshiService();
      
      final success = await fapshiService.sendPayout(
        amount: amount,
        phone: tenantPhone,
        medium: payoutMedium,
      );

      if (!success) {
        throw Exception('Automated refund transfer failed. Please try again or contact support.');
      }

      await FirebaseFirestore.instance.collection('tour_requests').doc(requestId).update({
        'status': 'refunded',
        'refundedAt': DateTime.now(),
        'escrowPayoutStatus': 'refunded',
        'escrowPayoutMedium': payoutMedium,
        'escrowPayoutNumber': tenantPhone,
      });

      final landlordId = request['landlordId'] as String?;
      if (landlordId != null) {
        await FirebaseFirestore.instance.collection('notifications').doc(landlordId).collection('items').add({
          'title': 'Tour Request Refunded',
          'message': 'The tenant has cancelled the tour for "${request['propertyTitle']}" and requested a refund.',
          'type': 'tour_request',
          'read': false,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Refund of $amount FCFA has been successfully sent to your phone!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Refund failed: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingRefund = false);
      }
    }
  }

  Future<void> _cancelFreeTourRequest(String requestId, Map<String, dynamic> request) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Cancel Tour Request', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Are you sure you want to cancel this tour request?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red, 
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Yes, Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('tour_requests').doc(requestId).update({
        'status': 'cancelled',
        'cancelledAt': DateTime.now(),
      });

      final landlordId = request['landlordId'] as String?;
      if (landlordId != null) {
        await FirebaseFirestore.instance.collection('notifications').doc(landlordId).collection('items').add({
          'title': 'Tour Request Cancelled',
          'message': 'The tenant has cancelled the tour request for "${request['propertyTitle']}".',
          'type': 'tour_request',
          'read': false,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tour request cancelled successfully.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cancellation failed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _updateRequestStatus(String requestId, String status, String tenantId) async {
    try {
      await FirebaseFirestore.instance
          .collection('tour_requests')
          .doc(requestId)
          .update({'status': status.toLowerCase()});

      // Send notification to tenant
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(tenantId)
          .collection('items')
          .add({
        'title': 'Tour Request $status',
        'message': 'Your tour request has been ${status.toLowerCase()}',
        'type': 'tour_request',
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request $status successfully'),
            backgroundColor: status == 'Approved' ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                children: [
                  Text(
                    'Tour Requests',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search tenant or property...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty 
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  fillColor: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF1F5F9),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // Filters
            SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filters.length,
                itemBuilder: (context, index) {
                  final filter = _filters[index];
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedFilter = filter);
                      },
                      selectedColor: const Color(0xFF1E3A5F),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey[700]),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      backgroundColor: isDark ? const Color(0xFF374151) : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? Colors.transparent : (isDark ? Colors.white12 : Colors.grey[300]!),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 8),

            // Requests List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('tour_requests')
                    .where(authService.userRole == UserRole.tenant ? 'tenantId' : 'landlordId', isEqualTo: authService.userId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // Convert docs to a sortable list and sort client-side to avoid index requirement
                  var requests = snapshot.data!.docs.toList();
                  
                  requests.sort((a, b) {
                    final aTime = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                    final bTime = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                    if (aTime == null && bTime == null) return 0;
                    if (aTime == null) return 1;
                    if (bTime == null) return -1;
                    return bTime.compareTo(aTime);
                  });

                  // Client-side filtering
                  if (_selectedFilter != 'All') {
                    requests = requests.where((doc) {
                      final status = (doc.data() as Map<String, dynamic>)['status'] ?? 'pending';
                      return status.toString().toLowerCase() == _selectedFilter.toLowerCase();
                    }).toList();
                  }

                  if (_searchQuery.isNotEmpty) {
                    requests = requests.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final tenant = (data['tenantName'] ?? '').toString().toLowerCase();
                      final property = (data['propertyTitle'] ?? '').toString().toLowerCase();
                      return tenant.contains(_searchQuery) || property.contains(_searchQuery);
                    }).toList();
                  }

                  if (requests.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _searchQuery.isNotEmpty ? Icons.search_off : Icons.event_busy,
                            size: 80,
                            color: isDark ? Colors.grey[600] : Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty ? 'No matches found' : 'No tour requests',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final doc = requests[index];
                      final request = doc.data() as Map<String, dynamic>;
                      final status = request['status'] ?? 'pending';
                      final timestamp = request['createdAt'] as Timestamp?;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header
                              Row(
                                children: [
                                  Container(
                                    width: 54,
                                    height: 54,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E3A5F).withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.person_outline,
                                      color: Color(0xFF1E3A5F),
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          request['tenantName'] ?? 'Tenant',
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.home_work_outlined, size: 14, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                request['propertyTitle'] ?? 'Property',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  _buildStatusBadge(status),
                                ],
                              ),

                              if (request['message'] != null && request['message'].toString().isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF374151)
                                        : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'TENANT MESSAGE',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[500],
                                          letterSpacing: 1,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        request['message'],
                                        style: TextStyle(
                                          fontSize: 14,
                                          height: 1.4,
                                          color: isDark ? Colors.grey[300] : Colors.grey[800],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 16),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  if (timestamp != null)
                                    Row(
                                      children: [
                                        Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatTimestamp(timestamp),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  const Spacer(),
                                ],
                              ),

                                if (status == 'pending' && authService.userRole != UserRole.tenant) ...[
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () => _updateRequestStatus(
                                            doc.id,
                                            'Declined',
                                            request['tenantId'],
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.red,
                                            side: const BorderSide(color: Colors.red),
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                          child: const Text('Decline', style: TextStyle(fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () => _updateRequestStatus(
                                            doc.id,
                                            'Approved',
                                            request['tenantId'],
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF10B981),
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                          child: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ] else ...[
                                  const SizedBox(height: 16),
                                  
                                  // ESCROW QR BUTTONS
                                   if (authService.userRole == UserRole.tenant)
                                     Column(
                                       children: [
                                         if (status == 'escrowed' || status == 'approved') ...[
                                           SizedBox(
                                             width: double.infinity,
                                             child: ElevatedButton.icon(
                                               onPressed: () {
                                                 Navigator.push(
                                                   context,
                                                   MaterialPageRoute(
                                                     builder: (context) => TourPassDisplayScreen(
                                                       tourRequestId: doc.id,
                                                       escrowCode: request['escrowCode'] ?? '',
                                                       propertyTitle: request['propertyTitle'] ?? 'Property Tour',
                                                     ),
                                                   ),
                                                 );
                                               },
                                               icon: const Icon(Icons.qr_code, size: 18),
                                               label: const Text('Show Tour Pass (QR)', style: TextStyle(fontWeight: FontWeight.bold)),
                                               style: ElevatedButton.styleFrom(
                                                 backgroundColor: const Color(0xFF10B981),
                                                 foregroundColor: Colors.white,
                                                 elevation: 0,
                                                 padding: const EdgeInsets.symmetric(vertical: 12),
                                                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                               ),
                                             ),
                                           ),
                                           const SizedBox(height: 8),
                                         ],
                                         if (status == 'escrowed') ...[
                                           SizedBox(
                                             width: double.infinity,
                                             child: OutlinedButton.icon(
                                               onPressed: () => _requestEscrowRefund(doc.id, request),
                                               icon: const Icon(Icons.undo_rounded, size: 18),
                                               label: const Text("Agent didn't show — Refund", style: TextStyle(fontWeight: FontWeight.bold)),
                                               style: OutlinedButton.styleFrom(
                                                 foregroundColor: Colors.orange,
                                                 side: const BorderSide(color: Colors.orange),
                                                 padding: const EdgeInsets.symmetric(vertical: 12),
                                                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                               ),
                                             ),
                                           ),
                                           const SizedBox(height: 8),
                                         ] else if (status == 'pending' || status == 'approved') ...[
                                           SizedBox(
                                             width: double.infinity,
                                             child: OutlinedButton.icon(
                                               onPressed: () => _cancelFreeTourRequest(doc.id, request),
                                               icon: const Icon(Icons.cancel_outlined, size: 18),
                                               label: const Text('Cancel Tour Request', style: TextStyle(fontWeight: FontWeight.bold)),
                                               style: OutlinedButton.styleFrom(
                                                 foregroundColor: Colors.red,
                                                 side: const BorderSide(color: Colors.red),
                                                 padding: const EdgeInsets.symmetric(vertical: 12),
                                                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                               ),
                                             ),
                                           ),
                                           const SizedBox(height: 8),
                                         ],
                                       ],
                                     )
                                  else if ((status == 'escrowed' || status == 'approved') && authService.userRole != UserRole.tenant)
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => const TourPassScannerScreen(),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.qr_code_scanner, size: 18),
                                        label: const Text('Scan Tenant Pass', style: TextStyle(fontWeight: FontWeight.bold)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF10B981),
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                    ),
                                  
                                  const SizedBox(height: 8),

                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ChatScreen(
                                              recipientId: authService.userRole == UserRole.tenant ? request['landlordId'] : request['tenantId'],
                                              recipientName: authService.userRole == UserRole.tenant ? 'Agent' : request['tenantName'] ?? 'Tenant',
                                              propertyTitle: request['propertyTitle'],
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                                      label: Text(authService.userRole == UserRole.tenant ? 'Message Agent' : 'Message Tenant', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF1E3A5F),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                ],
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      if (_isProcessingRefund)
        Container(
          color: Colors.black.withOpacity(0.6),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF1E3A5F)),
                SizedBox(height: 16),
                Text(
                  'Processing your Refund...',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'completed':
        color = const Color(0xFF10B981);
        break;
      case 'approved':
        color = const Color(0xFF10B981);
        break;
      case 'declined':
        color = Colors.red;
        break;
      case 'refunded':
        color = Colors.grey;
        break;
      case 'escrowed':
        color = const Color(0xFF1E3A5F); // Blue for active escrow holding
        break;
      default:
        color = const Color(0xFFF59E0B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
