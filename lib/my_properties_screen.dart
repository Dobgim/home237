import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';
import 'add_property_screen.dart';
import 'property_details_screen.dart';
import 'services/fapshi_service.dart';

class MyPropertiesScreen extends StatefulWidget {
  const MyPropertiesScreen({super.key});

  @override
  State<MyPropertiesScreen> createState() => _MyPropertiesScreenState();
}

class _MyPropertiesScreenState extends State<MyPropertiesScreen> {
  String _searchQuery = '';
  String _selectedStatus = 'All';
  final TextEditingController _searchController = TextEditingController();

  Future<void> _deleteProperty(BuildContext context, String propertyId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Property'),
        content: const Text('Are you sure you want to delete this property? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('properties')
            .doc(propertyId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Property deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting property: $e')),
          );
        }
      }
    }
  }

  Future<void> _togglePropertyStatus(String propertyId, String currentStatus) async {
    final isActive = currentStatus == 'active' || currentStatus == 'approved';
    final newStatus = isActive ? 'inactive' : 'approved';
    try {
      await FirebaseFirestore.instance
          .collection('properties')
          .doc(propertyId)
          .update({'status': newStatus});
    } catch (e) {
      print('Error toggling status: $e');
    }
  }

  final FapshiService _fapshi = FapshiService();

  Future<void> _boostProperty(BuildContext context, String propertyId) async {
    _showPaymentOptions(context, type: 'boost', amount: 2000, propertyId: propertyId);
  }

  Future<void> _fastTrackProperty(BuildContext context, String propertyId) async {
    _showPaymentOptions(context, type: 'fast_track', amount: 1000, propertyId: propertyId);
  }

  void _showPaymentOptions(BuildContext context, {required String type, required int amount, required String propertyId}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2937) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              type == 'boost' ? 'Boost Your Listing' : 'Fast-Track Your Listing',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              type == 'boost'
                  ? 'Feature your property at the top of results for 7 days.'
                  : 'Highlight your listing in green and alert tenants for 7 days.',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                '$amount FCFA',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF3B82F6)),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Pay with Mobile Money:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showPhoneDialog(context, provider: 'MTN', type: type, amount: amount, propertyId: propertyId);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFCC00),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('MTN MoMo', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showPhoneDialog(context, provider: 'Orange', type: type, amount: amount, propertyId: propertyId);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7900),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Orange Money', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showPhoneDialog(BuildContext context, {
    required String provider,
    required String type,
    required int amount,
    required String propertyId,
  }) {
    final TextEditingController phoneCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMTN = provider == 'MTN';
    final primaryColor = isMTN ? const Color(0xFFFFCC00) : const Color(0xFFFF7900);
    final medium = isMTN ? FapshiService.mediumMTN : FapshiService.mediumOrange;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E2937) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Pay with ${isMTN ? 'MTN MoMo' : 'Orange Money'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Amount: $amount FCFA',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              autofocus: true,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: '6XX XXX XXX',
                hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey[400]),
                prefixText: '+237 ',
                prefixStyle: const TextStyle(fontWeight: FontWeight.bold),
                filled: true,
                fillColor: isDark ? Colors.white.withAlpha(12) : Colors.grey[50],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final phone = phoneCtrl.text.trim();
              if (phone.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter your phone number')),
                );
                return;
              }
              Navigator.pop(ctx);
              _processPayment(context, provider: provider, phone: phone, medium: medium, type: type, amount: amount, propertyId: propertyId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: isMTN ? Colors.black : Colors.white),
            child: const Text('Confirm & Pay'),
          ),
        ],
      ),
    );
  }

  Future<void> _processPayment(BuildContext context, {
    required String provider,
    required String phone,
    required String medium,
    required String type,
    required int amount,
    required String propertyId,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text('Processing payment request. Please check your phone for prompt.')),
          ],
        ),
      ),
    );

    try {
      final userId = authService.userId;
      if (userId == null) throw Exception('Not signed in.');

      final externalId = 'home237_${type}_${propertyId}_${DateTime.now().millisecondsSinceEpoch}';

      final transId = await _fapshi.directPay(
        amount: amount,
        phone: phone,
        medium: medium,
        message: type == 'boost' ? 'Home237 Listing Boost' : 'Home237 Listing Fast-Track',
        userId: userId,
        externalId: externalId,
      );

      if (transId == null) {
        throw Exception('Failed to initiate payment.');
      }

      const maxAttempts = 40;
      int attempts = 0;
      bool done = false;

      while (!done && attempts < maxAttempts) {
        await Future.delayed(const Duration(seconds: 3));
        attempts++;

        final status = await _fapshi.getPaymentStatus(transId);
        if (status == FapshiStatus.successful) {
          done = true;
          break;
        } else if (status == FapshiStatus.failed || status == FapshiStatus.expired) {
          throw Exception('Payment failed or expired.');
        }
      }

      if (!done) {
        throw Exception('Payment timed out.');
      }

      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
      }

      final duration = const Duration(days: 7);
      final until = DateTime.now().add(duration);

      if (type == 'boost') {
        await FirebaseFirestore.instance.collection('properties').doc(propertyId).update({
          'isBoosted': true,
          'boostedUntil': until,
        });
      } else {
        await FirebaseFirestore.instance.collection('properties').doc(propertyId).update({
          'isFastTracked': true,
          'fastTrackedUntil': until,
        });
      }

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Payment Successful!'),
            content: Text(type == 'boost' ? 'Your property has been successfully boosted!' : 'Your property has been successfully fast-tracked!'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Payment Failed'),
            content: Text(e.toString().replaceAll('Exception: ', '')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = authService.userId;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'My Properties',
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
                  hintText: 'Search by title or location...',
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

            // Status Filter Chips
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: ['All', 'Active', 'Pending', 'Inactive', 'Rented'].map((status) {
                  final isSelected = _selectedStatus == status;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(status),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedStatus = status);
                      },
                      selectedColor: const Color(0xFF3B82F6),
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
                }).toList(),
              ),
            ),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('properties')
                    .where('landlordId', isEqualTo: currentUserId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // Convert docs to a sortable list and sort client-side to avoid index requirement
                  var properties = snapshot.data!.docs.toList();

                  // Sort: Boosted entries first, then by createdAt descending
                  properties.sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;
                    
                    final aBoosted = aData['isBoosted'] == true;
                    final bBoosted = bData['isBoosted'] == true;
                    
                    if (aBoosted && !bBoosted) return -1;
                    if (!aBoosted && bBoosted) return 1;
                    
                    final aTime = aData['createdAt'] as Timestamp?;
                    final bTime = bData['createdAt'] as Timestamp?;
                    
                    if (aTime == null && bTime == null) return 0;
                    if (aTime == null) return 1;
                    if (bTime == null) return -1;
                    return bTime.compareTo(aTime);
                  });

                  // Client-side filtering
                  if (_selectedStatus != 'All') {
                    properties = properties.where((doc) {
                      var status = (doc.data() as Map<String, dynamic>)['status'] ?? 'active';
                      status = status.toString().toLowerCase().trim();
                      if (_selectedStatus == 'Active') {
                        return status == 'active' || status == 'approved';
                      }
                      if (_selectedStatus == 'Rented') {
                        return status == 'rented';
                      }
                      return status == _selectedStatus.toLowerCase();
                    }).toList();
                  }

                  if (_searchQuery.isNotEmpty) {
                    properties = properties.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final title = (data['title'] ?? '').toString().toLowerCase();
                      final location = (data['location'] ?? '').toString().toLowerCase();
                      return title.contains(_searchQuery) || location.contains(_searchQuery);
                    }).toList();
                  }

                  if (properties.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.home_outlined,
                            size: 80,
                            color: isDark ? Colors.grey[600] : Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty ? 'No properties match search' : 'No properties found',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try adjusting your search or filters',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.grey[500] : Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: properties.length,
                        itemBuilder: (context, index) {
                      final doc = properties[index];
                      final property = doc.data() as Map<String, dynamic>;
                      final propertyId = doc.id;
                      final rawStatus = (property['status'] ?? 'active').toString().toLowerCase().trim();
                      final isStatusActive = rawStatus == 'active' || rawStatus == 'approved';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Image and Status
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(20),
                                  ),
                                  child: property['images'] != null && property['images'].isNotEmpty
                                      ? Image.network(
                                          property['images'][0],
                                          height: 180,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            height: 180,
                                            color: Colors.grey[300],
                                            child: const Icon(Icons.image, size: 60),
                                          ),
                                        )
                                      : Image.asset(
                                          'assets/images/logo.jpg',
                                          height: 180,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                        ),
                                ),
                                  Positioned(
                                    top: 12,
                                    left: 12,
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isStatusActive
                                                ? const Color(0xFF10B981)
                                                : rawStatus == 'pending'
                                                ? const Color(0xFFF59E0B)
                                                : rawStatus == 'rented'
                                                ? const Color(0xFFEF4444)
                                                : Colors.grey,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            isStatusActive ? 'ACTIVE' : rawStatus.toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                         if (property['isBoosted'] == true) ...[
                                           const SizedBox(width: 8),
                                           Container(
                                             padding: const EdgeInsets.symmetric(
                                               horizontal: 12,
                                               vertical: 6,
                                             ),
                                             decoration: BoxDecoration(
                                               color: Colors.amber,
                                               borderRadius: BorderRadius.circular(12),
                                             ),
                                             child: const Row(
                                               mainAxisSize: MainAxisSize.min,
                                               children: [
                                                 Icon(Icons.bolt, color: Colors.black, size: 14),
                                                 SizedBox(width: 4),
                                                 Text(
                                                   'FEATURED',
                                                   style: TextStyle(
                                                     color: Colors.black,
                                                     fontSize: 10,
                                                     fontWeight: FontWeight.bold,
                                                   ),
                                                 ),
                                               ],
                                             ),
                                           ),
                                         ],
                                         if (property['isFastTracked'] == true) ...[
                                           const SizedBox(width: 8),
                                           Container(
                                             padding: const EdgeInsets.symmetric(
                                               horizontal: 12,
                                               vertical: 6,
                                             ),
                                             decoration: BoxDecoration(
                                               color: const Color(0xFF10B981),
                                               borderRadius: BorderRadius.circular(12),
                                             ),
                                             child: const Row(
                                               mainAxisSize: MainAxisSize.min,
                                               children: [
                                                 Icon(Icons.flash_on, color: Colors.white, size: 14),
                                                 SizedBox(width: 4),
                                                 Text(
                                                   'FAST-TRACK',
                                                   style: TextStyle(
                                                     color: Colors.white,
                                                     fontSize: 10,
                                                     fontWeight: FontWeight.bold,
                                                   ),
                                                 ),
                                               ],
                                             ),
                                           ),
                                         ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                            // Property Info
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          property['title'] ?? 'Property',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                                          ),
                                        ),
                                      ),
                                      Text(
                                        property['price'] ?? '0 FCFA',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF3B82F6),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        size: 16,
                                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          property['location'] ?? '',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      _buildInfoChip(Icons.king_bed_outlined, '${property['beds'] ?? '0'} beds', isDark),
                                      const SizedBox(width: 12),
                                      _buildInfoChip(Icons.bathtub_outlined, '${property['baths'] ?? '0'} baths', isDark),
                                      const Spacer(),
                                      _buildInfoChip(Icons.visibility, '${property['views'] ?? 0} views', isDark),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => PropertyDetailsScreen(
                                                  propertyId: propertyId,
                                                  propertyData: property,
                                                ),
                                              ),
                                            );
                                          },
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: const Color(0xFF3B82F6),
                                            side: const BorderSide(color: Color(0xFF3B82F6)),
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                          child: const Text('View Details', style: TextStyle(fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => AddPropertyScreen(
                                                  propertyId: propertyId,
                                                  propertyData: property,
                                                ),
                                              ),
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF3B82F6),
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                          child: const Text('Edit Listing', style: TextStyle(fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        onPressed: () => _showMoreOptions(context, propertyId, property, rawStatus),
                                        icon: const Icon(Icons.more_vert),
                                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, bool isDark) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.grey[300] : Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void _showMoreOptions(BuildContext context, String propertyId, Map<String, dynamic> property, String status) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    (status == 'active' || status == 'approved') ? Icons.visibility_off : Icons.visibility,
                    color: const Color(0xFF3B82F6),
                    size: 20,
                  ),
                ),
                title: Text(
                  (status == 'active' || status == 'approved') ? 'Mark as Inactive' : 'Mark as Active',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text((status == 'active' || status == 'approved') ? 'Hide this listing from search' : 'Show this listing in search'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _togglePropertyStatus(propertyId, status);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    status == 'rented' ? Icons.check_circle_outline : Icons.house_siding,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                ),
                title: Text(
                  status == 'rented' ? 'Mark as Available' : 'Mark as Rented',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(status == 'rented' ? 'Show this listing as available for rent' : 'Show this listing as occupied/rented'),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  final newStatus = status == 'rented' ? 'approved' : 'rented';
                  try {
                    await FirebaseFirestore.instance
                        .collection('properties')
                        .doc(propertyId)
                        .update({'status': newStatus});
                  } catch (e) {
                    print('Error toggling rented status: $e');
                  }
                },
              ),
              if (property['isBoosted'] != true)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.bolt, color: Colors.amber, size: 20),
                  ),
                  title: const Text('Boost Listing', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Feature this at the top for 2,000 FCFA'),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _boostProperty(context, propertyId);
                  },
                ),
              if (property['isFastTracked'] != true)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.flash_on, color: Colors.green, size: 20),
                  ),
                  title: const Text('Fast-Track Listing', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Highlight listing and alert tenants for 1,000 FCFA'),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _fastTrackProperty(context, propertyId);
                  },
                ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                ),
                title: const Text('Delete Permanently', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                subtitle: const Text('Remove this property and all its data'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _deleteProperty(context, propertyId);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
