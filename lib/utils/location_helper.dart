import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location/location.dart' as loc;

/// Ensures device location services are enabled and the app has permission.
///
/// Returns `true` when the app is fully authorised to use GPS.
/// Uses the Google Play Services in-app dialog to enable location services
/// (no redirect to Settings, avoids background-start crashes on Android 12+).
Future<bool> ensureLocationEnabled(BuildContext context) async {
  // 1. Check device location service
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();

  if (!serviceEnabled) {
    // Use the Google Play Services in-app resolution dialog.
    // This shows the same "Turn on" prompt that Google Maps uses,
    // keeps the user inside the app, and avoids the
    // ForegroundServiceStartNotAllowedException crash.
    final location = loc.Location();
    final enabled = await location.requestService();
    if (!enabled) return false;
  }

  // 2. Check permission
  LocationPermission permission = await Geolocator.checkPermission();

  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      return false;
    }
  }

  // 3. Permanently denied → send user to app settings
  if (permission == LocationPermission.deniedForever) {
    if (!context.mounted) return false;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Text(
          'Location permission is permanently denied. '
          'Please enable it from the app settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Geolocator.openAppSettings();
              Navigator.of(context).pop();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
    return false;
  }

  return true;
}
