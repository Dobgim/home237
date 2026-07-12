import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';

class ReputationRatingDialog extends StatefulWidget {
  final String leaseId;
  final String rateeId;
  final String rateeName;
  final String role; // 'tenant_to_landlord' or 'landlord_to_tenant'

  const ReputationRatingDialog({
    super.key,
    required this.leaseId,
    required this.rateeId,
    required this.rateeName,
    required this.role,
  });

  @override
  State<ReputationRatingDialog> createState() => _ReputationRatingDialogState();
}

class _ReputationRatingDialogState extends State<ReputationRatingDialog> {
  int _param1 = 5; // Tenant: Professionalism | Landlord: Punctuality
  int _param2 = 5; // Tenant: Responsiveness  | Landlord: Cleanliness
  int _param3 = 5; // Tenant: Condition       | Landlord: Cooperation
  final TextEditingController _reviewController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submitRating() async {
    setState(() => _isSubmitting = true);
    try {
      final double averageRating = (_param1 + _param2 + _param3) / 3.0;

      // 1. Write the rating record to Firestore
      await FirebaseFirestore.instance.collection('reputation_ratings').add({
        'leaseId': widget.leaseId,
        'raterId': authService.userId,
        'rateeId': widget.rateeId,
        'rating': averageRating,
        'reviewText': _reviewController.text.trim(),
        'role': widget.role,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Fetch all ratings for the ratee to recalculate their average reputation score
      final ratingsSnap = await FirebaseFirestore.instance
          .collection('reputation_ratings')
          .where('rateeId', isEqualTo: widget.rateeId)
          .get();

      double total = 0;
      int count = ratingsSnap.docs.length;
      for (var doc in ratingsSnap.docs) {
        total += (doc.data()['rating'] as num).toDouble();
      }
      final double finalScore = count > 0 ? (total / count) : 5.0;

      // 3. Update the ratee's profile with their updated reputation score
      await FirebaseFirestore.instance.collection('users').doc(widget.rateeId).update({
        'reputationScore': finalScore,
        'trustRating': finalScore,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Thank you! Submitted feedback for ${widget.rateeName}.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit rating: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTenantRater = widget.role == 'tenant_to_landlord';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.shield_outlined, color: Color(0xFF0EA5E9), size: 28),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Rate ${widget.rateeName}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your review feeds into Home237\'s trust network, maintaining market security.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),

            // Param 1
            _buildRatingRow(
              isTenantRater ? 'Agent Professionalism' : 'Tenant Punctuality',
              _param1,
              (val) => setState(() => _param1 = val),
            ),
            const SizedBox(height: 12),

            // Param 2
            _buildRatingRow(
              isTenantRater ? 'Communication & Speed' : 'Cleanliness',
              _param2,
              (val) => setState(() => _param2 = val),
            ),
            const SizedBox(height: 12),

            // Param 3
            _buildRatingRow(
              isTenantRater ? 'Property Maintenance' : 'Rule Compliance',
              _param3,
              (val) => setState(() => _param3 = val),
            ),
            const SizedBox(height: 16),

            const Text('Written Review (Optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: _reviewController,
              decoration: const InputDecoration(
                hintText: 'Share details of your tenancy experience...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitRating,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0EA5E9),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _isSubmitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Submit Rating', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildRatingRow(String label, int value, ValueChanged<int> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        Row(
          children: List.generate(5, (index) {
            final starVal = index + 1;
            return GestureDetector(
              onTap: () => onChanged(starVal),
              child: Icon(
                Icons.star,
                color: starVal <= value ? const Color(0xFFF59E0B) : Colors.grey[300],
                size: 24,
              ),
            );
          }),
        ),
      ],
    );
  }
}
