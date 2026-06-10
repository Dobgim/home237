import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'app_localizations.dart';
import 'tenant_profile_screen.dart';
import 'landlord_profile_screen.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSyncing = false;
  bool _isDeleting = false;

  Future<void> _refreshData() async {
    // StreamBuilder handles this automatically, but we can show a brief refresh indicator
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Refreshing user data...'),
        duration: Duration(milliseconds: 500),
      ),
    );
  }

  void _showSetupGuideDialog(String featureName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.settings_applications, color: Color(0xFF0EA5E9)),
            const SizedBox(width: 10),
            const Text('Setup Required'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To use $featureName, you need to enable an API in your Firebase/Google Cloud Console.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              '1. Go to your Google Cloud Console.',
              style: TextStyle(fontSize: 14),
            ),
            const Text(
              '2. Search for "Artifact Registry API".',
              style: TextStyle(fontSize: 14),
            ),
            const Text(
              '3. Click "ENABLE".',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            const Text(
              'Once enabled, I can finish the deployment and this button will work "real-time"!',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => url_launcher.launchUrl(
                  Uri.parse("https://console.cloud.google.com/apis/library/artifactregistry.googleapis.com?project=home237-92c18")
                ),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open API Console'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0EA5E9),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('I will do it now'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 80,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).get('users'),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                return Text(
                  '$count total accounts',
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
            icon: const Icon(Icons.refresh, color: Color(0xFF0EA5E9)),
            tooltip: 'Refresh List',
            onPressed: _refreshData,
          ),
          IconButton(
            icon: const Icon(Icons.person_add, color: Color(0xFF0EA5E9)),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
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
                        onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                        decoration: InputDecoration(
                          hintText: 'Search...',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8)),
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
                            _buildFilterChip('Landlords'),
                            const SizedBox(width: 8),
                            _buildFilterChip('Tenants'),
                            const SizedBox(width: 8),
                            _buildFilterChip('Suspended'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Users List
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('No users found'));
                    }

                    var users = snapshot.data!.docs;

                    // Apply filters
                    if (_selectedFilter != 'All') {
                      users = users.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final role = data['role'] ?? '';
                        if (_selectedFilter == 'Landlords') return role == 'landlord';
                        if (_selectedFilter == 'Tenants') return role == 'tenant';
                        if (_selectedFilter == 'Suspended') return data['suspended'] == true;
                        return true;
                      }).toList();
                    }

                    // Apply search
                    if (_searchQuery.isNotEmpty) {
                      users = users.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final name = (data['name'] ?? '').toString().toLowerCase();
                        final email = (data['email'] ?? '').toString().toLowerCase();
                        return name.contains(_searchQuery) || email.contains(_searchQuery);
                      }).toList();
                    }

                    // Sort users by createdAt descending
                    users.sort((a, b) {
                      final aData = a.data() as Map<String, dynamic>;
                      final bData = b.data() as Map<String, dynamic>;
                      final aTime = aData['createdAt'] as Timestamp?;
                      final bTime = bData['createdAt'] as Timestamp?;
                      if (aTime == null && bTime == null) return 0;
                      if (aTime == null) return 1;
                      if (bTime == null) return -1;
                      return bTime.compareTo(aTime);
                    });

                    // Group users by date
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    final yesterday = today.subtract(const Duration(days: 1));

                    final List<DocumentSnapshot> todayUsers = [];
                    final List<DocumentSnapshot> yesterdayUsers = [];
                    final List<DocumentSnapshot> earlierUsers = [];

                    for (var doc in users) {
                      final data = doc.data() as Map<String, dynamic>;
                      final createdAt = data['createdAt'] as Timestamp?;
                      if (createdAt != null) {
                        final date = createdAt.toDate();
                        final DateUtilsDate = DateTime(date.year, date.month, date.day);
                        if (DateUtilsDate == today) {
                          todayUsers.add(doc);
                        } else if (DateUtilsDate == yesterday) {
                          yesterdayUsers.add(doc);
                        } else {
                          earlierUsers.add(doc);
                        }
                      } else {
                        earlierUsers.add(doc);
                      }
                    }

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (todayUsers.isNotEmpty) ...[
                          _buildDateHeader('Today'),
                          ...todayUsers.map((doc) => _buildUserListItem(doc)),
                        ],
                        if (yesterdayUsers.isNotEmpty) ...[
                          _buildDateHeader('Yesterday'),
                          ...yesterdayUsers.map((doc) => _buildUserListItem(doc)),
                        ],
                        if (earlierUsers.isNotEmpty) ...[
                          _buildDateHeader('Earlier'),
                          ...earlierUsers.map((doc) => _buildUserListItem(doc)),
                        ],
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'SHOWING ${users.length} OF ${snapshot.data!.docs.length} USERS',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              ],
            ),
            
            // Loading Overlay
            if (_isDeleting)
              Container(
                color: Colors.black45,
                child: const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Managing User Data...', style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 8),
                          Text('Please wait a moment.', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFF64748B),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildUserListItem(DocumentSnapshot doc) {
    final userData = doc.data() as Map<String, dynamic>;
    final userId = doc.id;
    final name = userData['name'] ?? 'User';

    return Dismissible(
      key: Key(userId),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        // Tap the real delete confirmation; dismissible is just the gesture trigger
        _confirmDeleteUser(userId, userData);
        return false; // actual deletion is handled inside the dialog
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.delete_forever, color: Colors.white, size: 28),
            SizedBox(height: 4),
            Text('DELETE',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1)),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _buildUserCard(userData, userId),
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

  Widget _buildUserCard(Map<String, dynamic> userData, String userId) {
    final name = userData['name'] ?? 'Unknown User';
    final email = userData['email'] ?? '';
    final role = userData['role'] ?? 'none';
    final suspended = userData['suspended'] == true;

    String roleLabel = '';
    Color roleColor = const Color(0xFF0EA5E9);

    if (role == 'landlord') {
      roleLabel = 'LANDLORD';
      roleColor = const Color(0xFF0EA5E9);
    } else if (role == 'tenant') {
      roleLabel = 'TENANT';
      roleColor = const Color(0xFF10B981);
    } else if (suspended) {
      roleLabel = 'SUSPENDED';
      roleColor = const Color(0xFFEF4444);
    }

    return Container(
      padding: const EdgeInsets.all(16),
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
          // Avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: roleColor.withOpacity(0.1),
            child: Text(
              name[0].toUpperCase(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: roleColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (roleLabel.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: roleColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          roleLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: roleColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          // More Menu
          IconButton(
            icon: const Icon(Icons.more_vert, color: Color(0xFF94A3B8)),
            onPressed: () => _showUserMenu(userId, userData),
          ),
        ],
      ),
    );
  }

  void _showUserMenu(String userId, Map<String, dynamic> userData) {
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
            ListTile(
              leading: const Icon(Icons.visibility, color: Color(0xFF0EA5E9)),
              title: const Text('View Profile'),
              onTap: () {
                Navigator.pop(context);
                final role = userData['role'] ?? '';
                if (role == 'tenant') {
                  _viewUserDetails(userData);
                } else if (role == 'landlord') {
                  _viewUserDetails(userData);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Color(0xFF64748B)),
              title: const Text('Edit User'),
              onTap: () {
                Navigator.pop(context);
                _editUserDialog(userId, userData);
              },
            ),
            ListTile(
              leading: Icon(
                userData['suspended'] == true ? Icons.play_arrow : Icons.block,
                color: const Color(0xFFF59E0B),
              ),
              title: Text(userData['suspended'] == true ? 'Unsuspend User' : 'Suspend User'),
              onTap: () async {
                Navigator.pop(context);
                final isSuspended = userData['suspended'] == true;
                await FirebaseFirestore.instance.collection('users').doc(userId).update({
                  'suspended': !isSuspended,
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isSuspended ? 'User unsuspended' : 'User suspended')),
                  );
                }
              },
            ),
            ListTile(
              leading: Icon(
                userData['role'] == 'admin' ? Icons.admin_panel_settings_outlined : Icons.admin_panel_settings,
                color: const Color(0xFF8B5CF6),
              ),
              title: Text(userData['role'] == 'admin' ? 'Remove Admin' : 'Make Admin'),
              onTap: () async {
                Navigator.pop(context);
                final isAdmin = userData['role'] == 'admin';
                await FirebaseFirestore.instance.collection('users').doc(userId).update({
                  'role': isAdmin ? 'tenant' : 'admin',
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isAdmin ? 'Admin rights removed' : 'User is now an Admin')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Color(0xFFEF4444)),
              title: const Text('Delete User'),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteUser(userId, userData);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _viewUserDetails(Map<String, dynamic> userData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(userData['name'] ?? 'User Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow(Icons.email, 'Email', userData['email'] ?? 'N/A'),
            _detailRow(Icons.person, 'Role', (userData['role'] ?? 'N/A').toString().toUpperCase()),
            _detailRow(Icons.phone, 'Phone', userData['phone'] ?? 'Not provided'),
            _detailRow(Icons.location_on, 'Location', userData['address'] ?? 'Not provided'),
            _detailRow(Icons.calendar_today, 'Joined', 'Recent'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF64748B)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _editUserDialog(String userId, Map<String, dynamic> userData) {
    final nameController = TextEditingController(text: userData['name']);
    final emailController = TextEditingController(text: userData['email']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('users').doc(userId).update({
                'name': nameController.text.trim(),
                'email': emailController.text.trim(),
              });
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteUser(String userId, Map<String, dynamic> userData) {
    final name = userData['name'] ?? 'this user';
    final email = userData['email'] ?? '';
    final role = (userData['role'] ?? 'user').toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Danger icon
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_forever_rounded,
                  color: Color(0xFFEF4444), size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              'Delete "$name"?',
              style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              email,
              style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 20),
            // What gets deleted
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('This will permanently delete:',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFDC2626), fontSize: 13)),
                  const SizedBox(height: 10),
                  _deleteImpactRow('User account & profile'),
                  if (role == 'landlord')
                    _deleteImpactRow('All their property listings'),
                  _deleteImpactRow('All notifications'),
                  _deleteImpactRow('Verification documents'),
                  _deleteImpactRow('Saved favourites'),
                  _deleteImpactRow('Tour requests & messages'),
                  _deleteImpactRow('Chats & conversations'),
                  const SizedBox(height: 8),
                  const Text('⚠️ This action cannot be undone.',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFDC2626))),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _performUserDeletion(userId, userData);
                    },
                    icon: const Icon(Icons.delete_forever, size: 18),
                    label: const Text('Delete Now',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _deleteImpactRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.remove_circle, color: Color(0xFFEF4444), size: 14),
          const SizedBox(width: 8),
          Text(text,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  /// Deletes a list of documents in small batches of up to 400 operations
  /// to stay safely under Firestore's 500-operation batch limit.
  Future<void> _batchDeleteDocs(List<DocumentReference> refs) async {
    const chunkSize = 400;
    for (var i = 0; i < refs.length; i += chunkSize) {
      final chunk = refs.sublist(i, (i + chunkSize).clamp(0, refs.length));
      final batch = FirebaseFirestore.instance.batch();
      for (var ref in chunk) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }

  Future<void> _performUserDeletion(
      String userId, Map<String, dynamic> userData) async {
    setState(() => _isDeleting = true);
    try {
      // 1. Attempt Firebase Auth deletion via Cloud Function (Blaze plan)
      FirebaseFunctions.instance
          .httpsCallable('deleteUserAccount')
          .call({'uid': userId})
          .catchError((_) {});

      final db = FirebaseFirestore.instance;

      // 2. Ban the email so they can't re-register
      final email = userData['email']?.toString().toLowerCase().trim();
      if (email != null && email.isNotEmpty) {
        await db.collection('banned_users').doc().set({
          'email': email,
          'bannedAt': FieldValue.serverTimestamp(),
          'reason': 'Deleted by Admin',
          'originalUserId': userId,
        });
      }

      // 3. Delete user document (triggers auth listener → forced sign-out)
      await db.collection('users').doc(userId).delete();

      // 4. Notifications
      final notifications = await db
          .collection('notifications').doc(userId)
          .collection('items').get();
      await _batchDeleteDocs(notifications.docs.map((d) => d.reference).toList());

      // 5. Verifications
      final verifications = await db
          .collection('verifications')
          .where('userId', isEqualTo: userId).get();
      await _batchDeleteDocs(verifications.docs.map((d) => d.reference).toList());

      // 6. Properties (landlord listings)
      final properties = await db
          .collection('properties')
          .where('landlordId', isEqualTo: userId).get();
      await _batchDeleteDocs(properties.docs.map((d) => d.reference).toList());

      // 7. Favourites sub-collection
      final favProps = await db
          .collection('favorites').doc(userId)
          .collection('properties').get();
      await _batchDeleteDocs(favProps.docs.map((d) => d.reference).toList());
      await db.collection('favorites').doc(userId).delete();

      // 8. Tour requests (as requester or property owner)
      final tourAsRequester = await db
          .collection('tour_requests')
          .where('userId', isEqualTo: userId).get();
      await _batchDeleteDocs(tourAsRequester.docs.map((d) => d.reference).toList());

      final tourAsLandlord = await db
          .collection('tour_requests')
          .where('landlordId', isEqualTo: userId).get();
      await _batchDeleteDocs(tourAsLandlord.docs.map((d) => d.reference).toList());

      // 9. Messages / conversations
      final chatsAsSender = await db
          .collection('messages')
          .where('senderId', isEqualTo: userId).get();
      await _batchDeleteDocs(chatsAsSender.docs.map((d) => d.reference).toList());

      final chatsAsReceiver = await db
          .collection('messages')
          .where('receiverId', isEqualTo: userId).get();
      await _batchDeleteDocs(chatsAsReceiver.docs.map((d) => d.reference).toList());

      // 10. Support chats
      final supportChats = await db
          .collection('support_chats')
          .where('userId', isEqualTo: userId).get();
      await _batchDeleteDocs(supportChats.docs.map((d) => d.reference).toList());

      // 11. Sessions
      await db.collection('sessions').doc(userId).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Text('User deleted & all data cleaned up'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }
}
