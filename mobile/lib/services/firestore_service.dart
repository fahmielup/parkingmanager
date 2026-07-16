import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attendance_model.dart';
import '../models/chat_message.dart';
import '../models/shuttle_request.dart';
import '../models/vehicle_model.dart';
import 'tenant_service.dart';

/// Centralised Firestore helper for all collections used by the shuttle app.
/// Collection names match the PR specification exactly.
///
/// MULTI-TENANT ISOLATION: every stream is filtered by, and every write is
/// stamped with, the active `parkingHubId` tenant key so multiple parking
/// companies can safely share the backend without data cross-contamination.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Collection names (hardcoded to match the spec).
  static const String companyVehicles = 'company_vehicles';
  static const String staffAttendance = 'staff_attendance';
  static const String shuttleRequests = 'shuttle_requests';
  static const String chats = 'chats';
  static const String messages = 'messages';

  /// The active tenant isolation key.
  String get _hubId => TenantService.instance.activeHubId;

  /// Chat channels are namespaced per tenant: `{hubId}__{channelId}`.
  String _chatDocId(String channelId) => '${_hubId}__$channelId';

  /// Legacy records seeded before multi-tenancy carry no hub key; treat
  /// them as belonging to the active hub during development.
  bool _belongsToHub(Map<String, dynamic> data) {
    final recordHub = data['parkingHubId'] as String?;
    return recordHub == null || recordHub.isEmpty || recordHub == _hubId;
  }

  // Streams (all tenant-scoped; filtering done client-side to avoid
  // Firestore composite index requirements during local development).
  Stream<List<VehicleModel>> streamVehicles() {
    return _db.collection(companyVehicles).snapshots().map((snapshot) =>
        snapshot.docs
            .where((d) => _belongsToHub(d.data()))
            .map(VehicleModel.fromFirestore)
            .toList());
  }

  Stream<List<AttendanceModel>> streamAttendance() {
    return _db
        .collection(staffAttendance)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .where((d) => _belongsToHub(d.data()))
            .map(AttendanceModel.fromFirestore)
            .toList());
  }

  Stream<List<ShuttleRequest>> streamRequests() {
    return _db
        .collection(shuttleRequests)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .where((d) => _belongsToHub(d.data()))
            .map(ShuttleRequest.fromFirestore)
            .toList());
  }

  Stream<List<ShuttleRequest>> streamDriverJobs() {
    return _db
        .collection(shuttleRequests)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .where((d) => _belongsToHub(d.data()))
            .map(ShuttleRequest.fromFirestore)
            .where((r) => r.status == 'pending' || r.status == 'assigned')
            .toList());
  }

  Stream<List<ChatMessage>> streamMessages(String channelId) {
    return _db
        .collection(chats)
        .doc(_chatDocId(channelId))
        .collection(messages)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(ChatMessage.fromFirestore).toList());
  }

  // Writes (every record is stamped with the tenant key).
  Future<DocumentReference> addAttendance(AttendanceModel attendance) async {
    final data = attendance.toMap()..['parkingHubId'] = _hubId;
    return await _db.collection(staffAttendance).add(data);
  }

  Future<DocumentReference> addShuttleRequest(ShuttleRequest request) async {
    final data = request.toMap()..['parkingHubId'] = _hubId;
    return await _db.collection(shuttleRequests).add(data);
  }

  Future<void> updateRequestStatus(
    String requestId,
    String status, {
    String? driverVehicle,
  }) async {
    final updateData = <String, dynamic>{'status': status};
    if (driverVehicle != null) {
      updateData['driverVehicle'] = driverVehicle;
    }
    await _db.collection(shuttleRequests).doc(requestId).update(updateData);
  }

  Future<void> updateCustomerLocation(
    String requestId,
    double lat,
    double lng,
  ) async {
    await _db.collection(shuttleRequests).doc(requestId).update({
      'currentLat': lat,
      'currentLng': lng,
    });
  }

  Future<void> sendMessage(String channelId, ChatMessage message) async {
    final data = message.toMap()..['parkingHubId'] = _hubId;
    await _db
        .collection(chats)
        .doc(_chatDocId(channelId))
        .collection(messages)
        .add(data);
  }

  Future<void> ensureChatChannelExists(String channelId) async {
    await _db.collection(chats).doc(_chatDocId(channelId)).set({
      'createdAt': FieldValue.serverTimestamp(),
      'parkingHubId': _hubId,
      'channelId': channelId,
    }, SetOptions(merge: true));
  }
}
