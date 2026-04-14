import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';
import 'signin_screen.dart';
import 'explore_screen.dart';
import 'property_details_screen.dart';
import 'widgets/favourite_button.dart';
import 'location_service.dart';
import 'package:provider/provider.dart';
import 'locale_notifier.dart';
import 'app_localizations.dart';
import 'widgets/language_toggle.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  String? _userCity;
  String _activeFilter = 'All'; // quick type filter

  static const List<Map<String, String>> _filterOptions = [
    {'label': 'All',       'icon': '🏠'},
    {'label': 'Apartment', 'icon': '🏢'},
    {'label': 'Studio',    'icon': '🛋️'},
    {'label': 'House',     'icon': '🏡'},
    {'label': 'Office',    'icon': '🏦'},
    {'label': 'Land',      'icon': '🌍'},
  ];

  // Cities — names must EXACTLY match landlord 'town' field
  static const List<Map<String, String>> _cities = [
    {'name': 'Buea',       'emoji': '🏔️'},
    {'name': 'Douala',     'emoji': '🌊'},
    {'name': 'Yaoundé',    'emoji': '🏛️'},
    {'name': 'Bamenda',    'emoji': '🌿'},
    {'name': 'Bafoussam',  'emoji': '🏞️'},
    {'name': 'Limbe',      'emoji': '🌋'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserCity();
  }

  Future<void> _loadUserCity() async {
    // 1. Try to load from cache first
    final cached = await LocationService.instance.loadCachedCity();
    if (mounted && cached != null) setState(() => _userCity = cached);

    // 2. Try to detect real location
    final detected = await LocationService.instance.detectCity();
    if (mounted && detected != null) {
      setState(() => _userCity = detected);
      // Save it back to cache
      await LocationService.instance.saveCity(detected);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Apply type filter to a list of docs ───────────────────────────────
  List<QueryDocumentSnapshot> _applyFilter(List<QueryDocumentSnapshot> docs) {
    if (_activeFilter == 'All') return docs;
    return docs.where((doc) {
      final d = doc.data() as Map<String, dynamic>;
      final type = (d['type'] ?? '').toString().toLowerCase();
      return type.contains(_activeFilter.toLowerCase());
    }).toList();
  }

  void _showSignInBottomSheet() {
    final t = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              const Icon(Icons.lock_outline, size: 48, color: Color(0xFF3B82F6)),
              const SizedBox(height: 16),
              Text(t.get('sign_in_to_continue'),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1E293B))),
              const SizedBox(height: 8),
              Text(t.get('create_free_account_body'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: isDark ? Colors.white60 : const Color(0xFF64748B), height: 1.5)),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SignInScreen()));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6), foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(t.get('sign_in_up_button'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t.get('continue_browsing'))),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  DateTime? _lastBackPressTime;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        body: SafeArea(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('properties').snapshots(),
            builder: (context, snapshot) {
              // ── Build data maps ────────────────────────────────────────
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
                // Sort each city: boosted first → newest
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

              // Featured = boosted + top-5 newest across all cities
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

              // Only cities that have listings
              final citiesWithListings = _cities.where((c) => byCity.containsKey(c['name'])).toList();

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // ① App bar
                  SliverToBoxAdapter(child: _buildAppBar(isDark, allApproved.length)),

                  // ② Search bar
                  SliverToBoxAdapter(child: _buildSearchBar(isDark)),

                  // ③ Filter chips
                  SliverToBoxAdapter(child: _buildFilterChips(isDark)),

                  // ④ Hero / stats banner
                  SliverToBoxAdapter(child: _buildHeroBanner(isDark, allApproved.length, byCity.length)),

                  // Loading indicator
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6))),
                      ),
                    )
                  else ...[

                    // ⑤ Near You (personalized — only if city set)
                    if (_userCity != null) ...[
                      SliverToBoxAdapter(
                        child: _buildCitySection(
                          '📍 ${t.get('near_you_dash').replaceAll('{city}', _userCity!)}', '',
                          _applyFilter(byCity[_userCity] ?? []),
                          isDark, isNearYou: true,
                        ),
                      ),
                    ],

                    // ⑥ Featured section (only when ≥ 1 property)
                    if (featuredDocs.isNotEmpty)
                      SliverToBoxAdapter(
                        child: _buildFeaturedSection(_applyFilter(featuredDocs), isDark),
                      ),

                    // ⑦ City sections — ONLY show cities that have listings
                    for (final city in citiesWithListings)
                      SliverToBoxAdapter(
                        child: _buildCitySection(
                          city['name']!, city['emoji']!,
                          _applyFilter(byCity[city['name']] ?? []),
                          isDark,
                        ),
                      ),

                    // Empty state
                    if (allApproved.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
                          child: Column(children: [
                            Icon(Icons.home_outlined, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(t.get('no_listings'), style: TextStyle(
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
        ),
      ),
    );
  }

  // ── App Bar ─────────────────────────────────────────────────────────────
  Widget _buildAppBar(bool isDark, int totalCount) {
    final t = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.home_outlined, color: Color(0xFF3B82F6), size: 22),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.get('app_name'),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1E293B))),
              if (totalCount > 0)
                Text('$totalCount ${t.get('listings_available')}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF3B82F6),
                        fontWeight: FontWeight.w500)),
            ],
          ),
          // Language Toggle
          _buildLanguageToggle(isDark),
          const SizedBox(width: 12),
          ListenableBuilder(
            listenable: authService,
            builder: (context, _) {
              if (!authService.isLoggedIn) {
                return TextButton(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SignInScreen())),
                  style: TextButton.styleFrom(
                    backgroundColor: isDark ? Colors.transparent : Colors.white,
                    foregroundColor: isDark ? Colors.white : const Color(0xFF3B82F6),
                    side: BorderSide(color: const Color(0xFF3B82F6).withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(t.get('login'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                );
              }
              return CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF3B82F6),
                backgroundImage: authService.profileImage != null
                    ? NetworkImage(authService.profileImage!) : null,
                child: authService.profileImage == null
                    ? const Icon(Icons.person, color: Colors.white, size: 20) : null,
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Search Bar ─────────────────────────────────────────────────────────
  Widget _buildSearchBar(bool isDark) {
    final t = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: GestureDetector(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ExploreScreen())),
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
                decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.tune, color: Color(0xFF3B82F6), size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Filter Chips ───────────────────────────────────────────────────────
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
                        fontSize: 13,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                        color: isActive ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)))),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroBanner(bool isDark, int total, int cities) {
    final t = AppLocalizations.of(context);
    final title = t.get('hero_title');
    final cityText = _userCity != null 
        ? t.get('hero_in_city_beyond').replaceAll('{city}', _userCity!) 
        : t.get('hero_across_cameroon');

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
              Text('$title\n$cityText',
                  style: const TextStyle(color: Colors.white, fontSize: 19,
                      fontWeight: FontWeight.bold, height: 1.35)),
              const SizedBox(height: 16),
              Row(children: [
                _statChip('🏠', '$total', t.get('properties')),
                const SizedBox(width: 10),
                _statChip('🏙️', '$cities', t.get('cities')),
                const SizedBox(width: 10),
                _statChip('✅', t.get('verified'), ''),
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
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 5),
        RichText(
          text: TextSpan(children: [
            TextSpan(text: value,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            TextSpan(text: ' $label',
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ]),
        ),
      ]),
    );
  }

  // ── Featured Section ───────────────────────────────────────────────────
  Widget _buildFeaturedSection(List<QueryDocumentSnapshot> docs, bool isDark) {
    final t = AppLocalizations.of(context);
    if (docs.isEmpty) return const SizedBox.shrink();
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
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ExploreScreen())),
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
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(left: 20, right: 40),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              return _buildPropertyCard(doc.id, data, isDark, isFeatured: true);
            },
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  // ── City Carousel Section ────────────────────────────────────────────
  Widget _buildCitySection(String city, String emoji,
      List<QueryDocumentSnapshot> docs, bool isDark, {bool isNearYou = false}) {
    final t = AppLocalizations.of(context);
    final rawCity = isNearYou ? (_userCity ?? city) : city;

    // Skip empty sections entirely (unless Near You — show friendly message)
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
                  if (emoji.isNotEmpty) ...[
                    Text(emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(city,
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold,
                            color: isNearYou
                                ? const Color(0xFF3B82F6)
                                : (isDark ? Colors.white : const Color(0xFF1E293B))),
                        overflow: TextOverflow.ellipsis),
                  ),
                  // Count badge
                  if (docs.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isNearYou
                            ? const Color(0xFF3B82F6).withOpacity(0.12)
                            : (isDark ? Colors.white12 : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${docs.length}',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold,
                              color: isNearYou
                                  ? const Color(0xFF3B82F6)
                                  : (isDark ? Colors.white60 : const Color(0xFF64748B)))),
                    ),
                  ],
                ]),
              ),
              GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => ExploreScreen(initialRegion: rawCity))),
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
                          child: const Text('Clear filter',
                              style: TextStyle(color: Color(0xFF3B82F6), fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ]),
                  ),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(left: 20, right: 40),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildPropertyCard(doc.id, data, isDark);
                  },
                ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  // ── Property Card ────────────────────────────────────────────────────
  Widget _buildPropertyCard(String propertyId, Map<String, dynamic> data, bool isDark,
      {bool isFeatured = false}) {
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
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => PropertyDetailsScreen(propertyId: propertyId, propertyData: data))),
      child: Container(
        width: 220,
        margin: const EdgeInsets.only(right: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image ──
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
                          ? Image.network(imageUrl, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.home, size: 40, color: Colors.grey))
                          : const Icon(Icons.home, size: 40, color: Colors.grey),
                    ),
                  ),
                  // Boosted badge
                  if (isBoosted)
                    Positioned(
                      top: 10, left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF3D00)]),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('⭐ ${t.get('top_pick')}',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  // Heart
                  Positioned(
                    top: 10, right: 10,
                    child: FavouriteButton(
                        propertyId: propertyId, propertyData: data,
                        onRequireAuth: _showSignInBottomSheet),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── Type badge ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(type,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF3B82F6), fontWeight: FontWeight.w600)),
            ),

            const SizedBox(height: 6),

            // ── Location + Rating ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(area.isNotEmpty ? '$area, $town' : town,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF1E293B)),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                Row(children: [
                  const Icon(Icons.star_rounded, size: 13, color: Color(0xFFFBBF24)),
                  const SizedBox(width: 2),
                  Text(rating, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87)),
                ]),
              ],
            ),

            const SizedBox(height: 2),

            Text('$beds beds · $type',
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.grey[600])),

            const SizedBox(height: 5),

            RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black),
                children: [
                  TextSpan(text: price.toString().contains('FCFA')
                      ? price.toString().replaceAll('FCFA', '').trim()
                      : price.toString()),
                  TextSpan(text: ' FCFA', style: const TextStyle(fontWeight: FontWeight.normal, fontSize: 12)),
                  TextSpan(text: ' ${t.get('per_month')}', style: TextStyle(
                      fontWeight: FontWeight.normal, fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.grey[600])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageToggle(bool isDark) {
    return const LanguageToggle();
  }
}
