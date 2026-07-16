import 'dart:async';
import 'dart:math';

import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../constants/hub_locations.dart';

/// Geolocation manager.
/// Handles permission, position streams, and Haversine distance checks.
class LocationService {
  StreamSubscription<Position>? _positionSubscription;

  /// Requests location permission and checks if services are enabled.
  Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Begins a foreground/background position stream.
  /// [onUpdate] is called on every new position.
  Future<void> startLocationStream({
    required Function(double lat, double lng) onUpdate,
  }) async {
    await stopLocationStream();

    final hasPermission = await requestPermission();
    if (!hasPermission) {
      throw Exception('Location permission not granted or services disabled.');
    }

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 10, // metres
      ),
    ).listen((Position position) {
      onUpdate(position.latitude, position.longitude);
    }, onError: (e) {
      print('Location stream error: $e');
    });
  }

  Future<void> stopLocationStream() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  /// Haversine distance between two coordinates in metres.
  static double distanceBetween(LatLng a, LatLng b) {
    const double earthRadius = 6371000; // metres
    final dLat = _toRadians(b.latitude - a.latitude);
    final dLng = _toRadians(b.longitude - a.longitude);
    final lat1 = _toRadians(a.latitude);
    final lat2 = _toRadians(b.latitude);

    final aVal = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(aVal), sqrt(1 - aVal));
    return earthRadius * c;
  }

  static double _toRadians(double degree) => degree * pi / 180;

  /// Returns true if [position] is inside the 100m radius of either hub.
  static bool isNearAnyHub(LatLng position) {
    final parkingHubDistance = distanceBetween(position, HubLocations.parkingHub);
    final ciqDistance = distanceBetween(position, HubLocations.ciqDropOff);
    return parkingHubDistance <= HubLocations.proximityRadiusMeters ||
        ciqDistance <= HubLocations.proximityRadiusMeters;
  }

  /// Finds the nearest hub label for display.
  static String nearestHubLabel(LatLng position) {
    final d1 = distanceBetween(position, HubLocations.parkingHub);
    final d2 = distanceBetween(position, HubLocations.ciqDropOff);
    if (d1 <= HubLocations.proximityRadiusMeters) return HubLocations.parkingHubName;
    if (d2 <= HubLocations.proximityRadiusMeters) return HubLocations.ciqDropOffName;
    return 'On Route';
  }
}
