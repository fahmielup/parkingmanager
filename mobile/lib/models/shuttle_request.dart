import 'package:cloud_firestore/cloud_firestore.dart';

/// Customer shuttle request stored in the [shuttle_requests] collection.
class ShuttleRequest {
  final String id;
  final String customerName;
  final String carPlate;
  final String parkingZone;
  final String parkingPlanType;
  final String status;
  final String? driverVehicle;
  final Timestamp? timestamp;
  final double? currentLat;
  final double? currentLng;

  ShuttleRequest({
    required this.id,
    required this.customerName,
    required this.carPlate,
    required this.parkingZone,
    required this.parkingPlanType,
    required this.status,
    this.driverVehicle,
    this.timestamp,
    this.currentLat,
    this.currentLng,
  });

  bool get isPending => status == 'pending';
  bool get isAssigned => status == 'assigned';
  bool get isCompleted => status == 'completed';

  factory ShuttleRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ShuttleRequest(
      id: doc.id,
      customerName: data['customerName'] as String? ?? '',
      carPlate: data['carPlate'] as String? ?? '',
      parkingZone: data['parkingZone'] as String? ?? '',
      parkingPlanType: data['parkingPlanType'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      driverVehicle: data['driverVehicle'] as String?,
      timestamp: data['timestamp'] as Timestamp?,
      currentLat: data['currentLat'] as double?,
      currentLng: data['currentLng'] as double?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerName': customerName,
      'carPlate': carPlate,
      'parkingZone': parkingZone,
      'parkingPlanType': parkingPlanType,
      'status': status,
      'driverVehicle': driverVehicle,
      'timestamp': timestamp ?? FieldValue.serverTimestamp(),
      'currentLat': currentLat,
      'currentLng': currentLng,
    };
  }

  ShuttleRequest copyWith({
    String? id,
    String? customerName,
    String? carPlate,
    String? parkingZone,
    String? parkingPlanType,
    String? status,
    String? driverVehicle,
    Timestamp? timestamp,
    double? currentLat,
    double? currentLng,
  }) {
    return ShuttleRequest(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      carPlate: carPlate ?? this.carPlate,
      parkingZone: parkingZone ?? this.parkingZone,
      parkingPlanType: parkingPlanType ?? this.parkingPlanType,
      status: status ?? this.status,
      driverVehicle: driverVehicle ?? this.driverVehicle,
      timestamp: timestamp ?? this.timestamp,
      currentLat: currentLat ?? this.currentLat,
      currentLng: currentLng ?? this.currentLng,
    );
  }
}
