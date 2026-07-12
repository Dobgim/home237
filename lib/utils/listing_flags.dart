import 'package:cloud_firestore/cloud_firestore.dart';

/// Shared helpers for paid listing flags and listing freshness.
///
/// Boost / fast-track purchases write `isBoosted` / `isFastTracked` together
/// with a `boostedUntil` / `fastTrackedUntil` deadline. Older documents may
/// only have the boolean, so a missing deadline counts as still active to
/// avoid stripping paid promotions retroactively.

DateTime? _toDate(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return null;
}

/// True while a paid boost is still within its purchased window.
bool isBoostActive(Map<String, dynamic> data) {
  if (data['isBoosted'] != true) return false;
  final until = _toDate(data['boostedUntil']);
  return until == null || until.isAfter(DateTime.now());
}

/// True while a paid fast-track is still within its purchased window.
bool isFastTrackActive(Map<String, dynamic> data) {
  if (data['isFastTracked'] != true) return false;
  final until = _toDate(data['fastTrackedUntil']);
  return until == null || until.isAfter(DateTime.now());
}

/// Days since the landlord last confirmed the listing is available
/// (falls back to creation date). Null when neither date exists.
int? daysSinceConfirmed(Map<String, dynamic> data) {
  final confirmed =
      _toDate(data['lastConfirmedAt']) ?? _toDate(data['createdAt']);
  if (confirmed == null) return null;
  return DateTime.now().difference(confirmed).inDays;
}

/// Listings unconfirmed for longer than this are de-ranked in search results.
const int staleAfterDays = 30;

/// True when the listing was created or re-confirmed recently enough to rank
/// normally. Listings without any date rank as fresh (never punish missing data).
bool isListingFresh(Map<String, dynamic> data) {
  final days = daysSinceConfirmed(data);
  return days == null || days <= staleAfterDays;
}

/// Listings unconfirmed for longer than this are hidden from tenants entirely
/// (the landlord still sees them in My Properties and can re-confirm).
const int hideAfterDays = 60;

/// True when the listing is too stale to show to tenants at all.
bool isListingHidden(Map<String, dynamic> data) {
  final days = daysSinceConfirmed(data);
  return days != null && days > hideAfterDays;
}
