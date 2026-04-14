import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:http/http.dart' as http;
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
    'House',
    'Studio',
    'Condo',
    'Villa',
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
  List<String> _existingImages = []; // Track existing images when editing
  bool _isSubmitting = false;
  LatLng? _selectedLocation;
  bool _isGeocodingArea = false;

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

    // If user is premium, allow unlimited properties
    if (authService.isPremium) return;

    final userId = authService.userId;
    if (userId == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('properties')
          .where('landlordId', isEqualTo: userId)
          .get();

      if (snapshot.docs.length >= 3) {
        if (!mounted) return;
        _showLimitDialog();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error checking property limit: $e');
      }
    }
  }

  void _showLimitDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Listing Limit Reached'),
        content: const Text(
          'On the Free plan, you can only post up to 3 properties. Upgrade to Premium to post unlimited properties and reach more tenants!',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back
            },
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const PremiumSubscriptionScreen()),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
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
        setState(() => _tourVideo = video);
      }
    } catch (e) {
      _showSnackBar('Error picking video: $e', isError: true);
    }
  }

  Future<String?> _uploadTourVideo() async {
    if (_tourVideo == null) return _existingTourVideoUrl;
    final supabase = Supabase.instance.client;
    final bytes = await _tourVideo!.readAsBytes();
    final ext = _tourVideo!.name.split('.').last.toLowerCase();
    final filePath =
        '${authService.userId}/tour_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await supabase.storage.from('properties').uploadBinary(
      filePath,
      bytes,
      fileOptions: FileOptions(
        contentType: ext == 'mp4' ? 'video/mp4' : 'video/$ext',
        upsert: true,
      ),
    );
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
      // Read bytes (works on both web and mobile)
      final bytes = await _selectedImages[i].readAsBytes();

      // Unique path inside the 'properties' Supabase bucket
      final filePath =
          '${authService.userId}/property_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';

      await supabase.storage
          .from('properties')
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

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
        '⚠️ Tip: Adding a 360° interior video boosts your listing views!',
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
        if (tourVideoUrl != null) 'tourVideoUrl': tourVideoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.propertyId != null) {
        await FirebaseFirestore.instance
            .collection('properties')
            .doc(widget.propertyId)
            .update(propertyMap);
        _showSnackBar('Property updated successfully!');
      } else {
        // Add new fields for new property
        propertyMap.addAll({
          'landlordId': authService.userId ?? '',
          'landlordName': authService.userName ?? 'Landlord',
          'status': 'pending', // Requires admin approval
          'views': 0,
          'favorites': 0,
          'createdAt': FieldValue.serverTimestamp(),
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

  /// Geocodes [area + town] using Nominatim (OpenStreetMap, no API key)
  /// then flies the map to the result and places a pin.
  Future<void> _geocodeAndFly() async {
    final area = _areaController.text.trim();
    if (area.isEmpty && _selectedRegion == null) {
      _showSnackBar('Enter an area or select a town first', isError: true);
      return;
    }

    setState(() => _isGeocodingArea = true);

    try {
      // Build the most specific query: "Molyko, Buea, Cameroon"
      final parts = <String>[];
      if (area.isNotEmpty) parts.add(area);
      if (_selectedRegion != null) parts.add(_selectedRegion!);
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
          final lat = double.parse(results[0]['lat'] as String);
          final lng = double.parse(results[0]['lon'] as String);
          final found = LatLng(lat, lng);

          // Fly to the geocoded location and update the pin
          _mapKey.currentState?.flyTo(found, zoom: 16);
          setState(() => _selectedLocation = found);
          _showSnackBar('📍 Located: ${results[0]['display_name'].toString().split(',').take(2).join(',')}');
        } else {
          _showSnackBar('Could not find "$area". Try a more specific name.', isError: true);
        }
      } else {
        _showSnackBar('Geocoding failed. Check your internet.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', isError: true);
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
                  color: Color(0xFF3B82F6),
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
              value: _selectedRegion,
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
                // 🗺️ Fly map to the selected city immediately
                if (value != null && _cityCentres.containsKey(value)) {
                  _mapKey.currentState?.flyTo(_cityCentres[value]!, zoom: 14);
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
                  ),
                ),
                const SizedBox(width: 10),
                // Locate on Map button
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isGeocodingArea ? null : _geocodeAndFly,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
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
              'Tap the map to drop a pin, or use the Locate button above.',
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
                          ? const Color(0xFF3B82F6)
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
                          ? const Color(0xFF3B82F6).withValues(alpha: 0.1)
                          : isDark
                          ? const Color(0xFF374151)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF3B82F6)
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
                              color: Color(0xFF3B82F6),
                            ),
                          ),
                        Text(
                          amenity,
                          style: TextStyle(
                            fontSize: 13,
                            color: isSelected
                                ? const Color(0xFF3B82F6)
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
                const Icon(Icons.view_in_ar, color: Color(0xFF3B82F6), size: 20),
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
                    const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.25 : 0.08),
                    const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.15 : 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.tips_and_updates_outlined, size: 18, color: Color(0xFF3B82F6)),
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
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                      style: BorderStyle.solid,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.videocam_outlined, size: 40, color: const Color(0xFF3B82F6).withValues(alpha: 0.7)),
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
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFF3B82F6)),
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
