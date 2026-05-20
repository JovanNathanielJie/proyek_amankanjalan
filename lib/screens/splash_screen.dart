import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onLoadingComplete;

  const SplashScreen({
    super.key,
    required this.onLoadingComplete,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Animasi scale untuk logo
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    // Animasi opacity untuk teks
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
      ),
    );

    _animationController.forward();

    // Simulasi loading selama 3 detik
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        widget.onLoadingComplete();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF223199), 
              Color(0xFF2563EB), 
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              ScaleTransition(
                scale: _scaleAnimation,
                child: Image.asset(
                  'assets/images/LogoAmankanJalanFIX.png',
                  width: 200, 
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
    
                    return const Icon(
                      Icons.shield,
                      size: 100, 
                      color: Colors.white,
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),

              // Teks aplikasi dengan animasi opacity
              FadeTransition(
                opacity: _opacityAnimation,
                child: const Column(
                  children: [
                    Text(
                      'Jalan Aman, Perjalanan Nyaman',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                        letterSpacing: 1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 60),

              // Loading indicator dengan animasi spin
              ScaleTransition(
                scale: _scaleAnimation,
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withOpacity(0.8), 
                    ),
                    strokeWidth: 4,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Loading text
              FadeTransition(
                opacity: _opacityAnimation,
                child: const Text(
                  'Memuat aplikasi...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white60,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}