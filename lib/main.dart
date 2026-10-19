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
            return const _StartupScreen();
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


class _StartupScreen extends StatelessWidget {
  const _StartupScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.25),
              radius: 1.1,
              colors: [Color(0xFF211B3A), AppTheme.background, AppTheme.background],
              stops: [0, 0.55, 1],
            ),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppTheme.accent, AppTheme.accentSecondary]),
                  borderRadius: BorderRadius.all(Radius.circular(22)),
                ),
                child: SizedBox(width: 76, height: 76, child: Icon(Icons.play_arrow_rounded, color: Color(0xFF100E1C), size: 52)),
              ),
              SizedBox(height: 22),
              Text('UNEX VISION', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: 2.4)),
              SizedBox(height: 9),
              Text('Preparando sua experiência', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
              SizedBox(height: 28),
              SizedBox(width: 120, child: LinearProgressIndicator(minHeight: 3, borderRadius: BorderRadius.all(Radius.circular(8))),),
            ],
          ),
        ),
      );
}
