import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'admin_users_screen.dart';
import 'admin_properties_screen.dart';
import 'admin_verifications_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_support_chats_screen.dart';
import 'settings_screen.dart';
import 'auth_service.dart';
import 'email_service.dart';
import 'widgets/floating_nav_bar.dart';
import 'widgets/language_toggle.dart';
import 'package:timeago/timeago.dart' as timeago;


class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});


  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}


class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;


  final List<Widget> _screens = [
    const AdminOverviewScreen(),
    const AdminVerificationsScreen(),
    const AdminPropertiesScreen(),
    const AdminUsersScreen(),
    const AdminSupportChatsScreen(),
    const SettingsScreen(),
  ];


  DateTime? _lastBackPressTime;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        final now = DateTime.now();
        if (_lastBackPressTime == null || 
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Press back again to close the app'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                backgroundColor: const Color(0xFF374151),
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
        body: _screens[_selectedIndex],
      bottomNavigationBar: FloatingNavBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          FloatingNavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Dashboard'),
          FloatingNavItem(icon: Icons.verified_user_outlined, activeIcon: Icons.verified_user, label: 'Verify'),
          FloatingNavItem(icon: Icons.home_work_outlined, activeIcon: Icons.home_work, label: 'Properties'),
          FloatingNavItem(icon: Icons.people_outline, activeIcon: Icons.people, label: 'Users'),
          FloatingNavItem(icon: Icons.support_agent_outlined, activeIcon: Icons.support_agent, label: 'Support'),
          FloatingNavItem(icon: Icons.settings_outlined, activeIcon: Icons.settings, label: 'Settings'),
        ],
      ),
    ),
  );
}
}

class AdminOverviewScreen extends StatefulWidget {
  const AdminOverviewScreen({super.key});


  @override
  State<AdminOverviewScreen> createState() => _AdminOverviewScreenState();
}


class _AdminOverviewScreenState extends State<AdminOverviewScreen> {

  void _navigateTo(int index) {
    final parentState = context.findAncestorStateOfType<_AdminDashboardState>();
    if (parentState != null) {
      parentState.setState(() {
        parentState._selectedIndex = index;
      });
    }
  }

  void _showBroadcastDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.campaign, color: Color(0xFF8B5CF6), size: 28),
                  SizedBox(width: 8),
                  Text('Broadcast Announcement', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'This announcement will be sent as a push notification and in-app notification to all registered users.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleCtrl,
                      enabled: !isSubmitting,
                      decoration: InputDecoration(
                        labelText: 'Announcement Title',
                        hintText: 'e.g., Scheduled Maintenance',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: messageCtrl,
                      maxLines: 4,
                      enabled: !isSubmitting,
                      decoration: InputDecoration(
                        labelText: 'Message Body',
                        hintText: 'e.g., We will perform maintenance tonight at 11PM...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final title = titleCtrl.text.trim();
                          final message = messageCtrl.text.trim();
                          if (title.isEmpty || message.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please fill in both fields')),
                            );
                            return;
                          }

                          setStateDialog(() => isSubmitting = true);

                          try {
                            final callable = FirebaseFunctions.instance.httpsCallable('broadcastNotification');
                            final result = await callable.call({
                              'title': title,
                              'message': message,
                            });

                            if (context.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Broadcast sent successfully to ${result.data['count']} users!'),
                                  backgroundColor: const Color(0xFF10B981),
                                ),
                              );
                            }
                           } catch (e) {
                             final errorStr = e.toString().toLowerCase();
                             if (true) { // Trigger fallback for any function failure (e.g. Spark plan / not deployed)
                               try {
                                 final usersSnap = await FirebaseFirestore.instance.collection('users').get();
                                 final firestore = FirebaseFirestore.instance;
                                 int count = 0;
                                 WriteBatch batch = firestore.batch();

                                 for (var doc in usersSnap.docs) {
                                   final data = doc.data();
                                   final userId = doc.id;
                                   final email = data['email']?.toString();

                                   if (email != null && email.isNotEmpty) {
                                     final emailHtml = '''
                                       <div style="font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto; border: 1px solid #e5e7eb; border-radius: 12px; overflow: hidden;">
                                         <div style="background: #3B82F6; padding: 24px; text-align: center;">
                                           <h1 style="color: white; font-size: 24px; margin: 0;">🏠 Home237</h1>
                                         </div>
                                         <div style="background: #f9fafb; padding: 32px;">
                                           <h2 style="color: #1e293b; margin-top: 0; margin-bottom: 16px; font-size: 20px;">$title</h2>
                                           <p style="color: #475569; font-size: 15px; line-height: 1.6;">Hello ${data['name'] ?? 'User'},</p>
                                           <div style="background: white; border-radius: 8px; padding: 20px; border: 1px solid #e2e8f0; margin: 20px 0; color: #334155; line-height: 1.6; font-size: 14px; white-space: pre-wrap;">$message</div>
                                           <p style="color: #64748b; font-size: 13px; margin-bottom: 0;">If you have any questions, feel free to reply to this email or contact support inside the app.</p>
                                         </div>
                                         <div style="background: #f3f4f6; padding: 16px; text-align: center; border-top: 1px solid #e5e7eb;">
                                           <p style="color: #9ca3af; font-size: 12px; margin: 0;">© 2026 Home237. All rights reserved.</p>
                                         </div>
                                       </div>
                                     ''';
                                     // Call non-blocking sendHtmlEmail on the client side
                                     EmailService.sendHtmlEmail(email, title, emailHtml);
                                   }

                                   final notificationRef = firestore
                                       .collection('notifications')
                                       .doc(userId)
                                       .collection('items')
                                       .doc();

                                   batch.set(notificationRef, {
                                     'title': title,
                                     'message': message,
                                     'type': 'announcement',
                                     'read': false,
                                     'timestamp': FieldValue.serverTimestamp(),
                                   });
                                   count++;

                                   if (count % 400 == 0) {
                                     await batch.commit();
                                     batch = firestore.batch();
                                   }
                                 }

                                 if (count % 400 != 0) {
                                   await batch.commit();
                                 }

                                 if (context.mounted) {
                                   Navigator.pop(ctx);
                                   ScaffoldMessenger.of(context).showSnackBar(
                                     SnackBar(
                                       content: Text('Broadcast sent via in-app & emails to $count users!'),
                                       backgroundColor: const Color(0xFF10B981),
                                     ),
                                   );
                                 }
                                 return;
                               } catch (fallbackError) {
                                 debugPrint('Fallback broadcast failed: $fallbackError');
                               }
                             }

                            setStateDialog(() => isSubmitting = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to broadcast: $e'),
                                  backgroundColor: const Color(0xFFEF4444),
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Broadcast', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }


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
              'Welcome,',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
                letterSpacing: 1,
              ),
            ),
            Text(
              authService.userName ?? 'Admin',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Color(0xFF64748B)),
            onPressed: () {},
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('reports')
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, snapshot) {
              final openReports = snapshot.hasData ? snapshot.data!.docs.length : 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined,
                        color: Color(0xFF64748B)),
                    onPressed: () {},
                  ),
                  if (openReports > 0)
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
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          openReports > 9 ? '9+' : openReports.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const LanguageToggle(),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Stats Grid
            GridView.extent(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              maxCrossAxisExtent: 300,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.0,
              children: [
                // ─ Pending property listings (properties waiting for admin approval)
                _buildStreamStatCard(
                  FirebaseFirestore.instance
                      .collection('properties')
                      .where('status', isEqualTo: 'pending'),
                  'PENDING\nLISTINGS',
                  Icons.home_work_outlined,
                  const Color(0xFFF97316),
                  badge: (n) => n == 0 ? 'ALL CLEAR' : '$n NEW',
                  badgeColor: (n) =>
                      n == 0 ? const Color(0xFF10B981) : const Color(0xFFF97316),
                  onTap: () => _navigateTo(2),
                ),
                // ─ Pending user ID / landlord verifications
                _buildStreamStatCard(
                  FirebaseFirestore.instance
                      .collection('verifications')
                      .where('status', isEqualTo: 'pending'),
                  'PENDING\nVERIFICATIONS',
                  Icons.verified_user,
                  const Color(0xFF10B981),
                  badge: (n) => n == 0 ? 'CLEAR' : '$n PENDING',
                  badgeColor: (n) =>
                      n == 0 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                  onTap: () => _navigateTo(1),
                ),
                // ─ Open reports
                _buildStreamStatCard(
                  FirebaseFirestore.instance
                      .collection('reports')
                      .where('status', isEqualTo: 'pending'),
                  'OPEN\nREPORTS',
                  Icons.report_problem,
                  const Color(0xFFEF4444),
                  badge: (n) => n == 0 ? 'CLEAR' : '$n OPEN',
                  badgeColor: (n) =>
                      n == 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AdminReportsScreen()),
                  ),
                ),
                // ─ Total registered users
                _buildStreamStatCard(
                  FirebaseFirestore.instance.collection('users'),
                  'TOTAL\nUSERS',
                  Icons.people,
                  const Color(0xFF0EA5E9),
                  badge: (_) => 'LIVE',
                  badgeColor: (_) => const Color(0xFF0EA5E9),
                  onTap: () => _navigateTo(3),
                ),
                // ─ Approved / active listings
                _buildStreamStatCard(
                  FirebaseFirestore.instance
                      .collection('properties')
                      .where('status', isEqualTo: 'approved'),
                  'ACTIVE\nLISTINGS',
                  Icons.home_work,
                  const Color(0xFF10B981),
                  badge: (_) => 'LIVE',
                  badgeColor: (_) => const Color(0xFF10B981),
                  onTap: () => _navigateTo(2),
                ),
                // ─ Support chats with unread messages
                _buildStreamStatCard(
                  FirebaseFirestore.instance
                      .collection('support_chats')
                      .where('unreadByAdmin', isGreaterThan: 0),
                  'SUPPORT\nCHATS',
                  Icons.support_agent,
                  const Color(0xFF8B5CF6),
                  badge: (n) => n == 0 ? 'QUIET' : '$n NEW',
                  badgeColor: (n) =>
                      n == 0 ? const Color(0xFF94A3B8) : const Color(0xFF8B5CF6),
                  onTap: () => _navigateTo(4),
                ),
              ],
            ),

            
            const SizedBox(height: 24),

            // Quick Actions Section
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.campaign, color: Color(0xFF8B5CF6)),
                ),
                title: const Text(
                  'Broadcast Announcement',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                subtitle: const Text('Send push & in-app notifications to all users'),
                trailing: const Icon(Icons.chevron_right, color: Color(0xFF64748B)),
                onTap: () => _showBroadcastDialog(context),
              ),
            ),

            const SizedBox(height: 24),

            // Recent Signups Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Signups',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                TextButton(
                  onPressed: () => _navigateTo(3),
                  child: const Text(
                    'View All',
                    style: TextStyle(
                      color: Color(0xFF0EA5E9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            SizedBox(
              height: 180, // Increased to fix the 2px bottom overflow
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .orderBy('createdAt', descending: true)
                    .limit(5)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF0EA5E9)));
                  }
                  
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text('No recent signups', style: TextStyle(color: Color(0xFF94A3B8))),
                    );
                  }
                  
                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final doc = snapshot.data!.docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final name = data['name'] ?? 'New User';
                      final role = data['role'] ?? 'tenant';
                      final createdAt = data['createdAt'] as Timestamp?;
                      
                      String timeText = 'Just now';
                      if (createdAt != null) {
                        timeText = timeago.format(createdAt.toDate(), locale: 'en_short');
                      }
                      
                      Color roleColor = role == 'landlord' ? const Color(0xFF0EA5E9) : const Color(0xFF10B981);
                        
                      return Container(
                        width: 140,
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: roleColor.withOpacity(0.1),
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                style: TextStyle(color: roleColor, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: roleColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                role.toString().toUpperCase(),
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: roleColor),
                              ),
                            ),
                            const Spacer(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.access_time, size: 12, color: Color(0xFF94A3B8)),
                                const SizedBox(width: 4),
                                Text(timeText, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),


            // Critical Alerts Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Critical Alerts',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    'View All',
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),


            const SizedBox(height: 12),


            // Critical Alerts List
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('verifications')
                  .where('status', isEqualTo: 'pending')
                  .limit(1)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  final doc = snapshot.data!.docs.first;
                  final data = doc.data() as Map<String, dynamic>;
                  return _buildAlertCard(
                    title: data['userName'] ?? 'John Smith',
                    subtitle: 'New agent verification request',
                    time: '2m ago',
                    color: const Color(0xFF10B981),
                    icon: Icons.person,
                    actions: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const AdminVerificationsScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Review',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Dismiss',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),


            const SizedBox(height: 12),


            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reports')
                  .where('status', isEqualTo: 'pending')
                  .limit(1)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  final doc = snapshot.data!.docs.first;
                  final data = doc.data() as Map<String, dynamic>;
                  return _buildAlertCard(
                    title: '123 Maple St - Leak',
                    subtitle: 'Tenant reported water leak issue',
                    time: '15m ago',
                    color: const Color(0xFFEF4444),
                    icon: Icons.report_problem,
                    actions: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AdminReportsScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'View Details',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Contact',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),


            const SizedBox(height: 12),


            // ─ Real-time pending property submissions
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('properties')
                  .where('status', isEqualTo: 'pending')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final title = data['title'] ?? 'Untitled Property';
                    final landlordName =
                        data['landlordName'] ?? 'Unknown Agent';
                    final location = data['location'] ?? 'Unknown location';
                    final createdAt = data['createdAt'] as Timestamp?;
                    String timeText = 'Just now';
                    if (createdAt != null) {
                      timeText = timeago.format(createdAt.toDate());
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildAlertCard(
                        title: title,
                        subtitle:
                            'By $landlordName • $location • Awaiting approval',
                        time: timeText,
                        color: const Color(0xFFF97316),
                        icon: Icons.home_work_outlined,
                        actions: [
                          ElevatedButton.icon(
                            onPressed: () async {
                              await FirebaseFirestore.instance
                                  .collection('properties')
                                  .doc(doc.id)
                                  .update({'status': 'approved'});
                              final landlordId =
                                  data['landlordId'] as String?;
                              if (landlordId != null &&
                                  landlordId.isNotEmpty) {
                                await FirebaseFirestore.instance
                                    .collection('notifications')
                                    .doc(landlordId)
                                    .collection('items')
                                    .add({
                                  'type': 'property_approved',
                                  'title': '🎉 Property Approved!',
                                  'message':
                                      'Your property "$title" has been approved and is now live on Home237!',
                                  'propertyId': doc.id,
                                  'timestamp': FieldValue.serverTimestamp(),
                                  'read': false,
                                });
                              }
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        '✅ "$title" approved and agent notified!'),
                                    backgroundColor:
                                        const Color(0xFF10B981),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    margin: const EdgeInsets.all(16),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.check_circle_outline,
                                size: 16),
                            label: const Text('Approve',
                                style:
                                    TextStyle(fontWeight: FontWeight.w600)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () => _navigateTo(2),
                            icon: const Icon(Icons.visibility_outlined,
                                size: 16),
                            label: const Text('View',
                                style:
                                    TextStyle(fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF64748B),
                              side: const BorderSide(
                                  color: Color(0xFFE2E8F0)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
    );
  }




  Widget _buildStreamStatCard(
    Query query,
    String title,
    IconData icon,
    Color iconColor, {
    required String Function(int count) badge,
    required Color Function(int count) badgeColor,
    VoidCallback? onTap,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        final isLoading =
            snapshot.connectionState == ConnectionState.waiting;
        final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
        return _buildStatCard(
          title,
          count.toString(),
          icon,
          iconColor,
          badge(count),
          badgeColor(count),
          isLoading: isLoading,
          onTap: onTap,
        );
      },
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color iconColor,
    String changeText,
    Color changeColor, {
    bool isLoading = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      padding: const EdgeInsets.all(12),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: iconColor, size: 24),
              Flexible(
                child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      changeText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: changeColor,
                      ),
                    )),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.0, 0.2),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : FittedBox(
                        key: ValueKey<String>(value),
                        fit: BoxFit.scaleDown,
                        child: Text(
                          value,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }


  Widget _buildAlertCard({
    required String title,
    required String subtitle,
    required String time,
    required Color color,
    required IconData icon,
    required List<Widget> actions,
  }) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
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
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                time,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: actions,
            ),
          ),
        ],
      ),
    );
  }
}


