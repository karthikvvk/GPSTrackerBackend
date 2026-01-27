import 'package:flutter/material.dart';
import 'package:gpstracking/nav.dart';
import 'package:gpstracking/services/background_service.dart';
import 'package:gpstracking/state/app_session.dart';
import 'package:gpstracking/theme.dart';
import 'package:provider/provider.dart';

import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (will use google-services.json on Android)
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
  }

  // Initialize background service
  await BackgroundService.initialize();

  runApp(const MyApp());
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
