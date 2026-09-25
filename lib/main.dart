import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/presentation/splash_screen.dart';
import 'firebase_options.dart';
import 'services/firebase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Linux Desktop is not officially supported by firebase_core native plugins natively in this project.
  if (!kIsWeb && Platform.isLinux) {
    runApp(const UnsupportedPlatformApp());
    return;
  }

  String? initError;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await FirebaseService.initialize();
  } catch (e) {
    initError = e.toString();
  }

  runApp(ProviderScope(
    child: SecureEVotingApp(initializationError: initError),
  ));
}

class SecureEVotingApp extends ConsumerStatefulWidget {
  final String? initializationError;

  const SecureEVotingApp({super.key, this.initializationError});

  @override
  ConsumerState<SecureEVotingApp> createState() => _SecureEVotingAppState();
}

class _SecureEVotingAppState extends ConsumerState<SecureEVotingApp> {
  String? _initError;
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    _initError = widget.initializationError;
  }

  Future<void> _retryInitialization() async {
    setState(() {
      _isRetrying = true;
      _initError = null;
    });

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      }
      await FirebaseService.initialize();
      setState(() {
        _isRetrying = false;
      });
    } catch (e) {
      setState(() {
        _initError = e.toString().replaceAll("Exception: ", "");
        _isRetrying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initError != null || _isRetrying) {
      return MaterialApp(
        title: 'SecureVote',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: SplashScreen(
          errorMessage: _initError,
          onRetry: _retryInitialization,
        ),
      );
    }

    final goRouter = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'SecureVote',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: goRouter,
    );
  }
}

class UnsupportedPlatformApp extends StatelessWidget {
  const UnsupportedPlatformApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SecureVote',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'Linux Desktop is not supported for Firebase in this project.\n\nPlease run the app using Flutter Web (Chrome) or an Android/iOS Emulator.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red.shade800, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}
