import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';
import 'chat_screen.dart';
import 'signin_screen.dart';
import 'widgets/favourite_button.dart';
import 'pending_property_service.dart';
import 'tour_player_screen.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';

class PropertyDetailsScreen extends StatefulWidget {
  final String propertyId;
  final Map<String, dynamic>? propertyData;
  /// Optional: 'contact' or 'tour' — auto-triggers that action on load
  /// (used when the user returns here after signing in).
  final String? autoAction;

  const PropertyDetailsScreen({
    super.key,
    required this.propertyId,
    this.propertyData,
    this.autoAction,
  });

  @override
  State<PropertyDetailsScreen> createState() => _PropertyDetailsScreenState();
}

class _PropertyDetailsScreenState extends State<PropertyDetailsScreen> {
  bool _isFavorite = false;
  bool _isLoading = true;
  Map<String, dynamic>? _property;
  int _currentImageIndex = 0;
  String? _tourStatus;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentImageIndex);
    if (widget.propertyData != null) {
      _property = widget.propertyData;
      _isLoading = false;
    } else {
      _loadPropertyDetails();
    }
    _checkIfFavorite();
    _loadTourStatus();

    // If this screen was opened after sign-in with a pending action,
    // trigger it once the frame is ready.
    if (widget.autoAction != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.autoAction == 'contact') _contactLandlord();
        if (widget.autoAction == 'tour') _requestTour();
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadTourStatus() async {
    if (authService.userId == null) return;
    try {
      final query = await FirebaseFirestore.instance
          .collection('tour_requests')
          .where('propertyId', isEqualTo: widget.propertyId)
          .where('tenantId', isEqualTo: authService.userId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        setState(() => _tourStatus = query.docs.first['status']);
      }
    } catch (e) {
      print('Error loading tour status: $e');
    }
  }

  Future<void> _loadPropertyDetails() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('properties')
          .doc(widget.propertyId)
          .get();

      if (doc.exists) {
        setState(() {
          _property = doc.data();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading property: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkIfFavorite() async {
    if (authService.userId == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('favorites')
          .doc(authService.userId)
          .collection('properties')
          .doc(widget.propertyId)
          .get();

      setState(() => _isFavorite = doc.exists);
    } catch (e) {
      print('Error checking favorite: $e');
    }
  }

  Future<void> _toggleFavorite() async {
    // Guests must sign in first
    if (!authService.isLoggedIn) {
      _showAuthPrompt('save this property');
      return;
    }

    try {
      final favRef = FirebaseFirestore.instance
          .collection('favorites')
          .doc(authService.userId)
          .collection('properties')
          .doc(widget.propertyId);

      final propertyRef = FirebaseFirestore.instance
          .collection('properties')
          .doc(widget.propertyId);

      if (_isFavorite) {
        await favRef.delete();
        await propertyRef.update({'likesCount': FieldValue.increment(-1)});
        setState(() => _isFavorite = false);
        _showSnackBar('Removed from favorites');
      } else {
        await favRef.set({
          'propertyId': widget.propertyId,
          'addedAt': DateTime.now(),
        });
        await propertyRef.update({'likesCount': FieldValue.increment(1)});
        setState(() => _isFavorite = true);
        _showSnackBar('Added to favorites');
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}');
    }
  }

  void _showAuthPrompt(String action) {
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
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 24),
              const Icon(Icons.lock_outline, size: 48, color: Color(0xFF3B82F6)),
              const SizedBox(height: 16),
              Text('Sign in to $action',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B))),
              const SizedBox(height: 8),
              Text('Create a free account to contact landlords, save listings, and book tours.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: isDark ? Colors.white60 : const Color(0xFF64748B), height: 1.5)),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const SignInScreen()));
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF3B82F6),
                        side: const BorderSide(color: Color(0xFF3B82F6)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                         // Since signup screen isn't imported here, we push SignIn and user can click sign up from there, or we can just import SignupScreen if available. For now push SignIn.
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const SignInScreen()));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6), foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Sign Up', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _requestTour() async {
    if (!authService.isLoggedIn) {
      // Store this property + intended action so SignInScreen can return here
      PendingPropertyService.instance.set(
        widget.propertyId,
        _property ?? widget.propertyData ?? {},
        action: 'tour',
      );
      _showAuthPrompt('request a tour');
      return;
    }
    if (_property == null) return;

    try {
      await FirebaseFirestore.instance.collection('tour_requests').add({
        'propertyId': widget.propertyId,
        'tenantId': authService.userId,
        'tenantName': authService.userName,
        'landlordId': _property!['landlordId'],
        'propertyTitle': _property!['title'],
        'status': 'pending',
        'createdAt': DateTime.now(),
      });
      _showSnackBar('Tour request sent! The landlord will get back to you.');
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}');
    }
  }

  void _contactLandlord() {
    if (!authService.isLoggedIn) {
      // Store this property + intended action so SignInScreen can return here
      PendingPropertyService.instance.set(
        widget.propertyId,
        _property ?? widget.propertyData ?? {},
        action: 'contact',
      );
      _showAuthPrompt('contact the landlord');
      return;
    }
    
    if (_property == null) return;

    final landlordId = _property!['landlordId'];
    if (landlordId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to contact landlord: Missing contact information.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (landlordId == authService.userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This is your own property.'),
          backgroundColor: Colors.blue,
        ),
      );
      return;
    }

    final imageUrl = (_property!['images'] != null && (_property!['images'] as List).isNotEmpty)
        ? (_property!['images'] as List)[0] as String
        : null;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          recipientId: landlordId,
          recipientName: _property!['landlordName'] ?? 'Landlord',
          propertyTitle: _property!['title'],
          initialMessage: 'Hi, I\'m interested in your property: ${_property!['title']}',
          initialImage: imageUrl,
          propertyId: widget.propertyId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Property Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_property == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Property Details')),
        body: const Center(child: Text('Property not found')),
      );
    }

    final rawImages = _property!['images'];
    final List<dynamic> imagesList = rawImages is List ? rawImages : [];
    final List<String> images = imagesList.isNotEmpty
        ? imagesList.map((e) => e.toString()).toList()
        : ['assets/images/logo.jpg'];

    final propertyAmenities = _property!['amenities'];
    List<String> amenities = [];
    if (propertyAmenities is List) {
      amenities = propertyAmenities.map((e) => e.toString()).toList();
    } else if (propertyAmenities is String) {
      amenities = propertyAmenities
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // ── Image Slider AppBar ──────────────────────────────────────
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8.0, top: 8.0),
                child: FavouriteButton(
                  propertyId: widget.propertyId,
                  propertyData: _property ?? widget.propertyData ?? {},
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  PageView.builder(
                    controller: _pageController,
                    itemCount: images.length,
                    onPageChanged: (i) =>
                        setState(() => _currentImageIndex = i),
                    itemBuilder: (context, index) {
                      final imageUrl = images[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              opaque: false,
                              pageBuilder: (context, _, __) =>
                                  _FullscreenImageViewer(
                                imageUrls: images,
                                initialIndex: index,
                                propertyTitle:
                                    _property!['title']?.toString() ??
                                        'Property',
                                price: _property!['price']?.toString() ??
                                    '',
                                propertyId: widget.propertyId,
                              ),
                            ),
                          );
                        },
                        child: Hero(
                          tag:
                              'property_image_${widget.propertyId}_$index',
                          child: imageUrl.startsWith('http')
                              ? Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                    if (loadingProgress == null)
                                      return child;
                                    return Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress
                                                    .expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                    .cumulativeBytesLoaded /
                                                loadingProgress
                                                    .expectedTotalBytes!
                                            : null,
                                        color: const Color(0xFF3B82F6),
                                      ),
                                    );
                                  },
                                  errorBuilder:
                                      (context, error, stackTrace) =>
                                          Container(
                                    color: Colors.grey[300],
                                    child:
                                        const Icon(Icons.image, size: 80),
                                  ),
                                )
                              : Image.asset(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (context, error, stackTrace) =>
                                          Container(
                                    color: Colors.grey[300],
                                    child:
                                        const Icon(Icons.image, size: 80),
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                  // Image dots indicator
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        images.length,
                        (index) => Container(
                          margin:
                              const EdgeInsets.symmetric(horizontal: 4),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentImageIndex == index
                                ? Colors.white
                                : Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Property Content ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          _property!['title']?.toString() ?? 'Property',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: _property!['price']?.toString() ??
                                  '0 FCFA',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF3B82F6),
                              ),
                            ),
                            TextSpan(
                              text: '/mo',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Location
                  Row(
                    children: [
                      Icon(Icons.location_on,
                          size: 18,
                          color: isDark
                              ? Colors.grey[400]
                              : Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _property!['location']?.toString() ??
                              'Location not specified',
                          style: TextStyle(
                            fontSize: 15,
                            color: isDark
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Landlord Info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF374151)
                          : const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFF3B82F6).withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: const Color(0xFF3B82F6),
                          radius: 20,
                          child: Text(
                            () {
                              final name =
                                  _property!['landlordName']?.toString() ??
                                      '';
                              return name.trim().isNotEmpty
                                  ? name.trim()[0].toUpperCase()
                                  : 'L';
                            }(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'In charge: ${_property!['landlordName']?.toString() ?? 'Landlord'}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1E293B),
                                ),
                              ),
                              Text(
                                'Property Owner',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.verified,
                            color: Color(0xFF10B981), size: 20),
                      ],
                    ),
                  ),

                  if (_tourStatus != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _tourStatus == 'approved'
                            ? Colors.green.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _tourStatus == 'approved'
                                ? Icons.check_circle
                                : Icons.info,
                            size: 16,
                            color: _tourStatus == 'approved'
                                ? Colors.green
                                : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Tour Request: ${_tourStatus!.toUpperCase()}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _tourStatus == 'approved'
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Beds / Baths
                  Row(
                    children: [
                      _buildInfoCard(
                          Icons.king_bed_outlined,
                          _property!['beds']?.toString() ?? '0',
                          'Beds',
                          isDark),
                      const SizedBox(width: 12),
                      _buildInfoCard(
                          Icons.bathtub_outlined,
                          _property!['baths']?.toString() ?? '0',
                          'Baths',
                          isDark),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Description
                  Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? Colors.white
                          : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _property!['description']?.toString() ??
                        'No description available.',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),

                  // Amenities
                  if (amenities.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Amenities',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? Colors.white
                            : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: amenities.map((amenity) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF374151)
                                : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle,
                                  size: 16, color: Color(0xFF10B981)),
                              const SizedBox(width: 6),
                              Text(
                                amenity,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? Colors.grey[300]
                                      : Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Virtual Tour
                  if ((_property!['tourVideoUrl']?.toString() ?? '')
                      .isNotEmpty) ...[
                    Text(
                      'Virtual Tour 360°',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? Colors.white
                            : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TourPlayerScreen(
                            videoUrl:
                                _property!['tourVideoUrl'].toString(),
                            propertyTitle:
                                _property!['title']?.toString() ??
                                    'Property',
                          ),
                        ),
                      ),
                      child: Container(
                        height: 130,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isDark
                                ? [
                                    const Color(0xFF1E3A5F),
                                    const Color(0xFF2D1B69)
                                  ]
                                : [
                                    const Color(0xFFEFF6FF),
                                    const Color(0xFFF5F3FF)
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color:
                                  const Color(0xFF3B82F6).withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 20),
                            Container(
                              width: 56,
                              height: 56,
                              decoration: const BoxDecoration(
                                color: Color(0xFF3B82F6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.play_arrow_rounded,
                                  color: Colors.white, size: 32),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Watch Virtual Tour',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Walk through every room from here',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark
                                          ? Colors.white60
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right,
                                color: Color(0xFF3B82F6)),
                            const SizedBox(width: 12),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Location Map
                  Text(
                    'Location',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _property!['location']?.toString() ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 12),
                  () {
                    final lat = double.tryParse(
                        _property!['latitude']?.toString() ?? '');
                    final lng = double.tryParse(
                        _property!['longitude']?.toString() ?? '');

                    if (lat == null || lng == null || (lat == 0 && lng == 0)) {
                      return Container(
                        height: 220,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1F2937)
                              : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: isDark
                                  ? Colors.grey[700]!
                                  : Colors.grey[200]!),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.location_off_outlined,
                                  size: 52,
                                  color: isDark
                                      ? Colors.grey[600]
                                      : Colors.grey[400]),
                              const SizedBox(height: 12),
                              Text(
                                'Location not set for this property',
                                style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final propertyLocation = LatLng(lat, lng);
                    final detailMapController = MapController();

                    return ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        height: 260,
                        child: Stack(
                          children: [
                            // ── Map ───────────────────────────────────
                            FlutterMap(
                              mapController: detailMapController,
                              options: MapOptions(
                                initialCenter: propertyLocation,
                                initialZoom: 15.5,
                                minZoom: 3,
                                maxZoom: 19,
                                interactionOptions: const InteractionOptions(
                                  flags: InteractiveFlag.all,
                                ),
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
                                    Marker(
                                      point: propertyLocation,
                                      width: 56,
                                      height: 64,
                                      child: _AnimatedPropertyPin(),
                                    ),
                                  ],
                                ),
                                RichAttributionWidget(
                                  attributions: [
                                    TextSourceAttribution(
                                        '© CartoDB © OpenStreetMap'),
                                  ],
                                ),
                              ],
                            ),

                            // ── Zoom controls (top-right) ─────────────
                            Positioned(
                              top: 10,
                              right: 10,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _DetailMapBtn(
                                    icon: Icons.add,
                                    isTop: true,
                                    onTap: () => detailMapController.move(
                                      detailMapController.camera.center,
                                      detailMapController.camera.zoom + 1,
                                    ),
                                  ),
                                  Container(
                                      width: 34, height: 1,
                                      color: Colors.grey[200]),
                                  _DetailMapBtn(
                                    icon: Icons.remove,
                                    isTop: false,
                                    onTap: () => detailMapController.move(
                                      detailMapController.camera.center,
                                      detailMapController.camera.zoom - 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // ── "Open in Maps" chip (top-left) ────────
                            Positioned(
                              top: 10,
                              left: 10,
                              child: GestureDetector(
                                onTap: () async {
                                  final uri = Uri.parse(
                                      'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
                                  try {
                                    // ignore: deprecated_member_use
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri,
                                          mode: LaunchMode
                                              .externalApplication);
                                    }
                                  } catch (_) {}
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.15),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.open_in_new,
                                          size: 13,
                                          color: Color(0xFF3B82F6)),
                                      SizedBox(width: 4),
                                      Text(
                                        'Open in Maps',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF3B82F6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // ── Coordinate label (bottom-left) ────────
                            Positioned(
                              bottom: 24, // above attribution
                              left: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.55),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }(),



                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      // ── Bottom Actions ───────────────────────────────────────────────
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _requestTour,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Color(0xFF3B82F6)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Request Tour',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3B82F6)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _contactLandlord,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF3B82F6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Contact',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

Widget _buildInfoCard(IconData icon, String value, String label, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF3B82F6), size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            Text(
              label,
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
}

// ── Fullscreen Image Viewer ───────────────────────────────────────────────
class _FullscreenImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final String propertyTitle;
  final String price;
  final String propertyId;

  const _FullscreenImageViewer({
    required this.imageUrls,
    required this.initialIndex,
    required this.propertyTitle,
    required this.price,
    required this.propertyId,
  });

  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_currentIndex + 1} / ${widget.imageUrls.length}',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemCount: widget.imageUrls.length,
            itemBuilder: (context, index) {
              return InteractiveViewer(
                minScale: 1.0,
                maxScale: 4.0,
                child: Hero(
                  tag: 'property_image_${widget.propertyId}_$index',
                  child: widget.imageUrls[index].startsWith('http')
                      ? Image.network(
                          widget.imageUrls[index],
                          fit: BoxFit.contain,
                        )
                      : Image.asset(
                          widget.imageUrls[index],
                          fit: BoxFit.contain,
                        ),
                ),
              );
            },
          ),
          // Gradient at bottom for text readability
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.only(top: 40, bottom: 40, left: 20, right: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.propertyTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.price,
                      style: const TextStyle(
                        color: Color(0xFF3B82F6),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Triangle pointer for property marker ─────────────────────────────────────
class _TrianglePainter extends CustomPainter {
  final Color color;
  const _TrianglePainter({required this.color});

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final paint = ui.Paint()..color = color;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Animated pulsing property marker ─────────────────────────────────────────
class _AnimatedPropertyPin extends StatefulWidget {
  const _AnimatedPropertyPin();

  @override
  State<_AnimatedPropertyPin> createState() => _AnimatedPropertyPinState();
}

class _AnimatedPropertyPinState extends State<_AnimatedPropertyPin>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.88, end: 1.12).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.scale(
            scale: _anim.value,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color:
                        const Color(0xFF3B82F6).withOpacity(0.5),
                    blurRadius: 14,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child:
                  const Icon(Icons.home, color: Colors.white, size: 20),
            ),
          ),
          CustomPaint(
            size: const Size(12, 8),
            painter:
                _TrianglePainter(color: const Color(0xFF3B82F6)),
          ),
        ],
      ),
    );
  }
}

// ── Leaflet-style zoom button for property details map ────────────────────────
class _DetailMapBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isTop;
  const _DetailMapBtn(
      {required this.icon, required this.onTap, required this.isTop});

  @override
  State<_DetailMapBtn> createState() => _DetailMapBtnState();
}

class _DetailMapBtnState extends State<_DetailMapBtn> {
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
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: _pressed ? const Color(0xFFF0F9FF) : Colors.white,
          borderRadius: BorderRadius.vertical(
            top: widget.isTop ? const Radius.circular(8) : Radius.zero,
            bottom: widget.isTop ? Radius.zero : const Radius.circular(8),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.16),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child:
            Icon(widget.icon, size: 18, color: const Color(0xFF374151)),
      ),
    );
  }
}
