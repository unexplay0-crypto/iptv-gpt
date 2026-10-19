import 'package:flutter/material.dart';

import 'controllers/app_controller.dart';
import 'core/app_constants.dart';
import 'core/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/shell_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const UnexVisionApp());
}

class UnexVisionApp extends StatefulWidget {
  const UnexVisionApp({super.key});

  @override
  State<UnexVisionApp> createState() => _UnexVisionAppState();
}

class _UnexVisionAppState extends State<UnexVisionApp> {
  late final AppController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AppController();
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          if (_controller.isInitializing) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (_controller.account == null) {
            return LoginScreen(controller: _controller, key: const ValueKey('login'));
          }
          return ShellScreen(controller: _controller, key: const ValueKey('shell'));
        },
      ),
    );
  }
}
