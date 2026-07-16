import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/hub_model.dart';

/// Multi-tenant session manager.
///
/// Holds the active `parkingHubId` tenant isolation key, caches it locally
/// via [SharedPreferences], and loads the tenant profile document from the
/// root `registered_hubs` collection.
class TenantService {
  TenantService._();
  static final TenantService instance = TenantService._();

  static const String _hubIdPrefKey = 'active_parking_hub_id';
  static const String _tncPrefKey = 'tnc_accepted_v1';
  static const String registeredHubs = 'registered_hubs';

  HubModel? _activeHub;

  HubModel? get activeHub => _activeHub;

  /// The tenant isolation key stamped onto every Firestore record.
  String get activeHubId => _activeHub?.id ?? '';

  bool get hasActiveHub => _activeHub != null;

  // -------------------------------------------------------------------
  // Terms & Conditions acceptance
  // -------------------------------------------------------------------
  Future<bool> isTncAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_tncPrefKey) ?? false;
  }

  Future<void> acceptTnc() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tncPrefKey, true);
  }

  // -------------------------------------------------------------------
  // Hub lifecycle
  // -------------------------------------------------------------------

  /// Attempts to restore a previously cached hub session.
  /// Returns the hub when found and still registered, otherwise null.
  Future<HubModel?> restoreCachedHub() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedId = prefs.getString(_hubIdPrefKey);
    if (cachedId == null || cachedId.isEmpty) return null;
    return selectHubById(cachedId, cache: false);
  }

  /// Loads a hub profile by its tenant code and activates the session.
  /// Returns null when the hub code does not exist in `registered_hubs`.
  Future<HubModel?> selectHubById(String hubId, {bool cache = true}) async {
    final doc = await FirebaseFirestore.instance
        .collection(registeredHubs)
        .doc(hubId.trim().toUpperCase())
        .get();
    if (!doc.exists) return null;

    _activeHub = HubModel.fromFirestore(doc);
    if (cache) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_hubIdPrefKey, _activeHub!.id);
    }
    return _activeHub;
  }

  /// Streams all registered hubs for the selector dropdown.
  Stream<List<HubModel>> streamHubs() {
    return FirebaseFirestore.instance
        .collection(registeredHubs)
        .snapshots()
        .map((snap) => snap.docs.map(HubModel.fromFirestore).toList());
  }

  /// Streams the active hub document so route guards react in real time
  /// when the server flips the subscription status.
  Stream<HubModel?> streamActiveHub() {
    if (_activeHub == null) return Stream.value(null);
    return FirebaseFirestore.instance
        .collection(registeredHubs)
        .doc(_activeHub!.id)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      _activeHub = HubModel.fromFirestore(doc);
      return _activeHub;
    });
  }

  /// Clears the tenant session (switch facility).
  Future<void> clearHub() async {
    _activeHub = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hubIdPrefKey);
  }
}
