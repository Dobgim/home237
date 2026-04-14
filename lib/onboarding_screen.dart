import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'location_service.dart';
import 'home_page.dart';
import 'app_localizations.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Location step state
  bool _isDetecting = false;
  String? _detectedCity;
  String? _selectedCity;
  bool _locationDenied = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    _fadeController.forward(from: 0);
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 450), curve: Curves.easeInOut);
    } else {
      _completeOnboarding();
    }
  }

  Future<void> _detectLocation() async {
    setState(() {
      _isDetecting = true;
      _locationDenied = false;
    });

    final city = await LocationService.instance.detectCity();

    if (!mounted) return;

    if (city != null) {
      await LocationService.instance.saveCity(city);
      setState(() {
        _detectedCity = city;
        _selectedCity = city;
        _isDetecting = false;
      });
    } else {
      setState(() {
        _isDetecting = false;
        _locationDenied = true;
      });
    }
  }

  Future<void> _completeOnboarding() async {
    // Save selected/detected city
    if (_selectedCity != null) {
      await LocationService.instance.saveCity(_selectedCity!);
    }

    // Mark onboarding done
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);

    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const HomePage()));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: size.width,
        height: size.height,
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF0FDFA), Color(0xFFE0F2FE)],
                ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Skip button
              Align(
                alignment: Alignment.topRight,
                child: _currentPage < 2
                    ? TextButton(
                        onPressed: () => _pageController.animateToPage(2,
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut),
                        child: Text(t.get('skip'),
                            style: TextStyle(
                                color: isDark
                                    ? Colors.white54
                                    : Colors.black45)),
                      )
                    : const SizedBox(height: 40),
              ),

              // Page content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  physics: const ClampingScrollPhysics(),
                  children: [
                    _buildSlide1(isDark, size),
                    _buildSlide2(isDark, size),
                    _buildSlide3(isDark, size),
                  ],
                ),
              ),

              // Dots + Button
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
                child: Column(
                  children: [
                    // Page dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        3,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == i ? 28 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: _currentPage == i
                                ? const Color(0xFF3B82F6)
                                : (isDark
                                    ? Colors.white24
                                    : Colors.black12),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // CTA button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _currentPage == 2 &&
                                _selectedCity == null &&
                                !_isDetecting
                            ? null
                            : () {
                                if (_currentPage == 2) {
                                  _completeOnboarding();
                                } else {
                                  _nextPage();
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              const Color(0xFF3B82F6).withOpacity(0.4),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                          shadowColor:
                              const Color(0xFF3B82F6).withOpacity(0.4),
                        ),
                        child: Text(
                          _currentPage == 2
                              ? (_selectedCity != null
                                  ? t.get('explore_in_city').replaceAll('{city}', _selectedCity!)
                                  : t.get('select_city_continue'))
                              : (_currentPage == 1
                                  ? t.get('next_location_setup')
                                  : t.get('let_get_started')),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SLIDE 1 — Welcome
  // ─────────────────────────────────────────────────────────────
  Widget _buildSlide1(bool isDark, Size size) {
    final t = AppLocalizations.of(context);
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withOpacity(0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Image.asset(
                  'assets/images/home237_logo.jpg',
                  fit: BoxFit.cover,
                ),
              ),
            ),

            const SizedBox(height: 40),

            Text(
              t.get('welcome_home237'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                height: 1.2,
              ),
            ),

            const SizedBox(height: 16),

            Text(
              t.get('welcome_home237_intro'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                height: 1.6,
              ),
            ),

            const SizedBox(height: 48),

            // Feature highlights row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _miniFeature(Icons.search_rounded, t.get('browse'), isDark),
                _miniFeature(Icons.favorite_rounded, t.get('save'), isDark),
                _miniFeature(Icons.chat_bubble_rounded, t.get('chat'), isDark),
                _miniFeature(Icons.tour_rounded, t.get('tour'), isDark),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniFeature(IconData icon, String label, bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: const Color(0xFF3B82F6), size: 26),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : const Color(0xFF334155))),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SLIDE 2 — Features
  // ─────────────────────────────────────────────────────────────
  Widget _buildSlide2(bool isDark, Size size) {
    final t = AppLocalizations.of(context);
    final features = [
      {
        'icon': Icons.verified_user_outlined,
        'color': const Color(0xFF10B981),
        'title': t.get('verified_listings_title'),
        'desc': t.get('verified_listings_body')
      },
      {
        'icon': Icons.location_on_outlined,
        'color': const Color(0xFF3B82F6),
        'title': t.get('find_near_you_title'),
        'desc': t.get('find_near_you_body')
      },
      {
        'icon': Icons.chat_bubble_outline_rounded,
        'color': const Color(0xFF8B5CF6),
        'title': t.get('chat_landlords_title'),
        'desc': t.get('chat_landlords_body')
      },
      {
        'icon': Icons.favorite_border_rounded,
        'color': const Color(0xFFEF4444),
        'title': t.get('save_favorites_title'),
        'desc': t.get('save_favorites_body')
      },
    ];

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              t.get('everything_you_need'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t.get('hunter_effortless_body'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ...features.map((f) => _featureRow(
                  icon: f['icon'] as IconData,
                  color: f['color'] as Color,
                  title: f['title'] as String,
                  desc: f['desc'] as String,
                  isDark: isDark,
                )),
          ],
        ),
      ),
    );
  }

  Widget _featureRow({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? Colors.white
                            : const Color(0xFF1E293B))),
                const SizedBox(height: 3),
                Text(desc,
                    style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? Colors.white54
                            : const Color(0xFF64748B),
                        height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SLIDE 3 — Location
  // ─────────────────────────────────────────────────────────────
  Widget _buildSlide3(bool isDark, Size size) {
    final t = AppLocalizations.of(context);
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF06B6D4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF10B981).withOpacity(0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8))
                ],
              ),
              child: const Icon(Icons.my_location_rounded,
                  size: 50, color: Colors.white),
            ),

            const SizedBox(height: 32),

            Text(
              t.get('where_looking'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                height: 1.2,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              t.get('personalize_feed_body'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                height: 1.5,
              ),
            ),

            const SizedBox(height: 32),

            // Detect button
            if (_detectedCity == null && !_isDetecting)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _detectLocation,
                  icon: const Icon(Icons.gps_fixed, size: 20),
                  label: Text(t.get('detect_my_location'),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF10B981),
                    side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),

            // Loading
            if (_isDetecting) ...[
              const SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                      color: Color(0xFF10B981), strokeWidth: 2.5)),
              const SizedBox(height: 10),
              Text(t.get('detecting_your_location'),
                  style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black45,
                      fontSize: 13)),
            ],

            // Detected success
            if (_detectedCity != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFF10B981).withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF10B981), size: 22),
                    const SizedBox(width: 10),
                    Text(
                      t.get('city_detected').replaceAll('{city}', _detectedCity!),
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => setState(() {
                  _detectedCity = null;
                  _selectedCity = null;
                }),
                child: Text(t.get('change_city'),
                    style: const TextStyle(color: Color(0xFF3B82F6))),
              ),
            ],

            // Denied notice
            if (_locationDenied && _detectedCity == null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: Color(0xFFD97706), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        t.get('location_not_available_pick'),
                        style: TextStyle(
                            color: isDark
                                ? const Color(0xFF92400E)
                                : const Color(0xFF92400E),
                            fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // Manual city picker
            if (_detectedCity == null) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  t.get('or_choose_city'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white60 : const Color(0xFF475569),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children:
                    LocationService.supportedCities.map((city) {
                  final isSelected = _selectedCity == city;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCity = city),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF3B82F6)
                            : (isDark
                                ? const Color(0xFF1E293B)
                                : Colors.white),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: isSelected
                                ? const Color(0xFF3B82F6)
                                : (isDark
                                    ? Colors.white24
                                    : const Color(0xFFE2E8F0)),
                            width: 1.5),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                    color: const Color(0xFF3B82F6)
                                        .withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4))
                              ]
                            : [],
                      ),
                      child: Text(
                        city,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? Colors.white
                              : (isDark
                                  ? Colors.white70
                                  : const Color(0xFF334155)),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
