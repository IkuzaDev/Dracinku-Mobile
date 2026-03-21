import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Add for kIsWeb
import 'package:provider/provider.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'theme/app_theme.dart';

// Providers
import 'providers/auth_provider.dart';
import 'providers/platform_provider.dart';
import 'providers/download_provider.dart';

// Screens
import 'screens/main_layout.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize flutter_downloader functionality only on mobile platforms
  if (!kIsWeb) {
    await FlutterDownloader.initialize(
      debug: true, 
      ignoreSsl: true,
    );
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PlatformProvider()),
        ChangeNotifierProvider(create: (_) => DownloadProvider()),
      ],
      child: const DracinkuApp(),
    ),
  );
}

class DracinkuApp extends StatelessWidget {
  const DracinkuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dracinku',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return auth.isAuthenticated ? const MainLayout() : const LoginScreen();
        },
      ),
    );
  }
}
