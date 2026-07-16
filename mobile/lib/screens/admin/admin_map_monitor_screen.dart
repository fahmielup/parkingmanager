import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../constants/colors.dart';
import '../../constants/hub_locations.dart';
import '../../models/shuttle_request.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';

/// Admin Google Maps screen with live shuttle tracking and customer proximity.
class AdminMapMonitorScreen extends StatefulWidget {
  const AdminMapMonitorScreen({super.key});

  @override
  State<AdminMapMonitorScreen> createState() => _AdminMapMonitorScreenState();
}

class _AdminMapMonitorScreenState extends State<AdminMapMonitorScreen>
    with TickerProviderStateMixin {
  final FirestoreService _firestore = FirestoreService();
  GoogleMapController? _mapController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  /// Splits requests into near-hub and other customers.
  ({List<ShuttleRequest> near, List<ShuttleRequest> other})
      _categorizeRequests(List<ShuttleRequest> requests) {
    final near = <ShuttleRequest>[];
    final other = <ShuttleRequest>[];

    for (final r in requests) {
      if (r.currentLat != null && r.currentLng != null) {
        final pos = LatLng(r.currentLat!, r.currentLng!);
        if (LocationService.isNearAnyHub(pos)) {
          near.add(r);
        } else {
          other.add(r);
        }
      } else {
        other.add(r);
      }
    }
    return (near: near, other: other);
  }

  Set<Marker> _buildMarkers(List<ShuttleRequest> requests) {
    final markers = <Marker>{};

    // Hub markers
    markers.add(Marker(
      markerId: const MarkerId('parking_hub'),
      position: HubLocations.parkingHub,
      infoWindow: const InfoWindow(title: HubLocations.parkingHubName),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
    ));
    markers.add(Marker(
      markerId: const MarkerId('ciq_dropoff'),
      position: HubLocations.ciqDropOff,
      infoWindow: const InfoWindow(title: HubLocations.ciqDropOffName),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
    ));

    // Proximity circles (added as simple circle overlays via circles set)

    // Customer markers
    for (final r in requests) {
      if (r.currentLat != null && r.currentLng != null) {
        final pos = LatLng(r.currentLat!, r.currentLng!);
        final nearHub = LocationService.isNearAnyHub(pos);
        markers.add(Marker(
          markerId: MarkerId('customer_${r.id}'),
          position: pos,
          infoWindow: InfoWindow(
            title: r.customerName,
            snippet: '${r.carPlate} | ${r.parkingZone}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            nearHub ? BitmapDescriptor.hueRose : BitmapDescriptor.hueOrange,
          ),
        ));
      }
    }
    return markers;
  }

  Set<Circle> _buildCircles() {
    return {
      Circle(
        circleId: const CircleId('parking_hub_radius'),
        center: HubLocations.parkingHub,
        radius: HubLocations.proximityRadiusMeters,
        fillColor: Colors.green.withAlpha(38),
        strokeColor: Colors.green,
        strokeWidth: 2,
      ),
      Circle(
        circleId: const CircleId('ciq_radius'),
        center: HubLocations.ciqDropOff,
        radius: HubLocations.proximityRadiusMeters,
        fillColor: Colors.blue.withAlpha(38),
        strokeColor: Colors.blue,
        strokeWidth: 2,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Shuttle Map'),
        backgroundColor: Colors.indigo,
      ),
      body: StreamBuilder<List<ShuttleRequest>>(
        stream: _firestore.streamRequests(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final requests = snapshot.data!;
          final categorized = _categorizeRequests(requests);

          return Column(
            children: [
              Expanded(
                flex: 3,
                child: GoogleMap(
                  onMapCreated: (controller) => _mapController = controller,
                  initialCameraPosition: const CameraPosition(
                    target: HubLocations.parkingHub,
                    zoom: 14,
                  ),
                  markers: _buildMarkers(requests),
                  circles: _buildCircles(),
                  myLocationEnabled: false,
                  mapToolbarEnabled: true,
                ),
              ),
              Expanded(
                flex: 2,
                child: _buildPriorityPanel(categorized.near),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPriorityPanel(List<ShuttleRequest> nearHubRequests) {
    return Container(
      color: Colors.grey.shade100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            color: AppColors.danger,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      width: 14 + _pulseController.value * 8,
                      height: 14 + _pulseController.value * 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red.withAlpha(((1 - _pulseController.value) * 255).round()),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                const Text(
                  'Auto-Active / Customer Near Hub',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: nearHubRequests.isEmpty
                ? const Center(
                    child: Text('No customers within 100m of a hub.'),
                  )
                : ListView.builder(
                    itemCount: nearHubRequests.length,
                    itemBuilder: (context, index) {
                      final r = nearHubRequests[index];
                      final label = (r.currentLat != null && r.currentLng != null)
                          ? LocationService.nearestHubLabel(
                              LatLng(r.currentLat!, r.currentLng!),
                            )
                          : 'Unknown';
                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.danger,
                          child: Icon(Icons.priority_high,
                              color: Colors.white),
                        ),
                        title: Text(r.customerName),
                        subtitle: Text('${r.carPlate} | ${r.parkingZone}'),
                        trailing: Chip(
                          backgroundColor: Colors.red.shade100,
                          label: Text(label),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
