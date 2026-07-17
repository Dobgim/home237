import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';
import 'signin_screen.dart';
import 'signup_screen.dart';
import 'explore_screen.dart';
import 'property_details_screen.dart';
import 'widgets/favourite_button.dart';
import 'widgets/role_signup_sheet.dart';
import 'location_service.dart';
import 'package:flutter/foundation.dart'; // kIsWeb
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_localizations.dart';
import 'utils/listing_flags.dart';
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

  static const List<Map<String, dynamic>> _filterOptions = [
    {'label': 'All',       'icon': Icons.home_outlined},
    {'label': 'Apartment', 'icon': Icons.apartment_outlined},
    {'label': 'Studio',    'icon': Icons.weekend_outlined},
    {'label': 'House',     'icon': Icons.house_outlined},
    {'label': 'Office',    'icon': Icons.business_outlined},
    {'label': 'Land',      'icon': Icons.landscape_outlined},
  ];

  // Cities — names must EXACTLY match landlord 'town' field
  static const List<Map<String, dynamic>> _cities = [
    {'name': 'Buea',       'icon': Icons.terrain_outlined},
    {'name': 'Douala',     'icon': Icons.water_outlined},
    {'name': 'Yaoundé',    'icon': Icons.account_balance_outlined},
    {'name': 'Bamenda',    'icon': Icons.park_outlined},
    {'name': 'Bafoussam',  'icon': Icons.forest_outlined},
    {'name': 'Limbe',      'icon': Icons.volcano_outlined},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserCity();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _checkAndShowAuthErrors();
      // Ask first-time guests whether they are an agent or just browsing.
      final shownAgentPrompt = await _maybeShowAgentPrompt();
      // Only nudge the mobile-app download if we didn't just interrupt them.
      if (kIsWeb && !shownAgentPrompt) {
        _checkAndShowMobileAppDialog();
      }
    });
  }

  /// Shows the agent/viewer chooser to first-time guests. Returns true if shown.
  Future<bool> _maybeShowAgentPrompt() async {
    if (authService.isLoggedIn) return false; // signed-in agents/admins skip it
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('hasAnsweredAgentPrompt') ?? false) return false;
      if (!mounted) return false;
      _showAgentPrompt(prefs);
      return true;
    } catch (e) {
      debugPrint('Agent prompt error: $e');
      return false;
    }
  }

  void _showAgentPrompt(SharedPreferences prefs) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final subColor =
            isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

        void answer([Widget Function()? destination, UserRole? role]) {
          prefs.setBool('hasAnsweredAgentPrompt', true);
          if (role != null) {
            // Remembered so the sign-up screen shows the matching
            // registration banner whichever path the user takes there.
            prefs.setString(
                'preferred_signup_role', role.toString().split('.').last);
          }
          Navigator.pop(ctx);
          if (destination != null) {
            Navigator.push(
                context, MaterialPageRoute(builder: (_) => destination()));
          }
        }

        return Dialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A5F).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.waving_hand_rounded,
                          color: Color(0xFF1E3A5F), size: 28),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Center(
                    child: Text('Welcome to Home237',
                        style:
                            TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Tell us what brings you here so we can set things up for you.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, height: 1.5, color: subColor),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _promptOption(
                    isDark: isDark,
                    icon: Icons.badge_rounded,
                    accent: const Color(0xFF8B5CF6),
                    title: 'I\'m a property agent',
                    subtitle: 'List and manage properties, reach serious clients',
                    onTap: () => answer(
                        () => const SignUpScreen(
                            preselectedRole: UserRole.landlord),
                        UserRole.landlord),
                  ),
                  const SizedBox(height: 12),
                  _promptOption(
                    isDark: isDark,
                    icon: Icons.house_rounded,
                    accent: const Color(0xFF10B981),
                    title: 'I\'m looking for a home',
                    subtitle:
                        'Sign up free to save favourites, chat with agents and book visits',
                    onTap: () => answer(
                        () => const SignUpScreen(
                            preselectedRole: UserRole.tenant),
                        UserRole.tenant),
                  ),
                  const SizedBox(height: 12),
                  _promptOption(
                    isDark: isDark,
                    icon: Icons.visibility_rounded,
                    accent: const Color(0xFF1E3A5F),
                    title: 'Just browsing',
                    subtitle: 'Explore listings as a guest — sign up anytime',
                    onTap: () => answer(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _promptOption({
    required bool isDark,
    required IconData icon,
    required Color accent,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color:
                    isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B))),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color:
                      isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
            ],
          ),
        ),
      ),
    );
  }

  void _checkAndShowAuthErrors() {
    if (authService.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authService.lastError!),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
      authService.clearLastError();
    }
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

  Future<void> _checkAndShowMobileAppDialog() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasSeen = prefs.getBool('hasSeenMobileAppPrompt') ?? false;
      if (!hasSeen) {
        if (!mounted) return;
        _showMobileAppDialog(prefs);
      }
    } catch (e) {
      debugPrint('Error loading prefs for mobile prompt: $e');
    }
  }

  void _showMobileAppDialog(SharedPreferences prefs) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          title: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A5F).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.phone_android_rounded, color: Color(0xFF1E3A5F), size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Get the Mobile App!',
                  style: TextStyle(fontSize: 18, fontStyle: FontStyle.normal, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'For a much faster, smoother, and data-friendly experience, we recommend downloading our Android mobile app.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.flash_on_rounded, color: Colors.amber.shade600, size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Loads instantly and saves internet data.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.notifications_active_rounded, color: Color(0xFF10B981), size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Receive instant push notifications for properties.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                prefs.setBool('hasSeenMobileAppPrompt', true);
                Navigator.pop(ctx);
              },
              child: Text(
                'Maybe Later',
                style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                prefs.setBool('hasSeenMobileAppPrompt', true);
                Navigator.pop(ctx);
                final Uri downloadUri = Uri.parse('${Uri.base.origin}/app-release.apk');
                try {
                  if (await canLaunchUrl(downloadUri)) {
                    await launchUrl(downloadUri, mode: LaunchMode.externalApplication);
                  } else {
                    await launchUrl(downloadUri);
                  }
                } catch (e) {
                  debugPrint('Could not launch download URL: $e');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A5F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              child: const Text('Download APK', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
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
    // Viewers who change their mind pick a role (home-seeker or agent) here.
    showRoleSignupSheet(context, action: 'save this property');
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
                  if (isListingHidden(d)) continue;
                  allApproved.add(doc);
                  final rawTown = (d['town'] ?? '').toString().trim();
                  final matchedCity = _cities.firstWhere(
                    (c) => c['name']!.toLowerCase() == rawTown.toLowerCase(),
                    orElse: () => {'name': rawTown, 'icon': Icons.home_outlined},
                  );
                  byCity.putIfAbsent(matchedCity['name']!, () => []).add(doc);
                }
                // Sort each city: boosted first → newest
                for (final list in byCity.values) {
                  list.sort((a, b) {
                    final aD = a.data() as Map<String, dynamic>;
                    final bD = b.data() as Map<String, dynamic>;
                    final aB = isBoostActive(aD);
                    final bB = isBoostActive(bD);
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
                  .where((d) => isBoostActive(d.data() as Map<String, dynamic>))
                  .toList();
              if (featuredDocs.length < 5) {
                final others = allApproved
                    .where((d) => !isBoostActive(d.data() as Map<String, dynamic>))
                    .take(5 - featuredDocs.length)
                    .toList();
                featuredDocs.addAll(others);
              }

              // Only cities that have listings
              final citiesWithListings = _cities.where((c) => byCity.containsKey(c['name'])).toList();

              // On wide screens (desktop web) the content is centred in a
              // max-width column instead of stretching edge-to-edge.
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1150),
                  child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // ① App bar
                  SliverToBoxAdapter(child: _buildAppBar(isDark, allApproved.length)),

                  // ② Search bar
                  SliverToBoxAdapter(child: _buildSearchBar(isDark)),

                  // ③ Filter chips
                  SliverToBoxAdapter(child: _buildFilterChips(isDark)),

                  // Loading indicator
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: Center(child: CircularProgressIndicator(color: Color(0xFF1E3A5F))),
                      ),
                    )
                  else ...[

                    // ⑤ Near You (personalized — only if city set)
                    if (_userCity != null) ...[
                      SliverToBoxAdapter(
                        child: _buildCitySection(
                          t.get('near_you_dash').replaceAll('{city}', _userCity!), '',
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
                          city['name']! as String, city['icon'] as IconData,
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
                  ),
                ),
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
          // Logo mark
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A5F).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.home_rounded, color: Color(0xFF1E3A5F), size: 22),
          ),
          const SizedBox(width: 12),
          // App name — clear, prominent heading
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.get('app_name'),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Text(
                'Cameroon Property Rentals',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Language toggle
          const LanguageToggle(),
          const SizedBox(width: 4),
          // Login / Avatar
          ListenableBuilder(
            listenable: authService,
            builder: (context, _) {
              if (!authService.isLoggedIn) {
                return TextButton(
                  // Ask the role first, then open the matching sign-up page.
                  // Existing users tap "Already have an account? Sign in".
                  onPressed: () =>
                      showRoleSignupSheet(context, action: 'get started'),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A5F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(t.get('login'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                );
              }
              return CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF1E3A5F),
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
              const Icon(Icons.search, color: Color(0xFF1E3A5F), size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(t.get('search_hint'),
                    style: TextStyle(color: isDark ? Colors.white38 : Colors.grey[400], fontSize: 14)),
              ),
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: const Color(0xFF1E3A5F).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.tune, color: Color(0xFF1E3A5F), size: 18),
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
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final opt = _filterOptions[i];
          final isActive = _activeFilter == opt['label'];
          return GestureDetector(
            onTap: () => setState(() => _activeFilter = opt['label']!),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF1E3A5F) : (isDark ? const Color(0xFF2D2D2D) : Colors.white),
                borderRadius: BorderRadius.circular(22),
                boxShadow: isActive
                    ? [BoxShadow(color: const Color(0xFF1E3A5F).withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 3))]
                    : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: Row(children: [
                Icon(opt['icon'] as IconData, size: 16, color: isActive ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155))),
                const SizedBox(width: 6),
                Text(opt['label']! as String,
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

  // Removed from the page to keep the home screen simple; kept for reuse.
  // ignore: unused_element
  // Removed from the homepage layout; kept for reference. Not called.
  // ignore: unused_element
  Widget _buildHeroBanner(bool isDark, int total, int cities) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF15294A), Color(0xFF1E3A5F), Color(0xFFCA8A04)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A5F).withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main headline — Display text
              Text(
                _userCity != null
                    ? 'Find Your Home in $_userCity & Beyond'
                    : 'Find Your Home in Cameroon',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 8),

              // Subtitle — Body text
              const Text(
                'Verified rentals from trusted agents across Cameroon.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w400,
                ),
              ),

              const SizedBox(height: 16),

              // CTA Button — only clickable element
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ExploreScreen()),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'Explore Properties',
                        style: TextStyle(
                          color: Color(0xFF15294A),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF15294A)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
              // Section heading with badge
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF3D00)]),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Row(children: [
                    Icon(Icons.local_fire_department_rounded, size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'Featured',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ]),
                ),
              ]),
              // Browse all — tappable
              GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ExploreScreen())),
                child: Row(children: [
                  Text(t.get('browse_all'),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF1E3A5F),
                        fontWeight: FontWeight.w600,
                      )),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_forward_ios, size: 11, color: Color(0xFF1E3A5F)),
                ]),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 248,
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
  Widget _buildCitySection(String city, dynamic iconOrString,
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
                  if (iconOrString is IconData) ...[
                    Icon(
                      iconOrString,
                      size: 19,
                      color: isNearYou
                          ? const Color(0xFF1E3A5F)
                          : (isDark ? Colors.white54 : const Color(0xFF94A3B8)),
                    ),
                    const SizedBox(width: 8),
                  ] else if (iconOrString is String && iconOrString.isNotEmpty) ...[
                    Text(iconOrString, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      city,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: isNearYou
                            ? const Color(0xFF1E3A5F)
                            : (isDark ? Colors.white : const Color(0xFF0F172A)),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Count badge
                  if (docs.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isNearYou
                            ? const Color(0xFF1E3A5F).withOpacity(0.12)
                            : (isDark ? Colors.white12 : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${docs.length}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isNearYou
                              ? const Color(0xFF1E3A5F)
                              : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                        ),
                      ),
                    ),
                  ],
                ]),
              ),
              // See all — tappable link
              GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => ExploreScreen(initialRegion: rawCity))),
                child: Row(children: [
                  Text(
                    t.get('see_all'),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF1E3A5F),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_forward_ios, size: 11, color: Color(0xFF1E3A5F)),
                ]),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 248,
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
                              style: TextStyle(color: Color(0xFF1E3A5F), fontSize: 12, fontWeight: FontWeight.w600)),
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
    final isBoosted = isBoostActive(data);
    final isFastTracked = isFastTrackActive(data);
    final landlordVerified = data['landlordVerified'] == true;

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
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF3F4F6),
                        border: isFastTracked
                            ? Border.all(color: const Color(0xFF10B981), width: 2.5)
                            : null,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: imageUrl != null && imageUrl.startsWith('http')
                          ? Image.network(imageUrl, fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(Icons.home, size: 40, color: Colors.grey))
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
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.star_rounded, size: 12, color: Colors.white),
                          const SizedBox(width: 3),
                          Text(t.get('top_pick'),
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    ),
                  // Fast-Track badge
                  if (isFastTracked)
                    Positioned(
                      top: 10,
                      left: isBoosted ? 90 : 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.flash_on, size: 12, color: Colors.white),
                            SizedBox(width: 3),
                            Text(
                              'FAST-TRACK',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
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

            // ── Location (primary) + verified-owner check ──
            Row(
              children: [
                Flexible(
                  child: Text(
                    area.isNotEmpty ? '$area, $town' : town,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (landlordVerified) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.verified,
                      size: 15, color: Color(0xFF10B981)),
                ],
              ],
            ),

            const SizedBox(height: 6),

            // ── Price ──
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

}
