import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SuccessScreen extends StatefulWidget {
  const SuccessScreen({super.key});

  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen>
    with TickerProviderStateMixin {
  // ── Circle scale-in ───────────────────────────────────────────────────────
  late AnimationController _circleController;
  late Animation<double> _circleScale;

  // ── Tick stroke draw ──────────────────────────────────────────────────────
  late AnimationController _tickController;
  late Animation<double> _tickProgress;

  // ── Subtle pulse after draw ───────────────────────────────────────────────
  late AnimationController _pulseController;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();

    // 1. Circle pops in
    _circleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _circleScale = CurvedAnimation(
      parent: _circleController,
      curve: Curves.elasticOut,
    );

    // 2. Tick draws itself
    _tickController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _tickProgress = CurvedAnimation(
      parent: _tickController,
      curve: Curves.easeOut,
    );

    // 3. Gentle pulse
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pulse = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Chain the animations
    _circleController.forward().then((_) {
      _tickController.forward().then((_) {
        _pulseController.repeat(reverse: true);
      });
    });

    // Navigate away after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      context.go('/location');
    });
  }

  @override
  void dispose() {
    _circleController.dispose();
    _tickController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top: home page logo ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 28, left: 20, right: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Image.asset(
                  'assets/images/home_main_logo.png',
                  height: 36,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => _FallbackLogo(),
                ),
              ),
            ),

            // ── Centre: animated check circle ───────────────────────────────
            Expanded(
              child: Center(
                child: AnimatedBuilder(
                  animation: Listenable.merge(
                      [_circleScale, _tickProgress, _pulse]),
                  builder: (context, _) {
                    return ScaleTransition(
                      scale: _circleScale,
                      child: Transform.scale(
                        scale: _pulse.value,
                        child: SizedBox(
                          width: 120,
                          height: 120,
                          child: CustomPaint(
                            painter: _CheckPainter(
                              progress: _tickProgress.value,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // ── Bottom: splash screen logo2 ─────────────────────────────────
            Padding(
              padding: EdgeInsets.only(
                bottom: size.height * 0.05,
              ),
              child: Image.asset(
                'assets/images/main_logo2.png',
                width: size.width * 0.38,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => _FallbackVersoAi(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom painter — draws the blue circle and animates the tick stroke
// ─────────────────────────────────────────────────────────────────────────────
class _CheckPainter extends CustomPainter {
  final double progress; // 0.0 → 1.0

  const _CheckPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // ── Blue circle ────────────────────────────────────────────────────────
    final circlePaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, circlePaint);

    // ── Animated tick stroke ────────────────────────────────────────────────
    if (progress <= 0) return;

    final tickPaint = Paint()
      ..color = const Color(0xFFFFD93D)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = size.width * 0.09;

    // Tick path: short leg then long leg
    // Points in a 120×120 box:
    final p1 = Offset(size.width * 0.25, size.height * 0.50);
    final p2 = Offset(size.width * 0.44, size.height * 0.67);
    final p3 = Offset(size.width * 0.75, size.height * 0.35);

    // Total path length (approximate for progress mapping)
    final leg1 = (p2 - p1).distance;
    final leg2 = (p3 - p2).distance;
    final total = leg1 + leg2;

    final drawn = progress * total;

    final path = Path();
    path.moveTo(p1.dx, p1.dy);

    if (drawn <= leg1) {
      // Still drawing first leg
      final t = drawn / leg1;
      path.lineTo(
        p1.dx + (p2.dx - p1.dx) * t,
        p1.dy + (p2.dy - p1.dy) * t,
      );
    } else {
      // First leg complete, drawing second
      path.lineTo(p2.dx, p2.dy);
      final remaining = drawn - leg1;
      final t = remaining / leg2;
      path.lineTo(
        p2.dx + (p3.dx - p2.dx) * t,
        p2.dy + (p3.dy - p2.dy) * t,
      );
    }

    canvas.drawPath(path, tickPaint);
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
// Fallback widgets if image assets are missing
// ─────────────────────────────────────────────────────────────────────────────
class _FallbackLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFFFFD93D), Color(0xFFF59E0B)],
            ),
          ),
          child: const Icon(Icons.star_rounded, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 8),
        const Text(
          'claimit',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2563EB),
          ),
        ),
      ],
    );
  }
}

class _FallbackVersoAi extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Text('from ', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        Text(
          'VERSOai',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF4B5563),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
