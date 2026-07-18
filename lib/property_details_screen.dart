import 'dart:ui' as ui;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';
import 'chat_screen.dart';
import 'signin_screen.dart';
import 'widgets/favourite_button.dart';
import 'widgets/role_signup_sheet.dart';
import 'pending_property_service.dart';
import 'tour_player_screen.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'tour_pass_display_screen.dart';
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
  String? _tourRequestId;
  String? _escrowCode;
  late PageController _pageController;

  LatLng? _resolvedLatLng;
  bool _isResolvingLocation = false;
  int _myRating = 0;
  final TextEditingController _reviewController = TextEditingController();
  bool _isSubmittingReview = false;

  // Owner (landlord) trust signals shown to the viewer
  bool _landlordVerified = false;
  double? _landlordRating;
  int _landlordRatingCount = 0;

  /// Known city centres for fallback coordinates
  static const Map<String, LatLng> _cityCentres = {
    'Buea':      LatLng(4.1527,  9.2432),
    'Douala':    LatLng(4.0511,  9.7679),
    'Yaoundé':   LatLng(3.8480, 11.5021),
    'Limbe':     LatLng(4.0174,  9.1990),
    'Kribi':     LatLng(2.9393,  9.9078),
    'Bafoussam': LatLng(5.4737, 10.4176),
    'Bamenda':   LatLng(5.9597, 10.1458),
    'Garoua':    LatLng(9.3013, 13.3922),
  };

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentImageIndex);
    if (widget.propertyData != null) {
      _property = widget.propertyData;
      _isLoading = false;
      _resolvePropertyLocation();
      _incrementViewCount();
      _loadLandlordTrust();
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
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _incrementViewCount() async {
    try {
      final landlordId = _property?['landlordId'];
      final currentUserId = authService.userId;
      // Increment only if viewer is not the landlord of this property
      if (landlordId != null && currentUserId != landlordId) {
        await FirebaseFirestore.instance
            .collection('properties')
            .doc(widget.propertyId)
            .update({
          'views': FieldValue.increment(1),
        });
      }
    } catch (e) {
      print('Error incrementing view count: $e');
    }
  }

  Future<void> _loadTourStatus() async {
    if (authService.userId == null) return;
    try {
      final query = await FirebaseFirestore.instance
          .collection('tour_requests')
          .where('propertyId', isEqualTo: widget.propertyId)
          .where('tenantId', isEqualTo: authService.userId)
          .get();

      if (query.docs.isNotEmpty) {
        final docs = query.docs.toList();
        docs.sort((a, b) {
          final aData = a.data();
          final bData = b.data();
          final aTime = aData.containsKey('createdAt') ? aData['createdAt'] : null;
          final bTime = bData.containsKey('createdAt') ? bData['createdAt'] : null;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          if (aTime is Timestamp && bTime is Timestamp) {
            return bTime.compareTo(aTime); // descending (newest first)
          }
          return 0;
        });

        final doc = docs.first;
        setState(() {
          _tourStatus = doc['status'];
          if (_tourStatus == 'escrowed' || _tourStatus == 'approved' || _tourStatus == 'pending') {
            _tourRequestId = doc.id;
            _escrowCode = doc['escrowCode'];
          }
        });
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
        _resolvePropertyLocation();
        _incrementViewCount();
        _loadLandlordTrust();
      }
    } catch (e) {
      print('Error loading property: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Loads the owner's real trust signals (KYC verification + reputation)
  /// so the viewer sees an honest badge instead of an always-green checkmark.
  Future<void> _loadLandlordTrust() async {
    final landlordId = _property?['landlordId'];
    if (landlordId == null) return;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(landlordId.toString())
          .get();

      bool verified = false;
      double? rating;
      if (userDoc.exists) {
        final data = userDoc.data() ?? {};
        // Verified = KYC flag OR Tier 2+ (Verified badge). Fall back to the
        // listing's denormalized flag so the detail badge can never contradict
        // the browse card the user just tapped.
        final tier = data['verificationTier'];
        verified = data['isVerified'] == true ||
            (tier is int && tier >= 2) ||
            _property?['landlordVerified'] == true;
        final score = data['reputationScore'] ?? data['trustRating'];
        if (score is num) rating = score.toDouble();
      } else {
        verified = _property?['landlordVerified'] == true;
      }

      // Number of reviews backing the reputation score
      final ratingsSnap = await FirebaseFirestore.instance
          .collection('reputation_ratings')
          .where('rateeId', isEqualTo: landlordId.toString())
          .get();
      final count = ratingsSnap.docs.length;

      if (mounted) {
        setState(() {
          _landlordVerified = verified;
          _landlordRating = count > 0 ? rating : null;
          _landlordRatingCount = count;
        });
      }
    } catch (e) {
      print('Error loading landlord trust: $e');
    }
  }

  /// Lets a viewer flag a suspicious listing. Writes to the `reports`
  /// collection that the admin Reports screen reads.
  Future<void> _reportListing() async {
    final reasons = <String>[
      'Suspected scam / fraud',
      'Fake or misleading photos',
      'Property does not exist',
      'Wrong price or details',
      'Already rented / unavailable',
      'Other',
    ];

    String? selected;
    final detailsController = TextEditingController();

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) => Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.flag_outlined, color: Color(0xFFEF4444)),
                    const SizedBox(width: 8),
                    const Text('Report this listing',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Help keep Home237 safe. Reports are reviewed by our team.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                ...reasons.map((r) => RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: r,
                      groupValue: selected,
                      activeColor: const Color(0xFFEF4444),
                      title: Text(r, style: const TextStyle(fontSize: 14)),
                      onChanged: (v) => setModal(() => selected = v),
                    )),
                const SizedBox(height: 8),
                TextField(
                  controller: detailsController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Add details (optional)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: selected == null
                        ? null
                        : () => Navigator.pop(ctx, true),
                    child: const Text('Submit report',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );

    if (submitted != true || selected == null) return;

    try {
      // Ensure the reporter has at least an anonymous identity
      if (authService.userId == null) {
        await authService.ensureGuestChatIdentity();
      }
      final extra = detailsController.text.trim();
      final reason = extra.isEmpty ? selected! : '${selected!} — $extra';

      await FirebaseFirestore.instance.collection('reports').add({
        'reportId':
            '#REP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        'propertyId': widget.propertyId,
        'propertyTitle': _property?['title']?.toString() ??
            _property?['area']?.toString() ??
            'Property',
        'landlordId': _property?['landlordId'],
        'type': selected,
        'reason': reason,
        'reporterId': authService.userId,
        'reporterName': authService.userName ?? 'Anonymous',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thanks — this listing has been reported for review.'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('Error submitting report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not submit report. Please try again.'),
            backgroundColor: Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _resolvePropertyLocation() async {
    final prop = _property;
    if (prop == null) return;

    final latVal = prop['latitude'];
    final lngVal = prop['longitude'];

    double? lat;
    double? lng;

    if (latVal != null && lngVal != null) {
      lat = double.tryParse(latVal.toString());
      lng = double.tryParse(lngVal.toString());
    }

    if (lat != null && lng != null && lat != 0 && lng != 0) {
      if (mounted) {
        setState(() {
          _resolvedLatLng = LatLng(lat!, lng!);
          _isResolvingLocation = false;
        });
      }
      return;
    }

    // Try geocoding if lat/lng are missing
    final area = (prop['area'] ?? '').toString().trim();
    final town = (prop['town'] ?? '').toString().trim();

    if (area.isEmpty && town.isEmpty) {
      if (mounted) {
        setState(() {
          _resolvedLatLng = null;
          _isResolvingLocation = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _isResolvingLocation = true);
    }

    try {
      // Build specific query e.g. "Molyko, Buea, Cameroon"
      final parts = <String>[];
      if (area.isNotEmpty) parts.add(area);
      if (town.isNotEmpty) parts.add(town);
      parts.add('Cameroon');
      final query = Uri.encodeComponent(parts.join(', '));

      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1',
      );

      final response = await http.get(
        uri,
        headers: {'User-Agent': 'Home237App/1.0'},
      );

      if (response.statusCode == 200) {
        final results = jsonDecode(response.body) as List<dynamic>;
        if (results.isNotEmpty) {
          final foundLat = double.parse(results[0]['lat'] as String);
          final foundLng = double.parse(results[0]['lon'] as String);
          final resolved = LatLng(foundLat, foundLng);

          if (mounted) {
            setState(() {
              _resolvedLatLng = resolved;
              _isResolvingLocation = false;
            });
          }

          // Cache in Firestore so future loads are instant
          try {
            await FirebaseFirestore.instance
                .collection('properties')
                .doc(widget.propertyId)
                .update({
              'latitude': foundLat,
              'longitude': foundLng,
            });
          } catch (firestoreError) {
            print('Could not cache resolved location to Firestore: $firestoreError');
          }
          return;
        }
      }

      // If specific geocoding failed, try town only
      if (town.isNotEmpty) {
        final townQuery = Uri.encodeComponent('$town, Cameroon');
        final townUri = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=$townQuery&format=json&limit=1',
        );

        final townResponse = await http.get(
          townUri,
          headers: {'User-Agent': 'Home237App/1.0'},
        );

        if (townResponse.statusCode == 200) {
          final results = jsonDecode(townResponse.body) as List<dynamic>;
          if (results.isNotEmpty) {
            final foundLat = double.parse(results[0]['lat'] as String);
            final foundLng = double.parse(results[0]['lon'] as String);
            final resolved = LatLng(foundLat, foundLng);

            if (mounted) {
              setState(() {
                _resolvedLatLng = resolved;
                _isResolvingLocation = false;
              });
            }

            // Cache in Firestore
            try {
              await FirebaseFirestore.instance
                  .collection('properties')
                  .doc(widget.propertyId)
                  .update({
                'latitude': foundLat,
                'longitude': foundLng,
              });
            } catch (_) {}
            return;
          }
        }

        // Fallback to town centre preset
        final fallbackCenter = _cityCentres[town];
        if (fallbackCenter != null) {
          if (mounted) {
            setState(() {
              _resolvedLatLng = fallbackCenter;
              _isResolvingLocation = false;
            });
          }
          return;
        }
      }
    } catch (e) {
      print('Error geocoding location: $e');
    }

    // Ultimate fallback: Yaoundé center or matched town center preset
    if (mounted) {
      setState(() {
        final town = (prop['town'] ?? '').toString().trim();
        _resolvedLatLng = _cityCentres[town] ?? const LatLng(3.8480, 11.5021);
        _isResolvingLocation = false;
      });
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
    // Viewers who change their mind mid-browse pick a role here
    // (home-seeker or agent) instead of hitting a generic sign-in wall.
    showRoleSignupSheet(context, action: action);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _showTourSuccessDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
            SizedBox(width: 8),
            Text('Request Sent', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Your tour request has been sent to the agent. '
          'Once the agent approves your request, you will receive an active Tour Pass (QR Code) on your dashboard to use during the visit.'
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
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

    final messageController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A5F).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.event_available, color: Color(0xFF1E3A5F), size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Schedule a Tour',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Request a physical viewing of this property. Tours on Home237 are completely free.',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[300] : Colors.grey[600],
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Optional Note/Preferred Time',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.grey[400] : Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: messageController,
                      maxLines: 3,
                      enabled: !isSubmitting,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'e.g. Saturday afternoon or Sunday 2PM...',
                        hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.grey[400]),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF2D2D2D) : Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: isDark ? Colors.white24 : Colors.grey[300]!),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                setStateDialog(() => isSubmitting = true);
                                try {
                                  final String escrowCode = const Uuid().v4();
                                  
                                  String tenantPhone = '';
                                  if (authService.userId != null) {
                                    final userDoc = await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(authService.userId)
                                        .get();
                                    if (userDoc.exists) {
                                      tenantPhone = userDoc.data()?['phone'] as String? ?? '';
                                    }
                                  }
                                  
                                  await FirebaseFirestore.instance.collection('tour_requests').add({
                                    'propertyId': widget.propertyId,
                                    'tenantId': authService.userId,
                                    'tenantName': authService.userName,
                                    'landlordId': _property!['landlordId'],
                                    'propertyTitle': _property!['title'] ?? 'Property',
                                    'status': 'pending',
                                    'escrowCode': escrowCode,
                                    'amount': 0,
                                    'platformFee': 0,
                                    'tenantPhone': tenantPhone ?? '',
                                    'message': messageController.text.trim(),
                                    'createdAt': DateTime.now(),
                                  });

                                  // Send notification to landlord
                                  final landlordId = _property!['landlordId'];
                                  if (landlordId != null) {
                                    await FirebaseFirestore.instance
                                        .collection('notifications')
                                        .doc(landlordId)
                                        .collection('items')
                                        .add({
                                      'title': 'New Tour Request',
                                      'message': '${authService.userName ?? 'A tenant'} has requested a tour for "${_property!['title'] ?? 'Property'}".',
                                      'type': 'tour_request',
                                      'read': false,
                                      'timestamp': FieldValue.serverTimestamp(),
                                    });
                                  }

                                  Navigator.pop(ctx); // Close confirmation dialog
                                  _showTourSuccessDialog();
                                  _loadTourStatus(); // Reload status in this screen
                                } catch (e) {
                                  setStateDialog(() => isSubmitting = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to request tour: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A5F),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'Request',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _cancelTourRequest() async {
    if (_tourRequestId == null) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Cancel Tour Request', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Are you sure you want to cancel this tour request?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red, 
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Yes, Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final docRef = FirebaseFirestore.instance.collection('tour_requests').doc(_tourRequestId!);
      final docSnapshot = await docRef.get();
      if (!docSnapshot.exists) return;
      final request = docSnapshot.data() as Map<String, dynamic>;

      final status = request['status'] ?? 'pending';
      if (status == 'escrowed') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please request a refund for this tour from the Tour Requests screen.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      await docRef.update({
        'status': 'cancelled',
        'cancelledAt': DateTime.now(),
      });

      final landlordId = request['landlordId'] as String?;
      if (landlordId != null) {
        await FirebaseFirestore.instance.collection('notifications').doc(landlordId).collection('items').add({
          'title': 'Tour Request Cancelled',
          'message': 'The tenant has cancelled the tour request for "${request['propertyTitle']}".',
          'type': 'tour_request',
          'read': false,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tour request cancelled successfully.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          _tourStatus = null;
          _tourRequestId = null;
          _escrowCode = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cancellation failed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _contactLandlord() async {
    if (!authService.isLoggedIn) {
      // Viewers must sign up before they can contact an agent.
      if (mounted) {
        showRoleSignupSheet(context, action: 'contact the agent');
      }
      return;
    }

    if (_property == null) return;

    final landlordId = _property!['landlordId'];
    if (landlordId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to contact agent: Missing contact information.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (landlordId == authService.userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This is your own property.'),
          backgroundColor: const Color(0xFF1E3A5F),
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
          recipientName: _property!['landlordName'] ?? 'Agent',
          propertyTitle: _property!['title'],
          initialMessage: 'Hi, I\'m interested in your property: ${_property!['title']}',
          initialImage: imageUrl,
          propertyId: widget.propertyId,
        ),
      ),
    );
  }

  Future<void> _submitRating() async {
    if (_myRating == 0) {
      _showSnackBar('Please select a star rating.');
      return;
    }
    if (!authService.isLoggedIn) {
      _showAuthPrompt('submit a rating');
      return;
    }

    setState(() => _isSubmittingReview = true);

    try {
      final String myUserId = authService.userId!;
      final String myUserName = authService.userName ?? 'Anonymous';

      // 1. Save rating document
      await FirebaseFirestore.instance
          .collection('properties')
          .doc(widget.propertyId)
          .collection('ratings')
          .doc(myUserId)
          .set({
        'rating': _myRating,
        'review': _reviewController.text.trim(),
        'userId': myUserId,
        'userName': myUserName,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 2. Fetch all ratings to calculate average
      final ratingsSnap = await FirebaseFirestore.instance
          .collection('properties')
          .doc(widget.propertyId)
          .collection('ratings')
          .get();

      double total = 0;
      int count = ratingsSnap.docs.length;
      for (var doc in ratingsSnap.docs) {
        total += (doc.data()['rating'] as num).toDouble();
      }
      double avg = count > 0 ? (total / count) : 0.0;

      // 3. Update parent property
      await FirebaseFirestore.instance
          .collection('properties')
          .doc(widget.propertyId)
          .update({
        'rating': avg,
        'ratingCount': count,
      });

      // 4. Reload local details so average shows correctly immediately
      await _loadPropertyDetails();

      _showSnackBar('Review submitted successfully!');
      setState(() {
        _myRating = 0;
        _reviewController.clear();
      });
    } catch (e) {
      _showSnackBar('Failed to submit review: $e');
    } finally {
      setState(() => _isSubmittingReview = false);
    }
  }

  Future<void> _deleteRating() async {
    if (!authService.isLoggedIn) return;

    setState(() => _isSubmittingReview = true);

    try {
      final String myUserId = authService.userId!;

      // 1. Delete rating document
      await FirebaseFirestore.instance
          .collection('properties')
          .doc(widget.propertyId)
          .collection('ratings')
          .doc(myUserId)
          .delete();

      // 2. Fetch all ratings to recalculate average
      final ratingsSnap = await FirebaseFirestore.instance
          .collection('properties')
          .doc(widget.propertyId)
          .collection('ratings')
          .get();

      double total = 0;
      int count = ratingsSnap.docs.length;
      for (var doc in ratingsSnap.docs) {
        total += (doc.data()['rating'] as num).toDouble();
      }
      double avg = count > 0 ? (total / count) : 0.0;

      // 3. Update parent property
      await FirebaseFirestore.instance
          .collection('properties')
          .doc(widget.propertyId)
          .update({
        'rating': avg,
        'ratingCount': count,
      });

      // 4. Reload details
      await _loadPropertyDetails();

      _showSnackBar('Review removed.');
    } catch (e) {
      _showSnackBar('Failed to remove review: $e');
    } finally {
      setState(() => _isSubmittingReview = false);
    }
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
              Padding(
                padding: const EdgeInsets.only(right: 8.0, top: 8.0),
                child: CircleAvatar(
                  backgroundColor: Colors.black26,
                  child: IconButton(
                    icon: const Icon(Icons.flag_outlined, color: Colors.white),
                    tooltip: 'Report this listing',
                    onPressed: _reportListing,
                  ),
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
                              pageBuilder: (context, _, _) =>
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
                                    if (loadingProgress == null) {
                                      return child;
                                    }
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
                                        color: const Color(0xFF1E3A5F),
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
                                color: Color(0xFF1E3A5F),
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
                          color: const Color(0xFF1E3A5F).withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: const Color(0xFF1E3A5F),
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
                                'In charge: ${_property!['landlordName']?.toString() ?? 'Agent'}',
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
                              if (_landlordRating != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.star_rounded,
                                        color: Color(0xFFF59E0B), size: 15),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${_landlordRating!.toStringAsFixed(1)} · $_landlordRatingCount review${_landlordRatingCount == 1 ? '' : 's'}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.grey[300]
                                            : const Color(0xFF475569),
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                const SizedBox(height: 4),
                                Text(
                                  'No reviews yet',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.grey[500]
                                        : Colors.grey[500],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        _landlordVerified
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981)
                                      .withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.verified,
                                        color: Color(0xFF10B981), size: 16),
                                    SizedBox(width: 4),
                                    Text(
                                      'Verified',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF10B981),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B)
                                      .withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.gpp_maybe_outlined,
                                        color: Color(0xFFB45309), size: 16),
                                    SizedBox(width: 4),
                                    Text(
                                      'Not verified',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFB45309),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
                                  const Color(0xFF1E3A5F).withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 20),
                            Container(
                              width: 56,
                              height: 56,
                              decoration: const BoxDecoration(
                                color: Color(0xFF1E3A5F),
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
                                color: Color(0xFF1E3A5F)),
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
                    if (_isResolvingLocation) {
                      return Container(
                        height: 260,
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
                              const SizedBox(
                                width: 32,
                                height: 32,
                                child: CircularProgressIndicator(
                                  color: Color(0xFF1E3A5F),
                                  strokeWidth: 3,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Locating property on map...',
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

                    if (_resolvedLatLng == null) {
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

                    final propertyLocation = _resolvedLatLng!;
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
                                onTap: (_, _) async {
                                  final uri = Uri.parse(
                                      'https://www.google.com/maps/search/?api=1&query=${propertyLocation.latitude},${propertyLocation.longitude}');
                                  try {
                                    // ignore: deprecated_member_use
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri,
                                          mode: LaunchMode.externalApplication);
                                    }
                                  } catch (_) {}
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
                                    Marker(
                                      point: propertyLocation,
                                      width: 56,
                                      height: 64,
                                      child: GestureDetector(
                                        onTap: () async {
                                          final uri = Uri.parse(
                                              'https://www.google.com/maps/search/?api=1&query=${propertyLocation.latitude},${propertyLocation.longitude}');
                                          try {
                                            // ignore: deprecated_member_use
                                            if (await canLaunchUrl(uri)) {
                                              await launchUrl(uri,
                                                  mode: LaunchMode.externalApplication);
                                            }
                                          } catch (_) {}
                                        },
                                        child: const _AnimatedPropertyPin(),
                                      ),
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
                                      'https://www.google.com/maps/search/?api=1&query=${propertyLocation.latitude},${propertyLocation.longitude}');
                                  try {
                                    // ignore: deprecated_member_use
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri,
                                          mode: LaunchMode.externalApplication);
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
                                          color: Color(0xFF1E3A5F)),
                                      SizedBox(width: 4),
                                      Text(
                                        'Open in Maps',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1E3A5F),
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
                                  '${propertyLocation.latitude.toStringAsFixed(5)}, ${propertyLocation.longitude.toStringAsFixed(5)}',
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



                  const SizedBox(height: 24),
                  Text(
                    'Ratings & Reviews',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('properties')
                        .doc(widget.propertyId)
                        .collection('ratings')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Text('Error loading reviews: ${snapshot.error}');
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = snapshot.data!.docs;
                      final bool hasReviews = docs.isNotEmpty;

                      // Check if current user already submitted a review
                      Map<String, dynamic>? myReviewData;
                      if (authService.isLoggedIn) {
                        for (var doc in docs) {
                          if (doc.id == authService.userId) {
                            myReviewData = doc.data() as Map<String, dynamic>?;
                            break;
                          }
                        }
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!hasReviews)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                'No reviews yet. Be the first to review this property!',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                final data = docs[index].data() as Map<String, dynamic>;
                                final reviewerName = data['userName'] ?? 'Anonymous';
                                final reviewerRating = data['rating'] ?? 0;
                                final reviewText = data['review'] ?? '';
                                final isMe = data['userId'] == authService.userId;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDark ? Colors.white12 : Colors.grey[200]!,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            isMe ? '$reviewerName (You)' : reviewerName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                                            ),
                                          ),
                                          Row(
                                            children: List.generate(5, (starIdx) {
                                              return Icon(
                                                Icons.star_rounded,
                                                size: 16,
                                                color: starIdx < reviewerRating
                                                    ? const Color(0xFFFBBF24)
                                                    : (isDark ? Colors.white24 : Colors.grey[300]),
                                              );
                                            }),
                                          ),
                                        ],
                                      ),
                                      if (reviewText.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          reviewText,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                                          ),
                                        ),
                                      ],
                                      if (isMe) ...[
                                        const SizedBox(height: 8),
                                        Align(
                                          alignment: Alignment.bottomRight,
                                          child: TextButton.icon(
                                            onPressed: _isSubmittingReview ? null : _deleteRating,
                                            icon: const Icon(Icons.delete_outline, size: 14, color: Colors.red),
                                            label: const Text(
                                              'Delete',
                                              style: TextStyle(color: Colors.red, fontSize: 12),
                                            ),
                                            style: TextButton.styleFrom(
                                              padding: EdgeInsets.zero,
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                          
                          // Write a Review Section
                          if (authService.isLoggedIn &&
                              authService.userId != _property!['landlordId'] &&
                              myReviewData == null) ...[
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 12),
                            Text(
                              'Rate this Property',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(5, (starIdx) {
                                return IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _myRating = starIdx + 1;
                                    });
                                  },
                                  icon: Icon(
                                    Icons.star_rounded,
                                    size: 36,
                                    color: starIdx < _myRating
                                        ? const Color(0xFFFBBF24)
                                        : (isDark ? Colors.white24 : Colors.grey[300]),
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _reviewController,
                              maxLines: 3,
                              enabled: !_isSubmittingReview,
                              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                              decoration: InputDecoration(
                                hintText: 'Share details of your experience with this property...',
                                hintStyle: TextStyle(
                                  color: isDark ? Colors.white30 : Colors.grey[400],
                                  fontSize: 14,
                                ),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF2D2D2D) : Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.all(12),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isSubmittingReview ? null : _submitRating,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E3A5F),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: _isSubmittingReview
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        'Submit Review',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                              ),
                            ),
                          ] else if (!authService.isLoggedIn) ...[
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 12),
                            Center(
                              child: TextButton(
                                onPressed: () {
                                  _showAuthPrompt('rate this property');
                                },
                                child: const Text(
                                  'Sign in to leave a review',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E3A5F),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
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
                child: _tourStatus == 'escrowed' || _tourStatus == 'approved'
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (_tourRequestId != null && _escrowCode != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TourPassDisplayScreen(
                                      tourRequestId: _tourRequestId!,
                                      escrowCode: _escrowCode!,
                                      propertyTitle: _property!['title']?.toString() ?? 'Property',
                                    ),
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              backgroundColor: const Color(0xFF10B981),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.qr_code, color: Colors.white, size: 18),
                            label: const Text('Show Pass', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            onPressed: _cancelTourRequest,
                            icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 14),
                            label: const Text('Cancel Tour', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 30),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ),
                      ],
                    )
                  : _tourStatus == 'pending'
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Your tour request is pending agent approval.'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                backgroundColor: Colors.orange.withOpacity(0.8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.hourglass_empty, color: Colors.white, size: 18),
                              label: const Text('Pending', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton.icon(
                              onPressed: _cancelTourRequest,
                              icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 14),
                              label: const Text('Cancel Request', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 30),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ),
                        ],
                      )
                    : OutlinedButton(
                        onPressed: _requestTour,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Color(0xFF1E3A5F)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text(
                          'Request Tour',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E3A5F)),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _contactLandlord,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF1E3A5F),
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
            Icon(icon, color: const Color(0xFF1E3A5F), size: 24),
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
                        color: Color(0xFF1E3A5F),
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
                color: const Color(0xFF1E3A5F),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color:
                        const Color(0xFF1E3A5F).withOpacity(0.5),
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
                _TrianglePainter(color: const Color(0xFF1E3A5F)),
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
