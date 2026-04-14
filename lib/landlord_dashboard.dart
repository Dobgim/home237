import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'add_property_screen.dart';
import 'my_properties_screen.dart';
import 'tour_requests_screen.dart';
import 'messages_screen.dart';
import 'notifications_screen.dart';
import 'landlord_profile_screen.dart';
import 'support_chat_screen.dart';
import 'verification_upload_screen.dart';
import 'premium_subscription_screen.dart';
import 'widgets/language_toggle.dart';
import 'app_localizations.dart';

class LandlordDashboard extends StatefulWidget {
  const LandlordDashboard({super.key});

  @override
  State<LandlordDashboard> createState() => _LandlordDashboardState();
}

class _LandlordDashboardState extends State<LandlordDashboard> {
  int _selectedNavIndex = 0;
  int _totalProperties = 0;
  int _activeProperties = 0;
  int _pendingRequests = 0;
  int _totalViews = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final userId = authService.userId;
    if (userId == null) return;

    try {
      final propertiesSnapshot = await FirebaseFirestore.instance
          .collection('properties')
          .where('landlordId', isEqualTo: userId)
          .get();

      final toursSnapshot = await FirebaseFirestore.instance
          .collection('tour_requests')
          .where('landlordId', isEqualTo: userId)
          .get();

      int views = 0;
      int active = 0;
      for (var doc in propertiesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        views += (data['views'] ?? 0) as int;
        if (data['status'] == 'active') {
          active++;
        }
      }

      if (mounted) {
        setState(() {
          _totalProperties = propertiesSnapshot.docs.length;
          _activeProperties = active;
          _pendingRequests = toursSnapshot.docs.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'pending').length;
          _totalViews = views;
        });
      }
    } catch (e) {
      print('Error loading stats: $e');
    }
  }

  DateTime? _lastBackPressTime;
  bool _welcomeShown = false;

  void _showWelcomePopup(AuthService auth) {
    if (_welcomeShown || auth.hasSeenWelcome) return;
    _welcomeShown = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          final t = AppLocalizations.of(ctx);
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            contentPadding: EdgeInsets.zero,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 140,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                    ),
                    const Icon(Icons.celebration, size: 64, color: Colors.white),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Column(
                    children: [
                      Text(
                        t.get('welcome_home237'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        t.get('landlord_welcome_body'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: isDark ? Colors.white70 : const Color(0xFF64748B),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        auth.completeWelcome();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text(t.get('let_get_started'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    });
  }

  Future<void> _navigateToAddProperty(BuildContext context, AuthService auth) async {
    if (!auth.isPremium) {
      final wantToUpgrade = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final t = AppLocalizations.of(ctx);
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.workspace_premium, color: Colors.amber),
                const SizedBox(width: 8),
                Text(t.get('upgrade_to_premium')),
              ],
            ),
            content: Text(t.get('upgrade_premium_desc')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t.get('maybe_later')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t.get('yes_upgrade')),
            ),
          ],
        );
      },
    );

      if (wantToUpgrade == true) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PremiumSubscriptionScreen(),
          ),
        );
        return; // Return after viewing premium screen so they can choose to add property again
      }
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddPropertyScreen(),
      ),
    );
    if (result == true) {
      _loadStats();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final auth = context.watch<AuthService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!auth.hasSeenWelcome) {
      _showWelcomePopup(auth);
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        final now = DateTime.now();
        if (_lastBackPressTime == null || 
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          if (mounted) {
            final t = AppLocalizations.of(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(t.get('press_back_to_close')),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                backgroundColor: isDark ? const Color(0xFF374151) : Colors.black87,
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
        } else {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8FAFC),
        body: SafeArea(
        child: _selectedNavIndex == 0
            ? _buildDashboardView(isDark, auth)
            : _selectedNavIndex == 1
            ? const MyPropertiesScreen()
            : _selectedNavIndex == 2
            ? const TourRequestsScreen()
            : _selectedNavIndex == 3
            ? const MessagesScreen()
            : const LandlordProfileScreen(),
      ),
      bottomNavigationBar: _buildBottomNav(isDark),
      floatingActionButton: _selectedNavIndex == 1
          ? FloatingActionButton.extended(
        onPressed: () => _navigateToAddProperty(context, auth),
        backgroundColor: const Color(0xFF3B82F6),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          t.get('add_property'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      )
          : null,
      ),
    );
  }

  Widget _buildDashboardView(bool isDark, AuthService auth) {
    return RefreshIndicator(
      onRefresh: _loadStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            _buildHeader(isDark, auth),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('verifications')
                  .where('userId', isEqualTo: auth.userId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildVerificationCard(
                    isDark,
                    'Get Verified',
                    'Upload documents for verification',
                    true,
                    status: 'none',
                    auth: auth,
                  );
                }

                final docs = snapshot.data!.docs.toList();
                docs.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aTime = aData['createdAt'] as Timestamp?;
                  final bTime = bData['createdAt'] as Timestamp?;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime);
                });

                final data = docs.first.data() as Map<String, dynamic>;
                final status = data['status'] ?? 'pending';

                if (status == 'approved') {
                  return const SizedBox.shrink();
                }

                if (status == 'pending') {
                  return _buildVerificationCard(
                    isDark,
                    'Verification Pending',
                    'Wait for admin approval',
                    false,
                    status: 'pending',
                    auth: auth,
                  );
                }

                if (status == 'rejected') {
                  return _buildVerificationCard(
                    isDark,
                    'Verification Rejected',
                    'Your documents have been rejected. Please re-upload.',
                    true,
                    status: 'rejected',
                    auth: auth,
                  );
                }

                return _buildVerificationCard(
                  isDark,
                  'Get Verified',
                  'Upload documents for verification',
                  true,
                  status: 'none',
                  auth: auth,
                );
              },
            ),
            _buildStatsCards(
              isDark,
              totalProperties: _totalProperties,
              activeProperties: _activeProperties,
              pendingTours: _pendingRequests,
              totalViews: _totalViews,
            ),
            _buildQuickActions(isDark, auth),
            _buildRecentActivity(isDark),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, AuthService auth) { // Accept AuthService here
    final t = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(25),
                  image: auth.profileImage != null
                      ? DecorationImage(
                          image: NetworkImage(auth.profileImage!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: auth.profileImage == null
                    ? Center(
                        child: Text(
                          (auth.userName ?? 'L')[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      auth.hasSeenWelcome ? t.get('welcome_back') : t.get('welcome_for_first_time'),
                      style: const TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            auth.userName ?? t.get('landlord'),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        if (auth.isPremium) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'PREMIUM',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const LanguageToggle(),
              if (!auth.isPremium)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PremiumSubscriptionScreen(),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(
                      t.get('upgrade'), // Using 'upgrade' key if it exists, but I added it as upgrade_to_premium... let me check app_localizations.dart
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('support_chats')
                    .doc(auth.userId)
                    .snapshots(),
                builder: (context, snapshot) {
                  final hasUnread = snapshot.hasData && 
                      (snapshot.data!.data() as Map<String, dynamic>?)?['unreadByUser'] != null &&
                      (snapshot.data!.data() as Map<String, dynamic>?)!['unreadByUser'] > 0;
                  
                  return Stack(
                    children: [
                      IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SupportChatScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                      ),
                      if (hasUnread)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 10,
                              minHeight: 10,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationsScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.notifications_outlined, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationCard(bool isDark, String title, String subtitle, bool showButton, {String status = 'none', AuthService? auth}) {
    final t = AppLocalizations.of(context);
    Color iconColor;
    IconData iconData;

    if (status == 'pending') {
      iconColor = const Color(0xFF3B82F6); // Blue for Landlord pending
      iconData = Icons.hourglass_top_rounded;
    } else if (status == 'rejected') {
      iconColor = const Color(0xFFEF4444); // Red
      iconData = Icons.gpp_bad_outlined;
    } else {
      iconColor = const Color(0xFF10B981); // Green for Landlord default
      iconData = Icons.verified_user_outlined;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                iconData,
                color: iconColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.get(title == 'Get Verified' ? 'get_verified' : (title == 'Verification Pending' ? 'verification_pending' : 'verification_rejected')),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t.get(subtitle == 'Upload documents for verification' ? 'upload_docs_desc' : (subtitle == 'Wait for admin approval' ? 'wait_admin_approval' : 'reupload_rejected_docs')),
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            if (showButton)
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VerificationUploadScreen(userRole: auth?.userRole ?? authService.userRole),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: status == 'rejected' ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  status == 'rejected' ? t.get('re_verify') : t.get('verify'),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards(
      bool isDark, {
        required int totalProperties,
        required int activeProperties,
        required int pendingTours,
        required int totalViews,
      }) {
    final t = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.get('overview'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  t.get('total_properties'),
                  totalProperties.toString(),
                  Icons.home,
                  const Color(0xFF3B82F6),
                  isDark,
                  onTap: () => setState(() => _selectedNavIndex = 1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  t.get('active'),
                  activeProperties.toString(),
                  Icons.check_circle,
                  const Color(0xFF10B981),
                  isDark,
                  onTap: () => setState(() => _selectedNavIndex = 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  t.get('pending_tours'),
                  pendingTours.toString(),
                  Icons.event,
                  const Color(0xFFF59E0B),
                  isDark,
                  onTap: () => setState(() => _selectedNavIndex = 2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  t.get('total_views'),
                  totalViews.toString(),
                  Icons.visibility,
                  const Color(0xFF8B5CF6),
                  isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title,
      String value,
      IconData icon,
      Color color,
      bool isDark, {
        VoidCallback? onTap,
      }) {
    final t = AppLocalizations.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(bool isDark, AuthService auth) {
    final t = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.get('quick_actions'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  t.get('add_property'),
                  Icons.add_home,
                  const Color(0xFF3B82F6),
                  () => _navigateToAddProperty(context, auth),
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  t.get('view_tours'),
                  Icons.event_available,
                  const Color(0xFF10B981),
                      () => setState(() => _selectedNavIndex = 2),
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  t.get('my_properties'),
                  Icons.apartment,
                  const Color(0xFFF59E0B),
                      () => setState(() => _selectedNavIndex = 1),
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  t.get('messages'),
                  Icons.chat,
                  const Color(0xFF8B5CF6),
                      () => setState(() => _selectedNavIndex = 3),
                  isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
      String title,
      IconData icon,
      Color color,
      VoidCallback onTap,
      bool isDark,
      ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity(bool isDark) {
    final t = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _selectedNavIndex = 2),
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('tour_requests')
                .where('landlordId', isEqualTo: authService.userId)
                .orderBy('createdAt', descending: true)
                .limit(3)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final requests = snapshot.data!.docs;

              if (requests.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      'No recent activity',
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: requests.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final request = requests[index].data() as Map<String, dynamic>;
                  return InkWell(
                    onTap: () => setState(() => _selectedNavIndex = 2),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: const Icon(
                              Icons.person,
                              color: Color(0xFF3B82F6),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  request['tenantName'] ?? 'Tenant',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tour request for ${request['propertyTitle'] ?? 'property'}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: request['status'] == 'pending'
                                  ? const Color(0xFFF59E0B).withOpacity(0.1)
                                  : const Color(0xFF10B981).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              request['status'] ?? 'pending',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: request['status'] == 'pending'
                                    ? const Color(0xFFF59E0B)
                                    : const Color(0xFF10B981),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesBadgeIcon(Widget icon) {
    if (authService.userId == null) return icon;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('conversations')
          .where('participants', arrayContains: authService.userId)
          .snapshots(),
      builder: (context, conversationSnapshot) {
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('support_chats')
              .doc(authService.userId)
              .snapshots(),
          builder: (context, supportSnapshot) {
            int unreadSourcesCount = 0;

            // Count unique regular conversations with unread messages
            if (conversationSnapshot.hasData) {
              for (var doc in conversationSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final count = data['unreadCount_${authService.userId}'] ?? 0;
                if ((count as num).toInt() > 0) {
                  unreadSourcesCount++;
                }
              }
            }

            // Count support chat if it has unread messages
            if (supportSnapshot.hasData && supportSnapshot.data!.exists) {
              final data = supportSnapshot.data!.data() as Map<String, dynamic>;
              final count = data['unreadByUser'] ?? 0;
              if ((count as num).toInt() > 0) {
                unreadSourcesCount++;
              }
            }

            if (unreadSourcesCount > 0) {
              return Badge(
                label: Text(unreadSourcesCount.toString()),
                child: icon,
              );
            }
            return icon;
          },
        );
      },
    );
  }

  Widget _buildBottomNav(bool isDark) {
    final t = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedNavIndex,
        onTap: (index) => setState(() => _selectedNavIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: isDark ? const Color(0xFF2D2D2D) : Colors.white,
        selectedItemColor: const Color(0xFF3B82F6),
        unselectedItemColor: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
        selectedFontSize: 11,
        unselectedFontSize: 11,
        elevation: 0,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.dashboard_outlined),
            activeIcon: const Icon(Icons.dashboard),
            label: t.get('nav_dashboard'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home),
            label: t.get('nav_properties'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.event_outlined),
            activeIcon: const Icon(Icons.event),
            label: t.get('nav_tours'),
          ),
          BottomNavigationBarItem(
            icon: _buildMessagesBadgeIcon(const Icon(Icons.chat_bubble_outline)),
            activeIcon: _buildMessagesBadgeIcon(const Icon(Icons.chat_bubble)),
            label: t.get('nav_messages'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            activeIcon: const Icon(Icons.person),
            label: t.get('nav_profile'),
          ),
        ],
      ),
    );
  }
}