import 'package:flutter/material.dart';
import 'package:gpstracking/nav.dart';
import 'package:gpstracking/services/background_service.dart';
import 'package:gpstracking/state/app_session.dart';
import 'package:gpstracking/theme.dart';
import 'package:gpstracking/utils/settings.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize background service
  await BackgroundService.initialize();

  // Wake up the Render server in the background so it's ready by the time
  // the user opens Live Map (Render free tier sleeps after ~15 min idle).
  _pingServer();

  runApp(const MyApp());
}

/// Fire-and-forget server wake-up ping.
Future<void> _pingServer() async {
  try {
    final settings = await Settings.instance;
    await http.get(
      Uri.parse('${settings.backendUrl}/serverstatus'),
    ).timeout(const Duration(seconds: 60));
    debugPrint('[Main] Server wake-up ping sent');
  } catch (e) {
    debugPrint('[Main] Server wake-up ping failed (ok if offline): $e');
  }
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: AppRouter.session,
      child: Consumer<AppSession>(
        builder: (context, session, _) {
          return MaterialApp.router(
            title: 'GPS Tracker',
            debugShowCheckedModeBanner: false,
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: session.themeMode,
            routerConfig: AppRouter.router,
          );
        },
      ),
    );
  }
}
