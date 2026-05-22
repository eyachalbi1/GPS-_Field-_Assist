import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  late final AnimationController _masterCtrl;   // séquence globale
  late final AnimationController _shimmerCtrl;  // shimmer infini
  late final AnimationController _exitCtrl;

  // Logo
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;

  // Reveal bar (wipe de gauche à droite sur le logo)
  late final Animation<double> _revealProgress;

  // Texte
  late final Animation<double> _textOpacity;
  late final Animation<Offset>  _textSlide;
  late final Animation<double> _tagOpacity;

  // Barre de progression
  late final Animation<double> _barProgress;

  // Shimmer
  late final Animation<double> _shimmerPos;

  // Exit
  late final Animation<double> _exitScale;
  late final Animation<double> _exitOpacity;

  @override
  void initState() {
    super.initState();

    _masterCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800));
    _shimmerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    _exitCtrl    = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

    // Logo : scale élastique + opacity — 0→600ms
    _logoScale   = CurvedAnimation(parent: _masterCtrl, curve: const Interval(0.0, 0.22, curve: Curves.elasticOut))
        .drive(Tween(begin: 0.3, end: 1.0));
    _logoOpacity = CurvedAnimation(parent: _masterCtrl, curve: const Interval(0.0, 0.12, curve: Curves.easeIn))
        .drive(Tween(begin: 0.0, end: 1.0));

    // Reveal wipe — 0→500ms
    _revealProgress = CurvedAnimation(parent: _masterCtrl, curve: const Interval(0.0, 0.18, curve: Curves.easeOut))
        .drive(Tween(begin: 0.0, end: 1.0));

    // Texte — 500→1200ms
    _textOpacity = CurvedAnimation(parent: _masterCtrl, curve: const Interval(0.20, 0.45, curve: Curves.easeOut))
        .drive(Tween(begin: 0.0, end: 1.0));
    _textSlide   = CurvedAnimation(parent: _masterCtrl, curve: const Interval(0.20, 0.45, curve: Curves.easeOutCubic))
        .drive(Tween(begin: const Offset(0, 0.35), end: Offset.zero));
    _tagOpacity  = CurvedAnimation(parent: _masterCtrl, curve: const Interval(0.35, 0.55, curve: Curves.easeOut))
        .drive(Tween(begin: 0.0, end: 1.0));

    // Barre de progression — 0→100% sur toute la durée
    _barProgress = CurvedAnimation(parent: _masterCtrl, curve: Curves.easeInOut)
        .drive(Tween(begin: 0.0, end: 1.0));

    // Shimmer
    _shimmerPos = _shimmerCtrl.drive(Tween(begin: -1.0, end: 2.0));

    // Exit : zoom out + fade
    _exitScale   = CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn)
        .drive(Tween(begin: 1.0, end: 1.08));
    _exitOpacity = CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn)
        .drive(Tween(begin: 1.0, end: 0.0));

    _startSequence();
  }

  Future<void> _startSequence() async {
    _masterCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 2800));
    _shimmerCtrl.stop();
    await _exitCtrl.forward();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _masterCtrl.dispose();
    _shimmerCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: Listenable.merge([_exitCtrl, _masterCtrl]),
      builder: (_, __) => Transform.scale(
        scale: _exitScale.value,
        child: Opacity(
          opacity: _exitOpacity.value,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF060D22),
                    Color(0xFF0D1B4B),
                    Color(0xFF0A2060),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
              child: Stack(children: [

                // ── Grille de fond (effet tech) ──
                CustomPaint(
                  size: size,
                  painter: _GridPainter(),
                ),

                // ── Lueur centrale ──
                Center(
                  child: Container(
                    width: 300, height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppTheme.skyBottom.withOpacity(0.12 * _logoOpacity.value),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Contenu principal ──
                Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [

                    // Logo avec shimmer
                    AnimatedBuilder(
                      animation: _shimmerCtrl,
                      builder: (_, __) => Transform.scale(
                        scale: _logoScale.value,
                        child: Opacity(
                          opacity: _logoOpacity.value,
                          child: ShaderMask(
                            blendMode: BlendMode.srcATop,
                            shaderCallback: (bounds) => LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Colors.white,
                                Colors.white,
                                Colors.white.withOpacity(0.5),
                                Colors.white,
                                Colors.white,
                              ],
                              stops: [
                                0.0,
                                (_shimmerPos.value - 0.3).clamp(0.0, 1.0),
                                _shimmerPos.value.clamp(0.0, 1.0),
                                (_shimmerPos.value + 0.3).clamp(0.0, 1.0),
                                1.0,
                              ],
                            ).createShader(bounds),
                            child: Image.asset(
                              'assets/logoTunavBlanc.png',
                              width: 100, height: 100,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 36),

                    // Titre avec effet reveal
                    SlideTransition(
                      position: _textSlide,
                      child: FadeTransition(
                        opacity: _textOpacity,
                        child: ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Colors.white, AppTheme.skyLight],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds),
                          child: const Text(
                            'GPS Field Assist',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Tag line
                    FadeTransition(
                      opacity: _tagOpacity,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 20, height: 1, color: AppTheme.skyLight.withOpacity(0.5)),
                        const SizedBox(width: 8),
                        Text(
                          'TUNAV IT GROUP',
                          style: TextStyle(
                            color: AppTheme.skyLight.withOpacity(0.7),
                            fontSize: 11,
                            letterSpacing: 4,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(width: 20, height: 1, color: AppTheme.skyLight.withOpacity(0.5)),
                      ]),
                    ),

                    const SizedBox(height: 56),

                    // Barre de progression moderne
                    FadeTransition(
                      opacity: _tagOpacity,
                      child: Column(children: [
                        SizedBox(
                          width: 180,
                          child: Stack(children: [
                            // Track
                            Container(
                              height: 2,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                            // Fill animé
                            AnimatedBuilder(
                              animation: _masterCtrl,
                              builder: (_, __) => FractionallySizedBox(
                                widthFactor: _barProgress.value,
                                child: Container(
                                  height: 2,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(1),
                                    gradient: const LinearGradient(
                                      colors: [AppTheme.skyBottom, AppTheme.skyLight],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.skyLight.withOpacity(0.6),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 12),
                        AnimatedBuilder(
                          animation: _masterCtrl,
                          builder: (_, __) => Text(
                            '${(_barProgress.value * 100).toInt()}%',
                            style: TextStyle(
                              color: AppTheme.skyLight.withOpacity(0.5),
                              fontSize: 10,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ]),
                ),

                // ── Version en bas ──
                Positioned(
                  bottom: 32, left: 0, right: 0,
                  child: FadeTransition(
                    opacity: _tagOpacity,
                    child: Text(
                      'v1.0.0',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.2),
                        fontSize: 10,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Grille de fond ─────────────────────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 0.5;
    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter _) => false;
}