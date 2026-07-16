import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/shuttle_request.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';

/// Privacy-centric waiting screen for the customer.
/// No map is shown. When assigned, it displays the incoming vehicle info.
/// Background location streaming begins when this screen is opened.
class CustomerWaitingScreen extends StatefulWidget {
  final String requestId;
  final String customerName;
  final String carPlate;
  final String parkingZone;
  final String planType;

  const CustomerWaitingScreen({
    super.key,
    required this.requestId,
    required this.customerName,
    required this.carPlate,
    required this.parkingZone,
    required this.planType,
  });

  @override
  State<CustomerWaitingScreen> createState() => _CustomerWaitingScreenState();
}

class _CustomerWaitingScreenState extends State<CustomerWaitingScreen> {
  final FirestoreService _firestore = FirestoreService();
  final LocationService _location = LocationService();
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _startLocationStream();
  }

  @override
  void dispose() {
    _location.stopLocationStream();
    super.dispose();
  }

  Future<void> _startLocationStream() async {
    try {
      await _location.startLocationStream(
        onUpdate: (lat, lng) async {
          await _firestore.updateCustomerLocation(widget.requestId, lat, lng);
        },
      );
    } catch (e) {
      setState(() => _locationError = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final docStream = FirebaseFirestore.instance
        .collection('shuttle_requests')
        .doc(widget.requestId)
        .snapshots()
        .map((doc) => doc.exists ? ShuttleRequest.fromFirestore(doc) : null);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shuttle Status'),
        backgroundColor: Colors.teal,
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<ShuttleRequest?>(
        stream: docStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final request = snapshot.data!;
          final assigned = request.isAssigned || request.isCompleted;
          final vehicleInfo = request.driverVehicle ?? 'Pending assignment';

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_locationError != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red),
                    ),
                    child: Text(
                      'Location error: $_locationError',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your Shuttle Request',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _InfoRow(label: 'Name', value: widget.customerName),
                        _InfoRow(label: 'Car Plate', value: widget.carPlate),
                        _InfoRow(label: 'Parking Zone', value: widget.parkingZone),
                        _InfoRow(label: 'Plan', value: widget.planType),
                        const Divider(height: 24),
                        _InfoRow(
                          label: 'Status',
                          value: request.status.toUpperCase(),
                          valueColor: _statusColor(request.status),
                        ),
                        _InfoRow(
                          label: 'Assigned Van',
                          value: vehicleInfo,
                          valueColor: assigned ? Colors.green : Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (assigned)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.local_taxi, size: 40, color: Colors.green),
                        const SizedBox(height: 8),
                        Text(
                          'Your Shuttle Van: $vehicleInfo is on the way.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                if (request.isCompleted)
                  const Center(
                    child: Text(
                      'Thank you for using Parking Shuttle.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'assigned':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: valueColor ?? Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
