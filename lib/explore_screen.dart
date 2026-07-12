import 'dart:convert';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'property_details_screen.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'widgets/favourite_button.dart';
import 'widgets/language_toggle.dart';
import 'app_localizations.dart';
import 'utils/listing_flags.dart';
import 'package:geolocator/geolocator.dart';

class ExploreScreen extends StatefulWidget {
  final String? initialCategory;
  final String? initialRegion;
  final String? searchQuery;
  /// Set to true when used as a bottom-nav tab inside TenantDashboard
  /// to avoid nested Scaffold overflow and hide the back button.
  final bool isTab;
  const ExploreScreen({
    super.key,
    this.initialCategory,
    this.initialRegion,
    this.searchQuery,
    this.isTab = false,
  });

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  late String _selectedCategory;
  String _selectedRegion = 'All Regions';
  TextEditingController? _autocompleteController;
  String _activeSearch = '';
  
  final MapController _mapController = MapController();
  LatLng _mapCenter = const LatLng(3.8480, 11.5021); // Yaoundé default
  double _mapZoom = 12.0;
  LatLng? _userLocation;
  bool _isLocating = false;

  final List<String> _categories = ['All', 'Apartment', 'House', 'Studio', 'Condo', 'Villa', 'Room'];
  final List<String> _regions = [
    'All Regions',
    'Buea',
    'Douala',
    'Yaoundé',
    'Limbe',
    'Kribi',
    'Bafoussam',
    'Bamenda',
    'Garoua',
  ];
  bool _isMapView = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory ?? 'All';
    _selectedRegion = widget.initialRegion ?? 'All Regions';
    _activeSearch = widget.searchQuery ?? '';
    // _searchController was not defined, assuming it should be _autocompleteController
    _autocompleteController = TextEditingController(text: widget.searchQuery ?? '');

    // If search query exactly matches a region name, pre-select that region chip
    if (_activeSearch.isNotEmpty) {
      final matchedRegion = _regions.firstWhere(
        (r) => r.toLowerCase() == _activeSearch.toLowerCase(),
        orElse: () => '',
      );
      if (matchedRegion.isNotEmpty) {
        _selectedRegion = matchedRegion;
        _activeSearch = '';
        _autocompleteController?.clear(); // Use _autocompleteController here
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _determineUserPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _userLocation = LatLng(position.latitude, position.longitude);
        });
      }
    } catch (e) {
      debugPrint('Error determining user position: $e');
    }
  }

  Future<void> _locateMe() async {
    if (_isLocating) return;
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final loc = LatLng(position.latitude, position.longitude);
      if (mounted) {
        setState(() {
          _userLocation = loc;
          _mapCenter = loc;
          _mapZoom = 15.0;
        });
        _mapController.move(loc, 15.0);
      }
    } catch (e) {
      debugPrint('Locate me error: $e');
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = SafeArea(
      bottom: false,
      child: Column(
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 20, 0),
            child: Row(
              children: [
                if (!widget.isTab)
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                  ),
                if (!widget.isTab) const SizedBox(width: 4),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: widget.isTab ? 16 : 0),
                    child: Text(
                      t.get('explore_properties'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(_isMapView ? Icons.list : Icons.map_outlined),
                  onPressed: () {
                    setState(() {
                      _isMapView = !_isMapView;
                    });
                    if (_isMapView && _userLocation == null) {
                      _determineUserPosition();
                    }
                  },
                ),
                const LanguageToggle(),
              ],
            ),
          ),

            // ── Search Bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? const Color(0xFF3D3D3D) : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Autocomplete<String>(
                  initialValue: TextEditingValue(text: widget.searchQuery ?? ''),
                  optionsBuilder: (TextEditingValue textEditingValue) async {
                    final query = textEditingValue.text;
                    // Update state so the map/list filters immediately even before selection
                    setState(() => _activeSearch = query);
                    if (query.length < 3) return const Iterable<String>.empty();
                    
                    try {
                      final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&countrycodes=cm&format=json&limit=5');
                      final response = await http.get(url, headers: {'User-Agent': 'Home237App/1.0'});
                      if (response.statusCode == 200) {
                        final List data = json.decode(response.body);
                        return data.map((e) {
                          final parts = e['display_name'].toString().split(', ');
                          return parts.take(2).join(', ');
                        }).toSet().toList();
                      }
                    } catch (_) {}
                    return const Iterable<String>.empty();
                  },
                  onSelected: (String selection) {
                    final searchStr = selection.split(',').first.trim();
                    setState(() => _activeSearch = searchStr);
                    // Override the field text to just the main name, so it matches our Firestore 'area' or 'town' better
                    _autocompleteController?.text = searchStr;
                  },
                  fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                    _autocompleteController = controller;
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onChanged: (val) => setState(() => _activeSearch = val),
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        hintText: t.get('search_explore_hint'),
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white38 : Colors.grey[400],
                          fontSize: 13,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: isDark ? Colors.white38 : const Color(0xFF3B82F6),
                        ),
                        suffixIcon: _activeSearch.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  controller.clear();
                                  setState(() => _activeSearch = '');
                                  focusNode.unfocus();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    );
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 6,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: MediaQuery.of(context).size.width - 40,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListView.separated(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            separatorBuilder: (context, index) => Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey[200]),
                            itemBuilder: (context, index) {
                              final option = options.elementAt(index);
                              return InkWell(
                                onTap: () => onSelected(option),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  child: Row(
                                    children: [
                                      Icon(Icons.location_on_outlined, size: 20, color: Colors.grey[500]),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(option, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14)),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Property Type Filter ──
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = _selectedCategory == category;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = category),
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF3B82F6)
                            : isDark
                                ? const Color(0xFF374151)
                                : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF3B82F6)
                              : isDark
                                  ? const Color(0xFF4B5563)
                                  : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : isDark
                                    ? const Color(0xFFD1D5DB)
                                    : const Color(0xFF374151),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 10),

            // ── Region / City Filter ──
            SizedBox(
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _regions.length,
                itemBuilder: (context, index) {
                  final region = _regions[index];
                  final isSelected = _selectedRegion == region;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedRegion = region),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF10B981)
                            : isDark
                                ? const Color(0xFF374151).withOpacity(0.5)
                                : Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          region,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 14),

            // ── Properties List / Map ──
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _buildQuery().snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    debugPrint('Firestore Error: ${snapshot.error}');
                    return _buildEmptyState(isDark);
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // Client-side filter: status, category, region, free-text
                  var properties = snapshot.data!.docs.where((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    final status = (d['status'] ?? '').toString();
                    // Only show approved (or active for legacy)
                    if (status != 'approved' && status != 'active') return false;
                    // Category filter
                    if (_selectedCategory != 'All') {
                      if ((d['type'] ?? '').toString() != _selectedCategory) return false;
                    }
                    // Region filter (case-insensitive)
                    if (_selectedRegion != 'All Regions') {
                      if ((d['town'] ?? '').toString().toLowerCase() !=
                          _selectedRegion.toLowerCase()) {
                        return false;
                      }
                    }
                    return true;
                  }).toList();

                  // Map to hold search scores for relevance sorting
                  Map<String, int> searchScores = {};
                  List<QueryDocumentSnapshot> categoryProperties = List.from(properties);

                  if (_activeSearch.isNotEmpty) {
                    final queryWords = _activeSearch.toLowerCase()
                        .replaceAll(RegExp(r'[^\w\s]'), '') // remove punctuation
                        .split(RegExp(r'\s+'))
                        .where((w) => !['in', 'at', 'the', 'a', 'an', 'for', 'with', 'precisely', 'show', 'me', 'some', 'i', 'want', 'to', 'see'].contains(w) && w.isNotEmpty)
                        .toList();

                    properties = properties.where((doc) {
                      final d = doc.data() as Map<String, dynamic>;
                      final searchableText = [
                        (d['title'] ?? '').toString(),
                        (d['area'] ?? '').toString(),
                        (d['town'] ?? '').toString(),
                        (d['location'] ?? '').toString(),
                        (d['type'] ?? '').toString(),
                        (d['description'] ?? '').toString(),
                      ].join(' ').toLowerCase();

                      if (queryWords.isEmpty) {
                        return searchableText.contains(_activeSearch.toLowerCase());
                      }

                      int score = 0;
                      for (final word in queryWords) {
                        if (searchableText.contains(word)) score++;
                      }
                      
                      if (score > 0) {
                        searchScores[doc.id] = score;
                        return true;
                      }
                      return false;
                    }).toList();
                  }

                  bool showingAlternatives = false;
                  if (properties.isEmpty && _activeSearch.isNotEmpty) {
                    showingAlternatives = true;
                    properties = categoryProperties;
                  }

                  // Sort: 1) Search Score  2) Premium landlord in-region  3) Newest
                  properties.sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;

                    // 1. Search relevance score
                    final scoreA = searchScores[a.id] ?? 0;
                    final scoreB = searchScores[b.id] ?? 0;
                    if (scoreA != scoreB) return scoreB.compareTo(scoreA);

                    // 2. Premium landlord flag (isLandlordPremium stamped at subscribe time)
                    final aPremium = aData['isLandlordPremium'] == true ||
                        isBoostActive(aData) ||
                        isFastTrackActive(aData);
                    final bPremium = bData['isLandlordPremium'] == true ||
                        isBoostActive(bData) ||
                        isFastTrackActive(bData);
                    if (aPremium && !bPremium) return -1;
                    if (!aPremium && bPremium) return 1;

                    // 3. Recently confirmed/created listings before stale ones
                    final aFresh = isListingFresh(aData);
                    final bFresh = isListingFresh(bData);
                    if (aFresh && !bFresh) return -1;
                    if (!aFresh && bFresh) return 1;

                    // 4. Newest last
                    final aTime = aData['createdAt'];
                    final bTime = bData['createdAt'];
                    if (aTime == null && bTime == null) return 0;
                    if (aTime == null) return 1;
                    if (bTime == null) return -1;
                    return (bTime as Timestamp).compareTo(aTime as Timestamp);
                  });

                  if (properties.isEmpty) {
                    return _buildEmptyState(isDark);
                  }

                  if (_isMapView) {
                    return _buildMapView(properties, showingAlternatives: showingAlternatives);
                  }

                  return _buildListGrid(properties, isDark, showingAlternatives: showingAlternatives);
                },
              ),
            ),
          ],
        ),
    );

    // When used as a tab, return content directly (no nested Scaffold)
    if (widget.isTab) {
      return ColoredBox(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8FAFC),
        child: content,
      );
    }
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: content,
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final t = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.home_outlined, size: 80, color: isDark ? Colors.grey[600] : Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            t.get('no_properties_found'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _activeSearch.isNotEmpty
                ? '${t.get('no_results_for').replaceAll('{query}', _activeSearch)}\n${t.get('try_different_keyword')}'
                : t.get('try_different_area'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[500] : Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildMapView(List<QueryDocumentSnapshot> properties, {bool showingAlternatives = false}) {
    // Compute bounds for "fit all" button
    final validProperties = properties.where((doc) {
      final d = doc.data() as Map<String, dynamic>;
      return d['latitude'] != null && d['longitude'] != null;
    }).toList();

    return StatefulBuilder(
      builder: (context, setMapState) {
        QueryDocumentSnapshot? selectedDoc;

        return Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _mapCenter,
                initialZoom: _mapZoom,
                minZoom: 3,
                maxZoom: 19,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
                onTap: (_, _) => setMapState(() => selectedDoc = null),
                onPositionChanged: (position, hasGesture) {
                  _mapCenter = position.center;
                                  _mapZoom = position.zoom;
                                },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.home237.app',
                  maxZoom: 19,
                ),
                MarkerLayer(
                  markers: [
                    ...properties.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final lat = data['latitude'] as double?;
                      final lng = data['longitude'] as double?;
                      if (lat == null || lng == null) return null;
                      final isSelected = selectedDoc?.id == doc.id;
                      final isPremium = isBoostActive(data) ||
                          isFastTrackActive(data) ||
                          data['subscriptionStatus'] == 'premium';
                      return Marker(
                        point: LatLng(lat, lng),
                        width: 90,
                        height: isSelected ? 58 : 46,
                        child: GestureDetector(
                          onTap: () {
                            setMapState(() => selectedDoc = doc);
                            _mapController.move(LatLng(lat, lng), 15.0);
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF1D4ED8)
                                      : isPremium
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFF3B82F6),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isSelected
                                              ? const Color(0xFF1D4ED8)
                                              : const Color(0xFF3B82F6))
                                          .withOpacity(0.45),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.home,
                                        color: Colors.white, size: 13),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        data['price']?.toString() ?? '',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Pin tail
                              CustomPaint(
                                size: const Size(10, 6),
                                painter: _MapPinTailPainter(
                                  color: isSelected
                                      ? const Color(0xFF1D4ED8)
                                      : isPremium
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFF3B82F6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).whereType<Marker>(),
                    if (_userLocation != null)
                      Marker(
                        point: _userLocation!,
                        width: 40,
                        height: 40,
                        child: const _UserLocationMarker(),
                      ),
                  ],
                ),
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution(
                        '© CartoDB © OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),

            if (showingAlternatives)
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade300),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade800),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No exact matches for "$_activeSearch". Here are some alternatives in this area!',
                          style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Zoom controls (top-right) ──────────────────────────────
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MapIconButton(
                      icon: Icons.add,
                      isTop: true,
                      onTap: () => _mapController.move(
                          _mapController.camera.center,
                          _mapController.camera.zoom + 1),
                    ),
                    Container(height: 1, color: Colors.grey[200]),
                    _MapIconButton(
                      icon: Icons.remove,
                      isTop: false,
                      onTap: () => _mapController.move(
                          _mapController.camera.center,
                          _mapController.camera.zoom - 1),
                    ),
                  ],
                ),
              ),
            ),

            // ── Locate Me Button (bottom-right) ─────────────────────────────
            Positioned(
              bottom: selectedDoc != null ? 180 : 36,
              right: 12,
              child: _MapControlButton(
                onTap: _isLocating ? null : _locateMe,
                tooltip: 'My Location',
                child: _isLocating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF3B82F6)),
                      )
                    : const Icon(Icons.my_location,
                        size: 20, color: Color(0xFF3B82F6)),
              ),
            ),

            // ── Fit-All button (top-left) ─────────────────────────────
            if (validProperties.isNotEmpty)
              Positioned(
                top: 12,
                left: 12,
                child: GestureDetector(
                  onTap: () {
                    if (validProperties.isEmpty) return;
                    // Compute bounding box
                    final lats = validProperties.map((doc) {
                      final d = doc.data() as Map<String, dynamic>;
                      return d['latitude'] as double;
                    }).toList();
                    final lngs = validProperties.map((doc) {
                      final d = doc.data() as Map<String, dynamic>;
                      return d['longitude'] as double;
                    }).toList();
                    final bounds = LatLngBounds(
                      LatLng(lats.reduce((a, b) => a < b ? a : b) - 0.05,
                          lngs.reduce((a, b) => a < b ? a : b) - 0.05),
                      LatLng(lats.reduce((a, b) => a > b ? a : b) + 0.05,
                          lngs.reduce((a, b) => a > b ? a : b) + 0.05),
                    );
                    _mapController.fitCamera(
                      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(32)),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2))
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fit_screen,
                            size: 16, color: Colors.grey[700]),
                        const SizedBox(width: 5),
                        Text('Fit All',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700])),
                      ],
                    ),
                  ),
                ),
              ),

            // ── Property popup card (bottom) ──────────────────────────
            if (selectedDoc != null)
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: _PropertyPopupCard(
                  doc: selectedDoc!,
                  onViewDetails: () => _navigateToDetails(
                    selectedDoc!.id,
                    selectedDoc!.data() as Map<String, dynamic>,
                  ),
                  onClose: () => setMapState(() => selectedDoc = null),
                ),
              ),
          ],
        );
      },
    );
  }


  Widget _buildListGrid(List<QueryDocumentSnapshot> properties, bool isDark, {bool showingAlternatives = false}) {
    final t = AppLocalizations.of(context);
    final gridView = GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        crossAxisSpacing: 14,
        mainAxisSpacing: 18,
        childAspectRatio: 0.72,
      ),
      itemCount: properties.length,
      itemBuilder: (context, index) {
        final property = properties[index].data() as Map<String, dynamic>;
        final propertyId = properties[index].id;
        final images = property['images'] as List<dynamic>? ?? [];
        final imageUrl = images.isNotEmpty ? images[0] as String : null;
        final ratingCount = property['ratingCount'] ?? 0;
        final ratingVal = property['rating'] ?? 0.0;
        final ratingStr = ratingCount > 0 ? '${ratingVal.toStringAsFixed(1)} ($ratingCount)' : 'New';
        final isBoosted = isBoostActive(property);
        final isFastTracked = isFastTrackActive(property);
        final isLandlordPremium = property['isLandlordPremium'] == true;
        final landlordVerified = property['landlordVerified'] == true;

        return GestureDetector(
          onTap: () => _navigateToDetails(propertyId, property),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Image (takes remaining space above text rows) ──
              Expanded(
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: double.infinity,
                        height: double.infinity,
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
                    if (isBoosted)
                      Positioned(
                        top: 8, left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF3D00)]),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, size: 10, color: Colors.white),
                              const SizedBox(width: 2),
                              Text(t.get('top_pick'),
                                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    if (isLandlordPremium && !isBoosted && !isFastTracked)
                      Positioned(
                        top: 8, left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFCC00), Color(0xFFFF9500)],
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFCC00).withAlpha(80),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.workspace_premium, size: 10, color: Colors.white),
                              SizedBox(width: 2),
                              Text('FEATURED',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    if (isFastTracked)
                      Positioned(
                        top: 8, left: isBoosted ? 85 : 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.flash_on, size: 10, color: Colors.white),
                              SizedBox(width: 2),
                              Text('FAST-TRACK',
                                  style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8, right: 8,
                        child: FavouriteButton(
                          propertyId: propertyId,
                          propertyData: property,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // ── Title (+ verified-owner check) ──
              Row(
                children: [
                  Flexible(
                    child: Text(
                      "${property['area'] ?? ''}${property['area'] != null ? ', ' : ''}${property['town'] ?? ''}",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (landlordVerified) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.verified,
                        size: 14, color: Color(0xFF10B981)),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              // ── Subtitle (Category · Rating) ──
              Row(
                children: [
                  Flexible(
                    child: Text(
                      "${property['type'] ?? 'Apt'} · ",
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.grey[600],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.star, size: 12, color: Colors.amber),
                  const SizedBox(width: 2),
                  Text(
                    ratingStr,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              // ── Price ──
              Text(
                property['price']?.toString() ?? '0 FCFA',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );

    if (!showingAlternatives) return gridView;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.orange.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade300),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange.shade800),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'No exact matches for "$_activeSearch". Here are some alternatives in this area!',
                  style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: gridView),
      ],
    );
  }

  void _navigateToDetails(String id, Map<String, dynamic> data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PropertyDetailsScreen(propertyId: id, propertyData: data),
      ),
    );
  }

  /// Single broad query — NO compound filters, NO orderBy.
  /// All filtering (status, category, region, free-text) is done client-side.
  /// This avoids ALL composite index requirements and the flash bug.
  Query _buildQuery() {
    return FirebaseFirestore.instance.collection('properties');
  }
}

// ── Property popup card shown when a map marker is tapped ─────────────────────

class _PropertyPopupCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final VoidCallback onViewDetails;
  final VoidCallback onClose;

  const _PropertyPopupCard({
    required this.doc,
    required this.onViewDetails,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final images = data['images'] as List<dynamic>? ?? [];
    final imageUrl = images.isNotEmpty ? images[0] as String? : null;
    final isPremium = isBoostActive(data) ||
        isFastTrackActive(data) ||
        data['subscriptionStatus'] == 'premium';
    final isFastTracked = isFastTrackActive(data);

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      shadowColor: Colors.black.withOpacity(0.25),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Property image
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              child: SizedBox(
                width: 100,
                height: 100,
                child: imageUrl != null && imageUrl.startsWith('http')
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            Container(color: const Color(0xFFF3F4F6),
                                child: const Icon(Icons.home, color: Colors.grey)),
                      )
                    : Container(
                        color: const Color(0xFFF3F4F6),
                        child: const Icon(Icons.home, size: 36, color: Colors.grey)),
              ),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        if (isPremium && !isFastTracked)
                          Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('FEATURED',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold)),
                          ),
                        if (isPremium && isFastTracked) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 4, right: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('FEATURED',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold)),
                          ),
                          Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('FAST-TRACK',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      data['title']?.toString() ?? 'Property',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 12, color: Color(0xFF64748B)),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            '${data['area'] ?? ''}${data['area'] != null ? ', ' : ''}${data['town'] ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      data['price']?.toString() ?? '0 FCFA',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3B82F6)),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 30,
                      child: ElevatedButton(
                        onPressed: onViewDetails,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: const Text('View Details',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Close button
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: GestureDetector(
                  onTap: onClose,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close,
                        size: 14, color: Colors.black54),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Marker pin tail triangle painter ─────────────────────────────────────────

class _MapPinTailPainter extends CustomPainter {
  final Color color;
  const _MapPinTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = ui.Paint()..color = color;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_MapPinTailPainter old) => old.color != color;
}

// ── Leaflet-style zoom button ─────────────────────────────────────────────────

class _MapIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isTop;
  const _MapIconButton(
      {required this.icon, required this.onTap, required this.isTop});

  @override
  State<_MapIconButton> createState() => _MapIconButtonState();
}

class _MapIconButtonState extends State<_MapIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _pressed ? const Color(0xFFF0F9FF) : Colors.white,
          borderRadius: BorderRadius.vertical(
            top: widget.isTop ? const Radius.circular(8) : Radius.zero,
            bottom: widget.isTop ? Radius.zero : const Radius.circular(8),
          ),
        ),
        child: Icon(widget.icon, size: 20, color: const Color(0xFF374151)),
      ),
    );
  }
}

// ── Pulsing User Location Marker ───────────────────────────────────────────

class _UserLocationMarker extends StatefulWidget {
  const _UserLocationMarker();

  @override
  State<_UserLocationMarker> createState() => _UserLocationMarkerState();
}

class _UserLocationMarkerState extends State<_UserLocationMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: 4.0, end: 18.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: _animation.value * 2,
              height: _animation.value * 2,
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity((1.0 - _controller.value).clamp(0.0, 1.0)),
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFF3B82F6),
                shape: BoxShape.circle,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Generic Leaflet-style control button ─────────────────────────────────────

class _MapControlButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;
  final String tooltip;

  const _MapControlButton({
    required this.onTap,
    required this.child,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}
