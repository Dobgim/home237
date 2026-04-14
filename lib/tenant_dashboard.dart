import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'tenant_profile_screen.dart';
import 'support_chat_screen.dart';
import 'verification_upload_screen.dart';
import 'notifications_screen.dart';
import 'package:home237/messages_screen.dart';
import 'package:home237/saved_properties_screen.dart';
import 'explore_screen.dart';
import 'property_details_screen.dart';
import 'widgets/favourite_button.dart';
import 'location_service.dart';
import 'widgets/language_toggle.dart';
import 'app_localizations.dart';

class TenantDashboard extends StatefulWidget {
  const TenantDashboard({super.key});
  @override
  State<TenantDashboard> createState() => _TenantDashboardState();
}

class _TenantDashboardState extends State<TenantDashboard> {
  int _selectedNavIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  String? _userCity;
  String _activeFilter = 'All';

  static const List<Map<String, String>> _filterOptions = [
    {'label': 'All',       'icon': '🏠'},
    {'label': 'Apartment', 'icon': '🏢'},
    {'label': 'Studio',    'icon': '🛋️'},
    {'label': 'House',     'icon': '🏡'},
    {'label': 'Office',    'icon': '🏦'},
    {'label': 'Land',      'icon': '🌍'},
  ];

  static const List<Map<String, String>> _cities = [
    {'name': 'Buea',      'emoji': '🏔️'},
    {'name': 'Douala',    'emoji': '🌊'},
    {'name': 'Yaoundé',   'emoji': '🏛️'},
    {'name': 'Bamenda',   'emoji': '🌿'},
    {'name': 'Bafoussam', 'emoji': '🏞️'},
    {'name': 'Limbe',     'emoji': '🌋'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserCity();
  }

  Future<void> _loadUserCity() async {
    // 1. Try cache
    final cached = await LocationService.instance.loadCachedCity();
    if (mounted && cached != null) {
      setState(() => _userCity = cached);
    }
    
    // 2. Try detection
    final detected = await LocationService.instance.detectCity();
    if (mounted && detected != null) {
      setState(() => _userCity = detected);
      await LocationService.instance.saveCity(detected);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<QueryDocumentSnapshot> _applyFilter(List<QueryDocumentSnapshot> docs) {
    if (_activeFilter == 'All') return docs;
    return docs.where((doc) {
      final d = doc.data() as Map<String, dynamic>;
      final type = (d['type'] ?? '').toString().toLowerCase();
      return type.contains(_activeFilter.toLowerCase());
    }).toList();
  }

  DateTime? _lastBackPressTime;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        if (_selectedNavIndex != 0) {
          setState(() => _selectedNavIndex = 0);
          return;
        }

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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: IndexedStack(
          index: _selectedNavIndex,
          children: [
            _buildTenantHomeTab(isDark, auth),
            const ExploreScreen(isTab: true),
            const SavedPropertiesScreen(),
            const MessagesScreen(),
            const TenantProfileScreen(),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(isDark),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TENANT HOME TAB
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTenantHomeTab(bool isDark, AuthService auth) {
    return SafeArea(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('properties').snapshots(),
        builder: (context, snapshot) {
          final t = AppLocalizations.of(context);
          final Map<String, List<QueryDocumentSnapshot>> byCity = {};
          final List<QueryDocumentSnapshot> allApproved = [];

          if (snapshot.hasData) {
            for (final doc in snapshot.data!.docs) {
              final d = doc.data() as Map<String, dynamic>;
              final status = (d['status'] ?? '').toString();
              if (status != 'approved' && status != 'active') continue;
              allApproved.add(doc);
              final rawTown = (d['town'] ?? '').toString().trim();
              final matchedCity = _cities.firstWhere(
                (c) => c['name']!.toLowerCase() == rawTown.toLowerCase(),
                orElse: () => {'name': rawTown, 'emoji': '🏠'},
              );
              byCity.putIfAbsent(matchedCity['name']!, () => []).add(doc);
            }
            // Sort: Boosted first, then newest
            for (final list in byCity.values) {
              list.sort((a, b) {
                final aD = a.data() as Map<String, dynamic>;
                final bD = b.data() as Map<String, dynamic>;
                final aB = aD['isBoosted'] == true;
                final bB = bD['isBoosted'] == true;
                if (aB && !bB) return -1;
                if (!aB && bB) return 1;
                final aT = aD['createdAt'];
                final bT = bD['createdAt'];
                if (aT == null && bT == null) return 0;
                if (aT == null) return 1;
                if (bT == null) return -1;
                return (bT as Timestamp).compareTo(aT as Timestamp);
              });
            }
          }

          // Featured: Boosted first, fill to 5
          final featuredDocs = allApproved
              .where((d) => (d.data() as Map<String, dynamic>)['isBoosted'] == true)
              .toList();
          if (featuredDocs.length < 5) {
            final others = allApproved
                .where((d) => (d.data() as Map<String, dynamic>)['isBoosted'] != true)
                .take(5 - featuredDocs.length)
                .toList();
            featuredDocs.addAll(others);
          }

          final citiesWithListings = _cities.where((c) => byCity.containsKey(c['name'])).toList();

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 1. Header
              SliverToBoxAdapter(child: _buildHeader(isDark, auth, allApproved.length)),

              // 2. Verification Banner
              SliverToBoxAdapter(child: _buildVerificationBanner(isDark, auth)),

              // 3. Search Bar
              SliverToBoxAdapter(child: _buildSearchSection(isDark)),

              // 4. Filter Chips
              SliverToBoxAdapter(child: _buildFilterChips(isDark)),

              // 5. Hero Banner
              SliverToBoxAdapter(child: _buildHeroBanner(isDark, allApproved.length, byCity.length)),

              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6))),
                  ),
                )
              else ...[
                // Near You
                if (_userCity != null)
                  SliverToBoxAdapter(
                    child: _buildCitySection(
                      '📍 ${t.get('near_you_dash').replaceAll('{city}', _userCity!)}', '',
                      _applyFilter(byCity[_userCity] ?? []),
                      isDark, isNearYou: true,
                    ),
                  ),

                // Featured
                if (featuredDocs.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildFeaturedSection(_applyFilter(featuredDocs), isDark),
                  ),

                // Cities
                for (final city in citiesWithListings)
                  SliverToBoxAdapter(
                    child: _buildCitySection(
                      city['name']!, city['emoji']!,
                      _applyFilter(byCity[city['name']] ?? []),
                      isDark,
                    ),
                  ),

                // Empty state if literally no properties
                if (allApproved.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
                      child: Column(children: [
                        Icon(Icons.home_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text('No listings yet', style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[500])),
                        const SizedBox(height: 8),
                        Text('Listings will appear here once approved by an admin.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                      ]),
                    ),
                  ),

                // No results for filter
                if (allApproved.isNotEmpty && _activeFilter != 'All' &&
                    citiesWithListings.every((c) => _applyFilter(byCity[c['name']] ?? []).isEmpty))
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 40),
                      child: Column(children: [
                        Text('No $_activeFilter listings found',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white60 : Colors.grey[600])),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => setState(() => _activeFilter = 'All'),
                          child: const Text('Clear filter'),
                        ),
                      ]),
                    ),
                  ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────
  Widget _buildHeader(bool isDark, AuthService auth, int totalCount) {
    final t = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 10),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.12),
              shape: BoxShape.circle,
              image: auth.profileImage != null
                  ? DecorationImage(image: NetworkImage(auth.profileImage!), fit: BoxFit.cover) : null,
            ),
            child: auth.profileImage == null
                ? Center(
                    child: Text((auth.userName ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF3B82F6))),
                  ) : null,
          ),
          const SizedBox(width: 12),
          // Greeting
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.get('welcome_back'),
                  style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B))),
                Text(auth.userName ?? t.get('tenant'),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B)),
                  overflow: TextOverflow.ellipsis, maxLines: 1),
                if (_userCity != null)
                  Row(children: [
                    const Icon(Icons.location_on, size: 12, color: Color(0xFF3B82F6)),
                    const SizedBox(width: 2),
                    Text(_userCity!, style: const TextStyle(fontSize: 12, color: Color(0xFF3B82F6), fontWeight: FontWeight.w500)),
                  ]),
              ],
            ),
          ),
          // Actions
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('support_chats').doc(auth.userId).snapshots(),
            builder: (context, snapshot) {
              final hasUnread = snapshot.hasData &&
                  (snapshot.data?.data() as Map<String, dynamic>?)?['unreadByUser'] != null &&
                  ((snapshot.data?.data() as Map<String, dynamic>?)!['unreadByUser'] as num) > 0;
              return Stack(
                children: [
                  IconButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportChatScreen())),
                    icon: Icon(Icons.chat_bubble_outline, color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B)),
                  ),
                  if (hasUnread)
                    Positioned(right: 8, top: 8,
                      child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle))),
                ],
              );
            },
          ),
          IconButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationsScreen())),
            icon: Icon(Icons.notifications_outlined, color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B)),
          ),
          const LanguageToggle(),
        ],
      ),
    );
  }

  // ── Verification Banner ────────────────────────────────────────────────
  Widget _buildVerificationBanner(bool isDark, AuthService auth) {
    final t = AppLocalizations.of(context);
    if (auth.userId == null) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('verifications')
          .where('userId', isEqualTo: auth.userId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _verificationCard(isDark, t.get('get_verified'), t.get('upload_docs_desc'), true, status: 'none', auth: auth);
        }
        final docs = snapshot.data!.docs.toList()..sort((a, b) {
          final aT = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          final bT = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          if (aT == null) return 1;
          if (bT == null) return -1;
          return bT.compareTo(aT);
        });
        final data = docs.first.data() as Map<String, dynamic>;
        final status = data['status'] ?? 'pending';
        if (status == 'approved') return const SizedBox.shrink();
        if (status == 'pending') {
          return _verificationCard(isDark, t.get('verification_pending'), t.get('wait_admin_approval'), false, status: 'pending');
        }
        if (status == 'rejected') {
          return _verificationCard(isDark, t.get('verification_rejected'), t.get('reupload_rejected_docs'), true, status: 'rejected', auth: auth);
        }
        return _verificationCard(isDark, t.get('get_verified'), t.get('upload_docs_desc'), true, status: 'none', auth: auth);
      },
    );
  }

  Widget _verificationCard(bool isDark, String title, String subtitle, bool showButton, {String status = 'none', AuthService? auth}) {
    final t = AppLocalizations.of(context);
    Color iconColor; IconData iconData;
    if (status == 'pending') {
      iconColor = const Color(0xFFF59E0B); iconData = Icons.hourglass_top_rounded;
    } else if (status == 'rejected') {
      iconColor = const Color(0xFFEF4444); iconData = Icons.gpp_bad_outlined;
    } else {
      iconColor = const Color(0xFF0EA5E9); iconData = Icons.verified_user_outlined;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.06), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: iconColor.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(iconData, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
              ]),
            ),
            if (showButton)
              ElevatedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VerificationUploadScreen(userRole: auth?.userRole ?? authService.userRole))),
                style: ElevatedButton.styleFrom(
                  backgroundColor: status == 'rejected' ? const Color(0xFFEF4444) : const Color(0xFF0EA5E9),
                  foregroundColor: Colors.white, elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(status == 'rejected' ? t.get('re_verify') : t.get('verify'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }

  // ── Search & Filters ───────────────────────────────────────────────────
  Widget _buildSearchSection(bool isDark) {
    final t = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExploreScreen())),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              const Icon(Icons.search, color: Color(0xFF3B82F6), size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(t.get('search_hint'),
                    style: TextStyle(color: isDark ? Colors.white38 : Colors.grey[400], fontSize: 14)),
              ),
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.tune, color: Color(0xFF3B82F6), size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(bool isDark) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _filterOptions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final opt = _filterOptions[i];
          final isActive = _activeFilter == opt['label'];
          return GestureDetector(
            onTap: () => setState(() => _activeFilter = opt['label']!),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF3B82F6) : (isDark ? const Color(0xFF2D2D2D) : Colors.white),
                borderRadius: BorderRadius.circular(22),
                boxShadow: isActive
                    ? [BoxShadow(color: const Color(0xFF3B82F6).withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 3))]
                    : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: Row(children: [
                Text(opt['icon']!, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(opt['label']!,
                    style: TextStyle(
                        fontSize: 13, fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                        color: isActive ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)))),
              ]),
            ),
          );
        },
      ),
    );
  }

  // ── Hero Banner ────────────────────────────────────────────────────────
  Widget _buildHeroBanner(bool isDark, int total, int cities) {
    final t = AppLocalizations.of(context);
    final title = t.get('hero_title');
    final cityText = _userCity != null ? t.get('hero_in_city_beyond').replaceAll('{city}', _userCity!) : t.get('hero_across_cameroon');
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6), Color(0xFF06B6D4)],
        ),
        boxShadow: [BoxShadow(color: const Color(0xFF3B82F6).withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Find your perfect home\n$cityText',
                  style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold, height: 1.35)),
              const SizedBox(height: 16),
              Row(children: [
                _statChip('🏠', '$total', t.get('properties')),
                const SizedBox(width: 10),
                _statChip('🏙️', '$cities', t.get('cities')),
                const SizedBox(width: 10),
                _statChip('✅', t.get('verified'), 'Listings'),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statChip(String emoji, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(20)),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 5),
        RichText(
          text: TextSpan(children: [
            TextSpan(text: value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            if (label.isNotEmpty)
              TextSpan(text: ' $label', style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ]),
        ),
      ]),
    );
  }

  // ── Featured Section ───────────────────────────────────────────────────
  Widget _buildFeaturedSection(List<QueryDocumentSnapshot> featuredDocs, bool isDark) {
    final t = AppLocalizations.of(context);
    if (featuredDocs.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF3D00)]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('🔥 ${t.get('featured')}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ]),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExploreScreen())),
                child: Row(children: [
                  Text(t.get('browse_all'), style: const TextStyle(fontSize: 13, color: Color(0xFF3B82F6), fontWeight: FontWeight.w600)),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFF3B82F6)),
                ]),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 310,
          child: ListView.builder(
            scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(left: 20, right: 40),
            itemCount: featuredDocs.length,
            itemBuilder: (context, index) {
              final doc = featuredDocs[index];
              return _buildPropertyCard(doc.id, doc.data() as Map<String, dynamic>, isDark, isFeatured: true);
            },
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  // ── City Carousel ──────────────────────────────────────────────────────
  Widget _buildCitySection(String title, String subtitle, List<QueryDocumentSnapshot> docs, bool isDark, {bool isNearYou = false}) {
    final t = AppLocalizations.of(context);
    final rawCity = isNearYou ? (_userCity ?? title) : title;
    if (docs.isEmpty && !isNearYou) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(children: [
                  if (subtitle.isNotEmpty) ...[Text(subtitle, style: const TextStyle(fontSize: 20)), const SizedBox(width: 8)],
                  Flexible(
                    child: Text(title,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                            color: isNearYou ? const Color(0xFF3B82F6) : (isDark ? Colors.white : const Color(0xFF1E293B))),
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (docs.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isNearYou ? const Color(0xFF3B82F6).withOpacity(0.12) : (isDark ? Colors.white12 : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${docs.length}',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                              color: isNearYou ? const Color(0xFF3B82F6) : (isDark ? Colors.white60 : const Color(0xFF64748B)))),
                    ),
                  ],
                ]),
              ),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExploreScreen(initialRegion: rawCity))),
                child: Row(children: [
                  Text(t.get('see_all'), style: const TextStyle(fontSize: 13, color: Color(0xFF3B82F6), fontWeight: FontWeight.w600)),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFF3B82F6)),
                ]),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 300,
          child: docs.isEmpty
              ? Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE2E8F0)),
                  ),
                  child: Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.home_outlined, size: 36, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        t.get('no_listings_near_you').replaceAll('{filter}', _activeFilter == 'All' ? '' : '$_activeFilter '),
                          style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                      if (_activeFilter != 'All') ...[
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () => setState(() => _activeFilter = 'All'),
                          child: Text(t.get('clear_filter'), style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ]),
                  ),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(left: 20, right: 40),
                  itemCount: docs.length,
                  itemBuilder: (context, index) => _buildPropertyCard(docs[index].id, docs[index].data() as Map<String, dynamic>, isDark),
                ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  // ── Property Card ──────────────────────────────────────────────────────
  Widget _buildPropertyCard(String propertyId, Map<String, dynamic> data, bool isDark, {bool isFeatured = false}) {
    final t = AppLocalizations.of(context);
    final images = data['images'] as List<dynamic>? ?? [];
    final imageUrl = images.isNotEmpty ? images[0] as String : null;
    final price = data['price'] ?? 'N/A';
    final town = data['town'] ?? 'Cameroon';
    final area = data['area'] ?? '';
    final type = data['type'] ?? 'Apartment';
    final beds = data['beds'] ?? '2';
    final isBoosted = data['isBoosted'] == true;
    final rating = (data['rating'] ?? (4.5 + (propertyId.hashCode % 50) / 100)).toStringAsFixed(2);

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PropertyDetailsScreen(propertyId: propertyId, propertyData: data))),
      child: Container(
        width: 220,
        margin: const EdgeInsets.only(right: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            SizedBox(
              height: 160,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity, height: double.infinity,
                      color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF3F4F6),
                      child: imageUrl != null && imageUrl.startsWith('http')
                          ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.home, size: 40, color: Colors.grey))
                          : const Icon(Icons.home, size: 40, color: Colors.grey),
                    ),
                  ),
                  if (isBoosted)
                    Positioned(
                      top: 10, left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF3D00)]),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('⭐ ${t.get('top_pick')}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  Positioned(
                    top: 10, right: 10,
                    child: FavouriteButton(propertyId: propertyId, propertyData: data),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Type badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
              child: Text(type, style: const TextStyle(fontSize: 11, color: Color(0xFF3B82F6), fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 6),
            // Location & Rating
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(area.isNotEmpty ? '$area, $town' : town, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                Row(children: [
                  const Icon(Icons.star_rounded, size: 13, color: Color(0xFFFBBF24)),
                  const SizedBox(width: 2),
                  Text(rating, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87)),
                ]),
              ],
            ),
            const SizedBox(height: 2),
            Text('$beds beds · $type', style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.grey[600])),
            const SizedBox(height: 5),
            RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                children: [
                  TextSpan(text: price.toString().contains('FCFA') ? price.toString().replaceAll('FCFA', '').trim() : price.toString()),
                  const TextSpan(text: ' FCFA', style: TextStyle(fontWeight: FontWeight.normal, fontSize: 12)),
                  TextSpan(text: ' ${t.get('per_month')}', style: TextStyle(fontWeight: FontWeight.normal, fontSize: 12, color: isDark ? Colors.white60 : Colors.grey[600])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BOTTOM NAV BAR
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildMessagesBadgeIcon(Widget icon) {
    if (authService.userId == null) return icon;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('conversations')
          .where('participants', arrayContains: authService.userId).snapshots(),
      builder: (context, conversationSnapshot) {
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('support_chats').doc(authService.userId).snapshots(),
          builder: (context, supportSnapshot) {
            int unreadSourcesCount = 0;
            if (conversationSnapshot.hasData) {
              for (var doc in conversationSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final count = data['unreadCount_${authService.userId}'] ?? 0;
                if ((count as num).toInt() > 0) unreadSourcesCount++;
              }
            }
            if (supportSnapshot.hasData && supportSnapshot.data!.exists) {
              final data = supportSnapshot.data!.data() as Map<String, dynamic>;
              final count = data['unreadByUser'] ?? 0;
              if ((count as num).toInt() > 0) unreadSourcesCount++;
            }
            if (unreadSourcesCount > 0) {
              return Badge(label: Text(unreadSourcesCount.toString()), child: icon);
            }
            return icon;
          },
        );
      },
    );
  }

  Widget _buildSavedBadgeIcon(Widget icon) {
    if (authService.userId == null) return icon;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('favorites').doc(authService.userId)
          .collection('properties').snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
        if (count > 0) {
          return Badge(label: Text(count.toString()), backgroundColor: const Color(0xFFEF4444), child: icon);
        }
        return icon;
      },
    );
  }

  Widget _buildBottomNav(bool isDark) {
    final t = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedNavIndex,
        onTap: (index) => setState(() => _selectedNavIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: isDark ? const Color(0xFF2D2D2D) : Colors.white,
        selectedItemColor: const Color(0xFF3B82F6),
        unselectedItemColor: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
        selectedFontSize: 11, unselectedFontSize: 11, elevation: 0,
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.home_outlined), activeIcon: const Icon(Icons.home), label: t.get('nav_home')),
          BottomNavigationBarItem(icon: const Icon(Icons.search), label: t.get('nav_explore')),
          BottomNavigationBarItem(icon: _buildSavedBadgeIcon(const Icon(Icons.favorite_outline)), activeIcon: _buildSavedBadgeIcon(const Icon(Icons.favorite)), label: t.get('nav_saved')),
          BottomNavigationBarItem(icon: _buildMessagesBadgeIcon(const Icon(Icons.chat_bubble_outline)), activeIcon: _buildMessagesBadgeIcon(const Icon(Icons.chat_bubble)), label: t.get('nav_messages')),
          BottomNavigationBarItem(icon: const Icon(Icons.person_outline), activeIcon: const Icon(Icons.person), label: t.get('nav_profile')),
        ],
      ),
    );
  }
}
