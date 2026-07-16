import 'package:cloud_firestore/cloud_firestore.dart';

/// Driver clock-in record from the [staff_attendance] collection.
class AttendanceModel {
  final String id;
  final String driverName;
  final Timestamp timestamp;
  final String vehicleInfo;
  final String status;

  AttendanceModel({
    required this.id,
    required this.driverName,
    required this.timestamp,
    required this.vehicleInfo,
    required this.status,
  });

  factory AttendanceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AttendanceModel(
      id: doc.id,
      driverName: data['driverName'] as String? ?? '',
      timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(),
      vehicleInfo: data['vehicleInfo'] as String? ?? '',
      status: data['status'] as String? ?? 'Inactive',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'driverName': driverName,
      'timestamp': timestamp,
      'vehicleInfo': vehicleInfo,
      'status': status,
    };
  }
}
