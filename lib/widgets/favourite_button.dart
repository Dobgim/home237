import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth_service.dart';

class FavouriteButton extends StatefulWidget {
  final String propertyId;
  final Map<String, dynamic> propertyData;
  final VoidCallback? onRequireAuth;

  const FavouriteButton({
    super.key,
    required this.propertyId,
    required this.propertyData,
    this.onRequireAuth,
  });

  @override
  State<FavouriteButton> createState() => _FavouriteButtonState();
}

class _FavouriteButtonState extends State<FavouriteButton> {
  bool _isFavourite = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkFavourite();
  }

  Future<void> _checkFavourite() async {
    if (authService.userId == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('favorites')
          .doc(authService.userId)
          .collection('properties')
          .doc(widget.propertyId)
          .get();
      if (mounted) setState(() => _isFavourite = doc.exists);
    } catch (_) {}
  }

  Future<void> _toggleFavourite() async {
    if (!authService.isLoggedIn) {
      if (widget.onRequireAuth != null) {
        widget.onRequireAuth!();
      }
      return;
    }
    setState(() => _isLoading = true);
    try {
      final ref = FirebaseFirestore.instance
          .collection('favorites')
          .doc(authService.userId)
          .collection('properties')
          .doc(widget.propertyId);
      if (_isFavourite) {
        await ref.delete();
        if (mounted) setState(() => _isFavourite = false);
      } else {
        await ref.set({'propertyId': widget.propertyId, 'addedAt': DateTime.now()});
        if (mounted) setState(() => _isFavourite = true);
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _isLoading ? null : _toggleFavourite,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 6,
            )
          ],
        ),
        child: _isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
              )
            : Icon(
                _isFavourite ? Icons.favorite : Icons.favorite_border,
                size: 18,
                color: _isFavourite ? Colors.red : Colors.grey[600],
              ),
      ),
    );
  }
}
