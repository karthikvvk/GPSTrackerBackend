import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

/// Call this ONCE before starting background tracking.
/// Opens the OS dialog asking the user to exempt your app from battery killing.
Future<void> requestBatteryOptimizationExemption(BuildContext? context) async {
  if (!Platform.isAndroid) return;

  final status = await Permission.ignoreBatteryOptimizations.status;

  if (!status.isGranted) {
    // This opens the system dialog:
    // "Allow [App] to run in background without restrictions?"
    final result = await Permission.ignoreBatteryOptimizations.request();
    
    // If the user denied the exemption and we have a UI context, warn them.
    if (!result.isGranted && context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Battery optimization is active. Tracking may stop when you close the app.'),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }
}
