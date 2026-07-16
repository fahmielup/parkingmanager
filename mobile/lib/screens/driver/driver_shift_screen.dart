import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/attendance_model.dart';
import '../../models/vehicle_model.dart';
import '../../services/firestore_service.dart';
import 'driver_job_screen.dart';

/// Pre-shift gatekeeper: attendance log + dynamic vehicle selection.
class DriverShiftScreen extends StatefulWidget {
  final ValueChanged<String>? onVehicleSelected;

  const DriverShiftScreen({super.key, this.onVehicleSelected});

  @override
  State<DriverShiftScreen> createState() => _DriverShiftScreenState();
}

class _DriverShiftScreenState extends State<DriverShiftScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final FirestoreService _firestore = FirestoreService();

  VehicleModel? _selectedVehicle;
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _clockIn() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVehicle == null) {
      setState(() => _error = 'Please select a vehicle.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final attendance = AttendanceModel(
        id: '',
        driverName: _nameController.text.trim(),
        timestamp: Timestamp.now(),
        vehicleInfo: _selectedVehicle!.displayInfo,
        status: 'Active',
      );
      await _firestore.addAttendance(attendance);

      widget.onVehicleSelected?.call(_selectedVehicle!.displayInfo);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DriverJobScreen(
            driverName: _nameController.text.trim(),
            vehicleInfo: _selectedVehicle!.displayInfo,
          ),
        ),
      );
    } catch (e) {
      setState(() => _error = 'Clock-in failed: $e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Step 1: Attendance Log',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Driver Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter your name'
                    : null,
              ),
              const SizedBox(height: 24),
              const Text(
                'Step 2: Select Vehicle',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<VehicleModel>>(
                stream: _firestore.streamVehicles(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text('Error loading vehicles: ${snapshot.error}');
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final vehicles = snapshot.data!
                      .where((v) => v.status.toLowerCase() == 'available')
                      .toList();

                  if (vehicles.isEmpty) {
                    return const Text('No available vehicles right now.');
                  }

                  return DropdownButtonFormField<VehicleModel>(
                    initialValue: _selectedVehicle,
                    decoration: const InputDecoration(
                      labelText: 'Assigned Vehicle',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.local_taxi),
                    ),
                    items: vehicles.map((vehicle) {
                      return DropdownMenuItem<VehicleModel>(
                        value: vehicle,
                        child: Text(vehicle.displayInfo),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedVehicle = value;
                        _error = null;
                      });
                    },
                  );
                },
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _isSubmitting ? null : _clockIn,
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Clock In & Start Shift'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
