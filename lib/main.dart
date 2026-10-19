import 'package:flutter/material.dart';
import 'package:iptv/app_controller.dart';
import 'package:iptv/app_core.dart';
import 'package:iptv/app_screens_auth_home.dart';
import 'package:iptv/app_shell.dart';

// ---- Merged from main.dart ----

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
