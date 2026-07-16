import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Geofence centers for the CIQ shuttle route.
/// Used by the admin proximity monitor and customer background stream logic.
class HubLocations {
  const HubLocations._();

  static const String parkingHubName = 'Parking Hub';
  static const String ciqDropOffName = 'CIQ Drop-off';

  // Replace with actual surveyed coordinates.
  static const LatLng parkingHub = LatLng(1.4927, 103.7414);
  static const LatLng ciqDropOff = LatLng(1.4656, 103.7577);

  // Customers within this radius are considered "near hub" and auto-prioritised.
  static const double proximityRadiusMeters = 100.0;
}
