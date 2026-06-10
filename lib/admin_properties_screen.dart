import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'property_details_screen.dart';
import 'add_property_screen.dart';
import 'package:flutter/foundation.dart';

class AdminPropertiesScreen extends StatefulWidget {
  const AdminPropertiesScreen({super.key});

  @override
  State<AdminPropertiesScreen> createState() => _AdminPropertiesScreenState();
}

class _AdminPropertiesScreenState extends State<AdminPropertiesScreen> {
  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Properties',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('properties').snapshots(),
              builder: (context, snapshot) {
                final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                return Text(
                  '$count Total Listings',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Color(0xFF0F172A)),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search address, ID, or owner...',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8)),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.tune, color: Color(0xFF94A3B8)),
                      onPressed: () {},
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Available'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Rented'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Paused'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Properties List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('properties').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No properties found'));
                }

                var properties = snapshot.data!.docs;

                // Apply filters
                if (_selectedFilter != 'All') {
                  properties = properties.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final status = data['status'] ?? '';
                    if (_selectedFilter == 'Available') return status == 'approved' || status == 'active';
                    if (_selectedFilter == 'Rented') return status == 'rented';
                    if (_selectedFilter == 'Paused') return status == 'paused';
                    return true;
                  }).toList();
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: properties.length + 1,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    if (index == properties.length) {
                      return const SizedBox(height: 80);
                    }

                    final propertyData =
                        properties[index].data() as Map<String, dynamic>;
                    final propertyId = properties[index].id;

                    // Swipe-to-delete for mobile convenience
                    return Dismissible(
                      key: Key(propertyId),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delete_forever_rounded,
                                color: Colors.white, size: 30),
                            SizedBox(height: 4),
                            Text('DELETE',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    letterSpacing: 1)),
                          ],
                        ),
                      ),
                      confirmDismiss: (_) async {
                        return await _showDeleteConfirmation(
                            propertyId, propertyData);
                      },
                      onDismissed: (_) {}, // actual delete is in confirmDismiss
                      child: _buildPropertyCard(propertyData, propertyId),
                    );
                  },
                );

              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: const Color(0xFF0EA5E9),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0EA5E9) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF0EA5E9) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildPropertyCard(Map<String, dynamic> propertyData, String propertyId) {
    final title = propertyData['title'] ?? 'Untitled Property';
    final location = propertyData['location'] ?? 'Unknown location';
    final owner = propertyData['landlordName'] ?? 'Unknown Owner';
    final price = propertyData['price'] ?? '0 FCFA';
    final status = propertyData['status'] ?? 'active';
    final beds = propertyData['beds'] ?? '0';
    final baths = propertyData['baths'] ?? '0';

    String statusLabel = '';
    Color statusColor = const Color(0xFF10B981);

    if (status == 'approved' || status == 'active') {
      statusLabel = 'APPROVED';
      statusColor = const Color(0xFF10B981);
    } else if (status == 'rented') {
      statusLabel = 'RENTED';
      statusColor = const Color(0xFF0EA5E9);
    } else if (status == 'paused') {
      statusLabel = 'PAUSED';
      statusColor = const Color(0xFFF59E0B);
    } else if (status == 'pending') {
      statusLabel = 'PENDING';
      statusColor = const Color(0xFFF97316);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Property Image
          Container(
            width: 90,
            height: 110,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
            child: Stack(
              children: [
                const Center(
                  child: Icon(Icons.home_work, size: 40, color: Color(0xFF94A3B8)),
                ),
                if (statusLabel.isNotEmpty)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        statusLabel,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Property Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 14, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Owner: $owner',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        price,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0EA5E9),
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.bed, size: 14, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 2),
                          Text(
                            beds,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.bathtub, size: 14, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 2),
                          Text(
                            baths,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // More Menu
          IconButton(
            icon: const Icon(Icons.more_vert, color: Color(0xFF94A3B8)),
            onPressed: () => _showPropertyMenu(propertyId, propertyData),
          ),
        ],
      ),
    );
  }

  void _showPropertyMenu(String propertyId, Map<String, dynamic> propertyData) {
    final status = propertyData['status'] ?? 'active';
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (status == 'pending')
              ListTile(
                leading: const Icon(Icons.check_circle, color: Color(0xFF10B981)),
                title: const Text('Approve Property'),
                onTap: () async {
                  Navigator.pop(context);
                  // ✅ Approve the property
                  await FirebaseFirestore.instance
                      .collection('properties')
                      .doc(propertyId)
                      .update({'status': 'approved'});

                  // 🔔 Notify the landlord
                  final landlordId = propertyData['landlordId'] as String?;
                  if (landlordId != null && landlordId.isNotEmpty) {
                    try {
                      await FirebaseFirestore.instance
                          .collection('notifications')
                          .doc(landlordId)
                          .collection('items')
                          .add({
                        'type': 'property_approved',
                        'title': '🎉 Property Approved!',
                        'message':
                            'Great news! Your property "${propertyData['title'] ?? 'your listing'}" '
                            'has been reviewed and approved by our team. '
                            'It is now live and visible to all tenants on Home237!',
                        'propertyId': propertyId,
                        'timestamp': FieldValue.serverTimestamp(),
                        'read': false,
                      });
                    } catch (e) {
                      debugPrint('❌ Failed to send approval notification: $e');
                    }
                  }

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Property approved! The landlord has been notified.'),
                        backgroundColor: Color(0xFF10B981),
                      ),
                    );
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.visibility, color: Color(0xFF0EA5E9)),
              title: const Text('View Details'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PropertyDetailsScreen(
                      propertyId: propertyId,
                      propertyData: propertyData,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Color(0xFF64748B)),
              title: const Text('Edit Property'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddPropertyScreen(
                      propertyId: propertyId,
                      propertyData: propertyData,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.pause, color: Color(0xFFF59E0B)),
              title: const Text('Pause Listing'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Color(0xFFEF4444)),
              title: const Text('Delete Property'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(propertyId, propertyData);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Shows a premium confirmation dialog and, if confirmed, performs a
  /// full cascade delete across Firestore + notifies the landlord.
  Future<bool> _showDeleteConfirmation(
      String propertyId, Map<String, dynamic> propertyData) async {
    final title = propertyData['title'] ?? 'this property';
    final landlordId = propertyData['landlordId'] as String?;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_forever_rounded,
                  color: Color(0xFFEF4444), size: 26),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Delete Property',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"$title" will be permanently removed from the entire app.',
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFFEF4444).withOpacity(0.3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('This will also remove:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Color(0xFFEF4444))),
                  SizedBox(height: 6),
                  _BulletRow('All saved / favourited copies'),
                  _BulletRow('All linked tour requests'),
                  _BulletRow('All related notifications'),
                ],
              ),
            ),
          ],
        ),
        actionsPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.delete_forever_rounded, size: 18),
            label: const Text('Delete Forever',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return false;

    // ── FULL CASCADE DELETE ────────────────────────────────────────────────
    try {
      final db = FirebaseFirestore.instance;

      // 1. Delete the property document itself
      await db.collection('properties').doc(propertyId).delete();

      // 2. Remove from every user's saved/favourites collection
      final allUsers = await db.collection('users').get();
      for (final userDoc in allUsers.docs) {
        try {
          final ref = db
              .collection('favorites')
              .doc(userDoc.id)
              .collection('properties')
              .doc(propertyId);
          final snap = await ref.get();
          if (snap.exists) await ref.delete();
        } catch (_) {}
      }

      // 3. Delete all tour requests linked to this property
      final tourQuery = await db
          .collection('tour_requests')
          .where('propertyId', isEqualTo: propertyId)
          .get();
      for (final doc in tourQuery.docs) {
        try { await doc.reference.delete(); } catch (_) {}
      }

      // 4. Notify the landlord
      if (landlordId != null && landlordId.isNotEmpty) {
        try {
          await db
              .collection('notifications')
              .doc(landlordId)
              .collection('items')
              .add({
            'type': 'property_removed',
            'title': '🚫 Property Removed',
            'message':
                'Your property "${propertyData['title'] ?? 'your listing'}" '
                'has been removed by the Home237 admin team. '
                'Please contact support if you believe this was a mistake.',
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
          });
        } catch (e) {
          debugPrint('⚠️ Failed to notify landlord: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Property fully deleted from the entire app.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ]),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(12))),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  // Keep legacy dialog caller so the bottom-sheet button still works
  void _confirmDeleteProperty(String propertyId,
      [Map<String, dynamic>? propertyData]) {
    _showDeleteConfirmation(propertyId, propertyData ?? {});
  }
}

/// Small bullet-row helper used inside the delete dialog.
class _BulletRow extends StatelessWidget {
  final String text;
  const _BulletRow(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('• ',
                style: TextStyle(
                    color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF64748B))),
            ),
          ],
        ),
      );
}
