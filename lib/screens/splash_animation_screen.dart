import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'dart:async';

class SplashAnimationScreen extends ConsumerStatefulWidget {
  const SplashAnimationScreen({super.key});

  @override
  ConsumerState<SplashAnimationScreen> createState() => _SplashAnimationScreenState();
}

class _SplashAnimationScreenState extends ConsumerState<SplashAnimationScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer(const Duration(seconds: 5), _navigateToNextScreen);
  }

  void _navigateToNextScreen() {
    if (!mounted) return;
    _timer?.cancel();
    
    final user = ref.read(authProvider);
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
            user != null ? const HomeScreen() : const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark background to match video/animation
      body: GestureDetector(
        onTap: _navigateToNextScreen, // Allow user to skip
        child: Center(
          child: Image.asset(
            'assets/animations/logo_wybuch.webp',
            fit: BoxFit.contain, // Fit the webp nicely
            width: double.infinity,
            height: double.infinity,
          ),
        ),
      ),
    );
  }
}
