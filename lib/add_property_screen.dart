import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart' as geo;
import 'auth_service.dart';
import 'map_component.dart';
import 'package:latlong2/latlong.dart';
import 'premium_subscription_screen.dart';


class AddPropertyScreen extends StatefulWidget {
  final String? propertyId;
  final Map<String, dynamic>? propertyData;

  const AddPropertyScreen({
    super.key,
    this.propertyId,
    this.propertyData,
  });

  @override
  State<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends State<AddPropertyScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  // Controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _areaController = TextEditingController(); // Area/Quarter within town
  final _locationController = TextEditingController();
  final _bedsController = TextEditingController();
  final _bathsController = TextEditingController();
  final _sqftController = TextEditingController(); // hidden, kept for backward compat


  String _selectedType = 'Apartment';
  final List<String> _propertyTypes = [
    'Apartment',
    'Hotel',
    'Studio',
    'Office',
    'Land',
    'Room',
  ];

  String? _selectedRegion;
  final List<String> _regions = [
    'Buea',
    'Douala',
    'Yaoundé',
    'Limbe',
    'Kribi',
    'Bafoussam',
    'Bamenda',
    'Garoua',
  ];

  final List<String> _selectedAmenities = [];
  final List<String> _availableAmenities = [
    'WiFi',
    'Parking',
    'AC',
    'Heating',
    'Furnished',
    'Pet Friendly',
    'Balcony',
    'Garden',
    'Pool',
    'Gym',
    'Security',
    'Elevator',
  ];

  List<XFile> _selectedImages = [];
  final List<String> _existingImages = []; // Track existing images when editing
  bool _isSubmitting = false;
  LatLng? _selectedLocation;
  bool _isGeocodingArea = false;
  Timer? _geocodeDebounce;

  // 360° tour video
  XFile? _tourVideo;
  String? _existingTourVideoUrl;

  /// GlobalKey so we can call mapKey.currentState?.flyTo(...)
  final GlobalKey<MapComponentState> _mapKey = GlobalKey<MapComponentState>();

  /// Known city centres for instant map jumps (no network call needed)
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
    _checkLimit();
    if (widget.propertyData != null) {
      final data = widget.propertyData!;
      _titleController.text = data['title'] ?? '';
      _descriptionController.text = data['description'] ?? '';
      
      // Price might have ' FCFA' suffix
      String priceStr = data['price'] ?? '';
      if (priceStr.endsWith(' FCFA')) {
        priceStr = priceStr.substring(0, priceStr.length - ' FCFA'.length);
      }
      _priceController.text = priceStr;
      
      _areaController.text = data['area'] ?? '';
      _locationController.text = data['location'] ?? '';
      _bedsController.text = (data['beds'] ?? '').toString();
      _bathsController.text = (data['baths'] ?? '').toString();
      _sqftController.text = (data['sqft'] ?? '').toString();
      _selectedType = data['type'] ?? 'Apartment';
      _selectedRegion = data['town'];
      
      if (data['amenities'] != null) {
        _selectedAmenities.addAll(List<String>.from(data['amenities']));
      }
      
      if (data['images'] != null) {
        _existingImages.addAll(List<String>.from(data['images']));
      }

      if (data['tourVideoUrl'] != null) {
        _existingTourVideoUrl = data['tourVideoUrl'] as String;
      }
      
      if (data['latitude'] != null && data['longitude'] != null) {
        _selectedLocation = LatLng(
          (data['latitude'] as num).toDouble(),
          (data['longitude'] as num).toDouble(),
        );
      }
    }
  }

  Future<void> _checkLimit() async {
    // If editing an existing property, don't check limit
    if (widget.propertyId != null) return;

    final userId = authService.userId;
    if (userId == null) return;

    try {
      final db = FirebaseFirestore.instance;

      // Landlord's existing listings…
      final snapshot = await db
          .collection('properties')
          .where('landlordId', isEqualTo: userId)
          .get();

      // …and their current subscription plan (read fresh from Firestore).
      final userDoc = await db.collection('users').doc(userId).get();
      final data = userDoc.data() ?? {};
      final isPremium = (data['subscriptionStatus'] ?? 'free') == 'premium';
      final isAnnual = (data['subscriptionPlan'] ?? '').toString() == 'annual';
      final isCompany = (data['accountType'] ?? 'agent') == 'company';

      if (isCompany) {
        // Company: 5 free listings; Premium (Company Unlimited) = no cap.
        // Posting permission itself is gated by Tier 1 in the dashboard.
        if (!isPremium && snapshot.docs.length >= 5 && mounted) {
          _showLimitDialog(isPremium: false, isAnnual: false, isCompany: true);
        }
        return;
      }

      if (!isPremium) {
        // Free plan: 1 property total.
        if (snapshot.docs.length >= 1 && mounted) {
          _showLimitDialog(isPremium: false, isAnnual: false);
        }
        return;
      }

      if (isAnnual) {
        // Annual plan: 3 NEW properties per calendar month (resets monthly).
        final now = DateTime.now();
        final monthStart = DateTime(now.year, now.month, 1);
        int postedThisMonth = 0;
        for (final doc in snapshot.docs) {
          final created = doc.data()['createdAt'];
          if (created is Timestamp && !created.toDate().isBefore(monthStart)) {
            postedThisMonth++;
          }
        }
        if (postedThisMonth >= 3 && mounted) {
          _showLimitDialog(isPremium: true, isAnnual: true);
        }
      } else {
        // Monthly plan: 3 properties total.
        if (snapshot.docs.length >= 3 && mounted) {
          _showLimitDialog(isPremium: true, isAnnual: false);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error checking property limit: $e');
      }
    }
  }

  void _showLimitDialog(
      {required bool isPremium,
      required bool isAnnual,
      bool isCompany = false}) {
    final String title =
        isAnnual ? 'Monthly Limit Reached' : 'Listing Limit Reached';
    final String message;
    if (isCompany) {
      // Company free tier: 5 listings, then upgrade to Company Unlimited.
      message =
          'Your agency has used all 5 free listings. Upgrade to Company '
          'Unlimited to post as many properties as you like!';
    } else if (!isPremium) {
      message =
          'On the Free plan you can only post 1 property. Upgrade to Premium to '
          'post up to 3 — or choose the Annual plan to post 3 new properties every month!';
    } else if (isAnnual) {
      message =
          'You\'ve reached your limit of 3 new properties for this month. '
          'Your allowance resets automatically at the start of next month.';
    } else {
      message =
          'On the Monthly Premium plan you can post up to 3 properties. '
          'Switch to the Annual plan to post 3 new properties every month!';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back
            },
            child: const Text('Maybe Later'),
          ),
          // Free users can upgrade straight away. (Annual users just wait for the
          // monthly reset; monthly users are informed about the Annual upgrade.)
          if (!isPremium)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const PremiumSubscriptionScreen()),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A5F)),
              child: const Text('Upgrade Now', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  Future<void> _pickTourVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 10),
      );
      if (video != null) {
        final sizeInBytes = await video.length();
        final sizeInMB = sizeInBytes / (1024 * 1024);
        if (sizeInMB > 50) {
          _showSnackBar(
            'The selected video is too large (${sizeInMB.toStringAsFixed(1)} MB). '
            'Please select a video file under 50 MB.',
            isError: true,
          );
          return;
        }
        setState(() => _tourVideo = video);
      }
    } catch (e) {
      _showSnackBar('Error picking video: $e', isError: true);
    }
  }

  Future<String?> _uploadTourVideo() async {
    if (_tourVideo == null) return _existingTourVideoUrl;
    
    // Failsafe size check before upload
    final sizeInBytes = await _tourVideo!.length();
    final sizeInMB = sizeInBytes / (1024 * 1024);
    if (sizeInMB > 50) {
      throw Exception(
        'The walkthrough video is too large (${sizeInMB.toStringAsFixed(1)} MB). '
        'Please select a video file under 50 MB.'
      );
    }

    final supabase = Supabase.instance.client;
    final ext = _tourVideo!.name.split('.').last.toLowerCase();
    final filePath =
        '${authService.userId}/tour_${DateTime.now().millisecondsSinceEpoch}.$ext';
        
    final fileOptions = FileOptions(
      contentType: ext == 'mp4' ? 'video/mp4' : 'video/$ext',
      upsert: true,
    );

    if (kIsWeb) {
      final bytes = await _tourVideo!.readAsBytes();
      await supabase.storage.from('properties').uploadBinary(
        filePath,
        bytes,
        fileOptions: fileOptions,
      );
    } else {
      await supabase.storage.from('properties').upload(
        filePath,
        File(_tourVideo!.path),
        fileOptions: fileOptions,
      );
    }
    return supabase.storage.from('properties').getPublicUrl(filePath);
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images);
          if (_selectedImages.length > 10) {
            _selectedImages = _selectedImages.sublist(0, 10);
          }
        });
      }
    } catch (e) {
      _showSnackBar('Error picking images: $e', isError: true);
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingImages.removeAt(index);
    });
  }

  Future<List<String>> _uploadImages() async {
    final List<String> imageUrls = [];
    final supabase = Supabase.instance.client;

    for (int i = 0; i < _selectedImages.length; i++) {
      // Unique path inside the 'properties' Supabase bucket
      final filePath =
          '${authService.userId}/property_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';

      final fileOptions = const FileOptions(
        contentType: 'image/jpeg',
        upsert: true,
      );

      if (kIsWeb) {
        final bytes = await _selectedImages[i].readAsBytes();
        await supabase.storage
            .from('properties')
            .uploadBinary(
              filePath,
              bytes,
              fileOptions: fileOptions,
            );
      } else {
        await supabase.storage
            .from('properties')
            .upload(
              filePath,
              File(_selectedImages[i].path),
              fileOptions: fileOptions,
            );
      }

      final url =
          supabase.storage.from('properties').getPublicUrl(filePath);
      imageUrls.add(url);
    }

    return imageUrls;
  }

  Future<void> _submitProperty() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedImages.isEmpty && _existingImages.isEmpty) {
      _showSnackBar('Please add at least one image', isError: true);
      return;
    }

    // Soft warning if no 360° video
    if (_tourVideo == null && _existingTourVideoUrl == null) {
      _showSnackBar(
        'Tip: Adding a 360° interior video boosts your listing views!',
        isError: false,
      );
    }

    setState(() => _isSubmitting = true);

    try {
      // Upload images
      final imageUrls = await _uploadImages();

      if (imageUrls.isEmpty && _existingImages.isEmpty) {
        _showSnackBar('No images were uploaded. Please try again.', isError: true);
        setState(() => _isSubmitting = false);
        return;
      }

      // Upload 360° video (if any)
      final tourVideoUrl = await _uploadTourVideo();

      // Create/Update property document
      final propertyMap = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': '${_priceController.text.trim()} FCFA',
        'town': _selectedRegion,
        'area': _areaController.text.trim(),
        'location': '${_areaController.text.trim()}, $_selectedRegion',
        'latitude': _selectedLocation?.latitude,
        'longitude': _selectedLocation?.longitude,
        'type': _selectedType,
        'beds': _bedsController.text.trim(),
        'baths': _bathsController.text.trim(),
        'sqft': _sqftController.text.trim(),
        'amenities': _selectedAmenities,
        'images': [..._existingImages, ...imageUrls],
        'tourVideoUrl': ?tourVideoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.propertyId != null) {
        await FirebaseFirestore.instance
            .collection('properties')
            .doc(widget.propertyId)
            .update(propertyMap);
        _showSnackBar('Property updated successfully!');
      } else {
        // Stamp the owner's current verification status onto the listing so
        // browse cards can show a trust badge without reading a user doc per card.
        // Propagation on admin approve/reject keeps existing listings in sync.
        bool landlordVerified = false;
        try {
          final ownerId = authService.userId;
          if (ownerId != null) {
            final ownerDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(ownerId)
                .get();
            landlordVerified = ownerDoc.data()?['isVerified'] == true;
          }
        } catch (_) {}

        // Add new fields for new property
        propertyMap.addAll({
          'landlordId': authService.userId ?? '',
          'landlordName': authService.userName ?? 'Agent',
          'landlordVerified': landlordVerified, // Denormalized; synced on approve/reject
          'status': 'pending', // Requires admin approval
          'isLandlordPremium': authService.isPremium, // Stamped at creation; updated on subscription change
          'views': 0,
          'favorites': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'lastConfirmedAt': FieldValue.serverTimestamp(),
        });
        await FirebaseFirestore.instance.collection('properties').add(propertyMap);
        _showSnackBar('Property submitted for admin approval!');
      }

      if (!mounted) return;
      _showSnackBar('Property submitted for admin approval!');
      Navigator.pop(context, true); // Return true to indicate success
    } catch (e) {
      if (!mounted) return;
      // Show the real Supabase error
      String errorMsg = e.toString();
      if (errorMsg.contains('bucket_not_found') || errorMsg.contains('The resource was not found')) {
        errorMsg = 'Upload failed: Supabase bucket not found. Please ensure the "properties" bucket exists and is set to Public.';
      } else if (errorMsg.contains('Unauthorized') || errorMsg.contains('permission denied')) {
        errorMsg = 'Upload failed: Supabase permission denied. Please ensure the RLS policies permit inserts for authenticated users.';
      }
      _showSnackBar(errorMsg, isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  /// Builds the most specific geocoding query from the area + town fields,
  /// e.g. "Molyko, Buea, Cameroon". Returns null if there's nothing to search.
  String? _buildLocationQuery() {
    final area = _areaController.text.trim();
    final parts = <String>[];
    if (area.isNotEmpty) parts.add(area);
    if (_selectedRegion != null) parts.add(_selectedRegion!);
    if (parts.isEmpty) return null;
    parts.add('Cameroon');
    return parts.join(', ');
  }

  /// Resolves [query] to coordinates. Tries the on-device geocoder first
  /// (Google on Android, Apple on iOS — the best coverage for places that show
  /// on Google Maps), then falls back to OpenStreetMap's Nominatim (which also
  /// covers web, where the native geocoder isn't available).
  Future<LatLng?> _geocodeQuery(String query) async {
    // 1. Native platform geocoder (Google/Apple). Not available on web.
    if (!kIsWeb) {
      try {
        final locations = await geo.locationFromAddress(query);
        if (locations.isNotEmpty) {
          return LatLng(locations.first.latitude, locations.first.longitude);
        }
      } catch (_) {
        // Fall through to Nominatim.
      }
    }

    // 2. Nominatim fallback, biased to Cameroon (countrycodes=cm) for accuracy.
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query)}&format=json&limit=1&countrycodes=cm',
      );
      final response = await http.get(
        uri,
        headers: {'User-Agent': 'Home237App/1.0'},
      );
      if (response.statusCode == 200) {
        final results = jsonDecode(response.body) as List<dynamic>;
        if (results.isNotEmpty) {
          return LatLng(
            double.parse(results[0]['lat'] as String),
            double.parse(results[0]['lon'] as String),
          );
        }
      }
    } catch (_) {
      // Ignore — caller treats a null result as "not found".
    }
    return null;
  }

  /// Auto-geocodes (debounced) as the landlord types the area, so the map
  /// "directly picks up" the location without needing to tap Locate.
  void _onAreaChanged(String _) {
    _geocodeDebounce?.cancel();
    _geocodeDebounce = Timer(const Duration(milliseconds: 900), () {
      if (_areaController.text.trim().length >= 3) {
        _geocodeAndFly(silent: true);
      }
    });
  }

  /// Geocodes the area + town and flies the map to it, dropping a pin.
  /// When [silent] is true (auto-trigger while typing) it stays quiet on
  /// failure; the manual Locate button surfaces errors.
  Future<void> _geocodeAndFly({bool silent = false}) async {
    final query = _buildLocationQuery();
    if (query == null) {
      if (!silent) {
        _showSnackBar('Enter an area or select a town first', isError: true);
      }
      return;
    }

    setState(() => _isGeocodingArea = true);
    try {
      final found = await _geocodeQuery(query);
      if (found != null) {
        // Fly to the geocoded location and update the pin.
        _mapKey.currentState?.flyTo(found, zoom: 16);
        setState(() => _selectedLocation = found);
        if (!silent) _showSnackBar('📍 Location pinned on the map');
      } else if (!silent) {
        _showSnackBar(
          'Could not find that location. Try a more specific name, or tap the map.',
          isError: true,
        );
      }
    } catch (e) {
      if (!silent) _showSnackBar('Error: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isGeocodingArea = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Add New Property'),
        actions: [
          if (_isSubmitting)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _submitProperty,
              child: const Text(
                'POST',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F),
                ),
              ),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Form(
            key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // --- New Location Section at Top ---
            Text(
              'Location Details',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            
            // Town Selection
            DropdownButtonFormField<String>(
              initialValue: _selectedRegion,
              decoration: InputDecoration(
                labelText: 'Town',
                hintText: 'Select Town',
                filled: true,
                fillColor: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              items: _regions.map((region) {
                return DropdownMenuItem(
                  value: region,
                  child: Text(region),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedRegion = value);
                // 🗺️ Fly to the city centre instantly for feedback…
                if (value != null && _cityCentres.containsKey(value)) {
                  _mapKey.currentState?.flyTo(_cityCentres[value]!, zoom: 14);
                }
                // …then refine to the exact area if one is already typed.
                if (_areaController.text.trim().length >= 3) {
                  _geocodeAndFly(silent: true);
                }
              },
              validator: (v) => v == null ? 'Please select a town' : null,
              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            ),

            const SizedBox(height: 16),

            // Area/Quarter + locate button
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _areaController,
                    label: 'Area / Quarter',
                    hint: 'e.g., Molyko, Bastos, Akwa',
                    validator: (v) => v!.isEmpty ? 'Please specify the area' : null,
                    isDark: isDark,
                    onChanged: _onAreaChanged,
                    onFieldSubmitted: (_) => _geocodeAndFly(),
                    textInputAction: TextInputAction.search,
                  ),
                ),
                const SizedBox(width: 10),
                // Locate on Map button
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isGeocodingArea ? null : _geocodeAndFly,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A5F),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    icon: _isGeocodingArea
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.my_location, size: 18),
                    label: const Text('Locate',
                        style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),

            // Property Images
            Text(
              'Property Images',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),

            if (_selectedImages.isEmpty && _existingImages.isEmpty)
              GestureDetector(
                onTap: _pickImages,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                      style: BorderStyle.solid,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate,
                        size: 64,
                        color: isDark ? Colors.grey[500] : Colors.grey[400],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tap to add images',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Up to 10 images',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[500] : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                children: [
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _existingImages.length + _selectedImages.length + 1,
                      itemBuilder: (context, index) {
                        if (index == _existingImages.length + _selectedImages.length) {
                          return GestureDetector(
                            onTap: (_existingImages.length + _selectedImages.length) < 10 ? _pickImages : null,
                            child: Container(
                              width: 120,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: Icon(
                                Icons.add,
                                size: 32,
                                color: isDark ? Colors.grey[500] : Colors.grey[400],
                              ),
                            ),
                          );
                        }

                        // Check if it's an existing image
                        if (index < _existingImages.length) {
                          return Stack(
                            children: [
                              Container(
                                width: 120,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  image: DecorationImage(
                                    image: NetworkImage(_existingImages[index]),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 12,
                                child: GestureDetector(
                                  onTap: () => _removeExistingImage(index),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }

                        // It's a newly selected image
                        final selectedIndex = index - _existingImages.length;
                        return Stack(
                          children: [
                            Container(
                              width: 120,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                image: DecorationImage(
                                  image: kIsWeb 
                                    ? NetworkImage(_selectedImages[selectedIndex].path)
                                    : FileImage(File(_selectedImages[selectedIndex].path)) as ImageProvider,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 12,
                              child: GestureDetector(
                                onTap: () => _removeImage(selectedIndex),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_existingImages.length + _selectedImages.length}/10 images',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[500] : Colors.grey[500],
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 24),

            // Title
            _buildTextField(
              controller: _titleController,
              label: 'Property Title',
              hint: 'e.g., Modern 2BR Apartment',
              validator: (v) => v!.isEmpty ? 'Required' : null,
              isDark: isDark,
            ),

            const SizedBox(height: 16),

            // Description
            _buildTextField(
              controller: _descriptionController,
              label: 'Description',
              hint: 'Describe your property...',
              maxLines: 4,
              validator: (v) => v!.isEmpty ? 'Required' : null,
              isDark: isDark,
            ),

            const SizedBox(height: 16),

            // Price
            _buildTextField(
              controller: _priceController,
              label: 'Monthly Rent (FCFA)',
              hint: '2500',
              keyboardType: TextInputType.number,
              validator: (v) => v!.isEmpty ? 'Required' : null,
              isDark: isDark,
            ),

            const SizedBox(height: 16),

            const SizedBox(height: 16),

            // Map Selection
            Text(
              'Pin Exact Location',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'The map pins your location automatically as you type the area. '
              'You can also tap the map to fine-tune the exact spot.',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey[500] : Colors.grey[500],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: MapComponent(
                  key: _mapKey,
                  isPicker: true,
                  onLocationSelected: (location) {
                    setState(() => _selectedLocation = location);
                  },
                ),
              ),
            ),
            if (_selectedLocation != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Selected: ${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green,
                  ),
                ),
              ),

            const SizedBox(height: 16),


            // Property Type
            Text(
              'Property Type',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _propertyTypes.map((type) {
                final isSelected = _selectedType == type;
                return GestureDetector(
                  onTap: () => setState(() => _selectedType = type),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF1E3A5F)
                          : isDark
                          ? const Color(0xFF374151)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      type,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected
                            ? Colors.white
                            : isDark
                            ? Colors.grey[300]
                            : Colors.grey[700],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Beds and Baths
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _bedsController,
                    label: 'Beds',
                    hint: '2',
                    keyboardType: TextInputType.number,
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _bathsController,
                    label: 'Baths',
                    hint: '1',
                    keyboardType: TextInputType.number,
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                    isDark: isDark,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Amenities
            Text(
              'Amenities',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableAmenities.map((amenity) {
                final isSelected = _selectedAmenities.contains(amenity);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedAmenities.remove(amenity);
                      } else {
                        _selectedAmenities.add(amenity);
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF1E3A5F).withValues(alpha: 0.1)
                          : isDark
                          ? const Color(0xFF374151)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF1E3A5F)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSelected)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.check_circle,
                              size: 16,
                              color: Color(0xFF1E3A5F),
                            ),
                          ),
                        Text(
                          amenity,
                          style: TextStyle(
                            fontSize: 13,
                            color: isSelected
                                ? const Color(0xFF1E3A5F)
                                : isDark
                                ? Colors.grey[300]
                                : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 32),

            // ── 360° Interior Tour ──
            const Divider(),
            const SizedBox(height: 20),

            // Header
            Row(
              children: [
                const Icon(Icons.view_in_ar, color: Color(0xFF1E3A5F), size: 20),
                const SizedBox(width: 8),
                Text(
                  '360° Interior Tour',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Recommended',
                    style: TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Info banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1E3A5F).withValues(alpha: isDark ? 0.25 : 0.08),
                    const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.15 : 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF1E3A5F).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.tips_and_updates_outlined, size: 18, color: Color(0xFF1E3A5F)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Record a walkthrough of every room with your phone camera so tenants can virtually tour the full interior before visiting. Properties with a 360° tour get 3× more interest!',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: isDark ? Colors.white70 : const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Video picker UI
            if (_tourVideo == null && _existingTourVideoUrl == null)
              GestureDetector(
                onTap: _pickTourVideo,
                child: Container(
                  height: 110,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF1E3A5F).withValues(alpha: 0.4),
                      style: BorderStyle.solid,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.videocam_outlined, size: 40, color: const Color(0xFF1E3A5F).withValues(alpha: 0.7)),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to add interior walkthrough video',
                        style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500,
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text('MP4 · MOV · up to 10 min',
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[500] : Colors.grey[500])),
                    ],
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _tourVideo != null
                                ? _tourVideo!.name
                                : '360° tour video uploaded',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _tourVideo != null ? 'Ready to upload' : 'Existing video',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF10B981)),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _pickTourVideo,
                      icon: const Icon(Icons.swap_horiz, size: 16),
                      label: const Text('Replace', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFF1E3A5F)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: Colors.red),
                      onPressed: () => setState(() {
                        _tourVideo = null;
                        _existingTourVideoUrl = null;
                      }),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 40),
          ],
        ),
      ),
      ),
    ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isDark,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    void Function(String)? onFieldSubmitted,
    TextInputAction? textInputAction,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400]),
            filled: true,
            fillColor: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
          validator: validator,
        ),
      ],
    );
  }

  @override
  void dispose() {
    _geocodeDebounce?.cancel();
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _areaController.dispose();
    _locationController.dispose();
    _bedsController.dispose();
    _bathsController.dispose();
    _sqftController.dispose();
    super.dispose();
  }
}
