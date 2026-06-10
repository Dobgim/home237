/// A lightweight singleton that remembers which property a guest was
/// looking at when they hit the auth wall.
///
/// Usage:
///   // Before pushing SignInScreen:
///   PendingPropertyService.instance.set(id, data, action: 'contact');
///
///   // After successful login in SignInScreen / SignUpScreen:
///   final pending = PendingPropertyService.instance.consume();
///   if (pending != null) push PropertyDetailsScreen with pending data
class PendingPropertyService {
  PendingPropertyService._();
  static final instance = PendingPropertyService._();

  String? _propertyId;
  Map<String, dynamic>? _propertyData;
  String? _pendingAction; // 'contact' | 'tour' | null

  /// Save the destination the user wanted before they had to sign in.
  void set(String propertyId, Map<String, dynamic> propertyData, {String? action}) {
    _propertyId = propertyId;
    _propertyData = Map<String, dynamic>.from(propertyData);
    _pendingAction = action;
  }

  /// Read and clear the stored destination (one-time use).
  PendingProperty? consume() {
    if (_propertyId == null || _propertyData == null) return null;
    final result = PendingProperty(
      propertyId: _propertyId!,
      propertyData: _propertyData!,
      pendingAction: _pendingAction,
    );
    _propertyId = null;
    _propertyData = null;
    _pendingAction = null;
    return result;
  }

  bool get hasPending => _propertyId != null;
}

class PendingProperty {
  final String propertyId;
  final Map<String, dynamic> propertyData;
  final String? pendingAction; // 'contact' | 'tour' | null

  const PendingProperty({
    required this.propertyId,
    required this.propertyData,
    this.pendingAction,
  });
}
