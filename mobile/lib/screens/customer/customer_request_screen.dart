import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../models/shuttle_request.dart';
import '../../services/firestore_service.dart';
import '../../services/tenant_service.dart';
import 'customer_waiting_screen.dart';

/// Customer form to request a shuttle. Includes plan selector and privacy-safe
/// location permission flow. No map is shown to the customer.
class CustomerRequestScreen extends StatefulWidget {
  const CustomerRequestScreen({super.key});

  @override
  State<CustomerRequestScreen> createState() => _CustomerRequestScreenState();
}

class _CustomerRequestScreenState extends State<CustomerRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _plateController = TextEditingController();
  final FirestoreService _firestore = FirestoreService();

  String _planType = 'Plan Harian';
  bool _isSubmitting = false;
  String? _requestId;

  /// Zones are populated dynamically from the selected hub profile
  /// (`registered_hubs/{parkingHubId}.zones`), falling back to defaults.
  late final List<String> _zones = TenantService.instance.activeHub?.zones ??
      const ['Zone A', 'Zone B', 'Zone C'];
  late String _parkingZone = _zones.first;

  @override
  void dispose() {
    _nameController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _requestLocationPermission() async {
    // Ask for foreground then background if needed.
    var status = await Permission.location.request();
    if (status.isGranted) {
      var backgroundStatus = await Permission.locationAlways.request();
      print('Background location status: $backgroundStatus');
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      await _requestLocationPermission();

      final request = ShuttleRequest(
        id: '',
        customerName: _nameController.text.trim(),
        carPlate: _plateController.text.trim().toUpperCase(),
        parkingZone: _parkingZone,
        parkingPlanType: _planType,
        status: 'pending',
        timestamp: Timestamp.now(),
      );

      final docRef = await _firestore.addShuttleRequest(request);
      _requestId = docRef.id;

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CustomerWaitingScreen(
            requestId: _requestId!,
            customerName: _nameController.text.trim(),
            carPlate: _plateController.text.trim().toUpperCase(),
            parkingZone: _parkingZone,
            planType: _planType,
          ),
        ),
      );
    } catch (e) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request failed: $e')),
      );
    }
  }

  Widget _buildPlanToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '1. Choose Your Parking Plan',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Shuttle Transport Service is included with your parking booking.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _PlanButton(
                label: 'Plan Harian',
                icon: Icons.today,
                selected: _planType == 'Plan Harian',
                selectedColor: Colors.orange,
                onTap: () => setState(() => _planType = 'Plan Harian'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PlanButton(
                label: 'Plan Bulanan',
                icon: Icons.calendar_month,
                selected: _planType == 'Plan Bulanan',
                selectedColor: Colors.purple,
                onTap: () => setState(() => _planType = 'Plan Bulanan'),
              ),
            ),
          ],
        ),
      ],
    );
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
              _buildPlanToggle(),
              const SizedBox(height: 24),
              const Text(
                '2. Your Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Customer Full Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter your full name'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _plateController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Car Plate Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.directions_car),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter your car plate number'
                    : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _parkingZone,
                decoration: const InputDecoration(
                  labelText: 'Parking Zone',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.local_parking),
                ),
                items: _zones.map((zone) {
                  return DropdownMenuItem<String>(
                    value: zone,
                    child: Text(zone),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _parkingZone = value);
                },
              ),
              const SizedBox(height: 24),
              const Text(
                '3. Privacy Notice',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your GPS coordinates will be shared securely with the shuttle '
                'dispatch team only while your request is active. No map tracking '
                'view is available to you for privacy.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _isSubmitting ? null : _submitRequest,
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Request Shuttle & Share Location'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  const _PlanButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? selectedColor : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? selectedColor : Colors.grey.shade400,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? Colors.white : Colors.grey.shade700),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.grey.shade800,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (selected)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Shuttle included',
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
