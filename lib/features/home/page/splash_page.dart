import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) context.go(RoutePaths.home);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_stories_rounded, size: 48, color: Color(0xFF07D2D7)),
              SizedBox(height: 20),
              Text('Zephyr',
                style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A), letterSpacing: 4,
                ),
              ),
              SizedBox(height: 8),
              Text('轻如风，阅无界',
                style: TextStyle(
                  fontSize: 14, color: Color(0xFF8A8A8E), letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
