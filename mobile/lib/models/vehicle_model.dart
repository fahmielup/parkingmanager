import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents one company vehicle stored in the [company_vehicles] collection.
class VehicleModel {
  final String id;
  final String model;
  final String plateNumber;
  final String status;

  VehicleModel({
    required this.id,
    required this.model,
    required this.plateNumber,
    required this.status,
  });

  /// Display string passed to driver job state: "Vehicle Model (Car Plate)".
  String get displayInfo => '$model ($plateNumber)';

  factory VehicleModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return VehicleModel(
      id: doc.id,
      model: data['model'] as String? ?? '',
      plateNumber: data['plateNumber'] as String? ?? '',
      status: data['status'] as String? ?? 'Unknown',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'model': model,
      'plateNumber': plateNumber,
      'status': status,
    };
  }
}
