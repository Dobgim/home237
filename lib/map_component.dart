import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

/// A fully-featured Leaflet-style map widget.
///
/// Supports:
///  - Zoom +/− controls (top-right)
///  - "Locate Me" GPS button (bottom-right)
///  - Tap-to-pick a location when [isPicker] = true
///  - Smooth flyTo() camera animation
///  - Pulsing animated picker pin
///  - OpenStreetMap attribution (bottom)
///  - Optional dark tile layer
class MapComponent extends StatefulWidget {
  final List<Marker> markers;
  final bool isPicker;
  final Function(LatLng)? onLocationSelected;
  final LatLng? initialLocation;
  final bool showUserLocation;
  final bool showZoomControls;
  final bool showLocateButton;
  final bool useDarkTiles;

  const MapComponent({
    super.key,
    this.markers = const [],
    this.isPicker = false,
    this.onLocationSelected,
    this.initialLocation,
    this.showUserLocation = true,
    this.showZoomControls = true,
    this.showLocateButton = true,
    this.useDarkTiles = false,
  });

  @override
  State<MapComponent> createState() => MapComponentState();
}

class MapComponentState extends State<MapComponent>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  LatLng? _pickerLocation;
  LatLng _currentCenter = const LatLng(3.8480, 11.5021); // Yaoundé default
  bool _isLoading = true;
  bool _isLocating = false;

  // Fly-to animation
  late AnimationController _flyController;
  Animation<double>? _latAnim;
  Animation<double>? _lngAnim;
  Animation<double>? _zoomAnim;

  // Pulsing pin animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    // Fly-to controller
    _flyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    // Pulse animation for picker pin
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _pickerLocation = widget.initialLocation;
    if (widget.initialLocation != null) {
      _currentCenter = widget.initialLocation!;
    }

    if (!widget.showUserLocation) {
      _isLoading = false;
    } else {
      _determinePosition();
    }
  }

  @override
  void dispose() {
    _flyController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Smoothly fly the camera to [destination] at [zoom].
  void flyTo(LatLng destination, {double zoom = 15.0}) {
    final from = _mapController.camera.center;
    final fromZoom = _mapController.camera.zoom;

    _flyController.reset();

    _latAnim = Tween<double>(begin: from.latitude, end: destination.latitude)
        .animate(CurvedAnimation(
            parent: _flyController, curve: Curves.easeInOutCubic));
    _lngAnim = Tween<double>(begin: from.longitude, end: destination.longitude)
        .animate(CurvedAnimation(
            parent: _flyController, curve: Curves.easeInOutCubic));
    _zoomAnim = Tween<double>(begin: fromZoom, end: zoom).animate(
        CurvedAnimation(
            parent: _flyController, curve: Curves.easeInOutCubic));

    void listener() {
      if (_latAnim != null && _lngAnim != null && _zoomAnim != null) {
        _mapController.move(
          LatLng(_latAnim!.value, _lngAnim!.value),
          _zoomAnim!.value,
        );
      }
    }

    _flyController.addListener(listener);
    _flyController.forward().then((_) {
      _flyController.removeListener(listener);
    });

    if (widget.isPicker) {
      setState(() => _pickerLocation = destination);
      widget.onLocationSelected?.call(destination);
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<void> _determinePosition() async {
    if (!widget.showUserLocation) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() => _isLoading = false);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          if (widget.initialLocation == null) {
            _currentCenter = LatLng(position.latitude, position.longitude);
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error determining position: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _locateMe() async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final loc = LatLng(position.latitude, position.longitude);
      flyTo(loc, zoom: 16.0);
    } catch (e) {
      debugPrint('Locate me error: $e');
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _zoomIn() {
    final current = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, current + 1);
  }

  void _zoomOut() {
    final current = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, current - 1);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: const Color(0xFFE8F4F1),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF3B82F6)),
              SizedBox(height: 12),
              Text('Loading map…',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
            ],
          ),
        ),
      );
    }

    // Tile URL — use CartoDB Positron (clean Leaflet-style) or OSM
    const cartoLightUrl =
        'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';
    const cartoDarkUrl =
        'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';

    final tileUrl =
        widget.useDarkTiles ? cartoDarkUrl : cartoLightUrl;

    return Stack(
      children: [
        // ── The map itself ──────────────────────────────────────────────
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentCenter,
            initialZoom: 14,
            minZoom: 3,
            maxZoom: 19,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
            onTap: (tapPosition, point) {
              if (widget.isPicker) {
                setState(() => _pickerLocation = point);
                widget.onLocationSelected?.call(point);
              }
            },
          ),
          children: [
            // Tile layer
            TileLayer(
              urlTemplate: tileUrl,
              subdomains: const ['a', 'b', 'c'],
              userAgentPackageName: 'com.home237.app',
              maxZoom: 19,
              // Faster tile loading with keep-alive
              tileProvider: NetworkTileProvider(),
            ),

            // Markers layer from external callers
            MarkerLayer(markers: widget.markers),

            // Picker pin (animated pulsing)
            if (widget.isPicker && _pickerLocation != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _pickerLocation!,
                    width: 60,
                    height: 70,
                    child: _PulsingPin(animation: _pulseAnim),
                  ),
                ],
              ),

            // ── Attribution (required by OpenStreetMap) ────────────────
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution(
                  widget.useDarkTiles
                      ? '© CartoDB © OpenStreetMap contributors'
                      : '© OpenStreetMap contributors',
                  onTap: null,
                ),
              ],
            ),
          ],
        ),

        // ── Zoom Controls (top-right, Leaflet-style) ────────────────────
        if (widget.showZoomControls)
          Positioned(
            top: 12,
            right: 12,
            child: _LeafletZoomControls(
              onZoomIn: _zoomIn,
              onZoomOut: _zoomOut,
            ),
          ),

        // ── Locate Me Button (bottom-right) ─────────────────────────────
        if (widget.showLocateButton)
          Positioned(
            bottom: 36,
            right: 12,
            child: _LeafletControlButton(
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

        // ── Picker instruction banner ────────────────────────────────────
        if (widget.isPicker)
          Positioned(
            top: 12,
            left: 12,
            right: 60,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.touch_app,
                      size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Tap map to drop pin',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ── Animated pulsing pin widget ──────────────────────────────────────────────

class _PulsingPin extends StatelessWidget {
  final Animation<double> animation;
  const _PulsingPin({required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.scale(
              scale: animation.value,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withOpacity(0.5),
                      blurRadius: 12,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(Icons.location_on,
                    color: Colors.white, size: 22),
              ),
            ),
            // Pin tail
            CustomPaint(
              size: const Size(12, 8),
              painter: _TrianglePainter(color: const Color(0xFF3B82F6)),
            ),
          ],
        );
      },
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  const _TrianglePainter({required this.color});

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
  bool shouldRepaint(_TrianglePainter old) => old.color != color;
}

// ── Leaflet-style zoom control widget ────────────────────────────────────────

class _LeafletZoomControls extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const _LeafletZoomControls({
    required this.onZoomIn,
    required this.onZoomOut,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ZoomButton(
            icon: Icons.add,
            onTap: onZoomIn,
            isTop: true,
          ),
          Container(height: 1, color: Colors.grey[200]),
          _ZoomButton(
            icon: Icons.remove,
            onTap: onZoomOut,
            isTop: false,
          ),
        ],
      ),
    );
  }
}

class _ZoomButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isTop;

  const _ZoomButton({
    required this.icon,
    required this.onTap,
    required this.isTop,
  });

  @override
  State<_ZoomButton> createState() => _ZoomButtonState();
}

class _ZoomButtonState extends State<_ZoomButton> {
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

// ── Generic Leaflet-style control button ─────────────────────────────────────

class _LeafletControlButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;
  final String tooltip;

  const _LeafletControlButton({
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
