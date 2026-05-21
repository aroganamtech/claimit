import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/bill_reward_provider.dart';

class BillScannerScreen extends StatefulWidget {
  const BillScannerScreen({super.key});

  @override
  State<BillScannerScreen> createState() => _BillScannerScreenState();
}

class _BillScannerScreenState extends State<BillScannerScreen>
    with SingleTickerProviderStateMixin {
  static const _blue = Color(0xFF1565C0);
  bool _torchOn = false;
  late AnimationController _scanLineCtrl;
  late Animation<double> _scanLineAnim;

  @override
  void initState() {
    super.initState();
    _scanLineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scanLineAnim =
        Tween<double>(begin: 0, end: 1).animate(_scanLineCtrl);
  }

  @override
  void dispose() {
    _scanLineCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery);
    if (img != null && mounted) {
      _triggerScan();
    }
  }

  void _triggerScan() {
    final provider = context.read<BillRewardProvider>();
    provider.simulateScan();
    context.push('/bill-reader/scanning');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Bill Reader',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: false,
        actions: [
          // Flashlight toggle
          IconButton(
            icon: Icon(
              _torchOn ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
              color: _torchOn ? Colors.yellow : Colors.white,
              size: 26,
            ),
            onPressed: () => setState(() => _torchOn = !_torchOn),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Camera viewfinder area ──────────────────────────────────────
          Positioned.fill(
            child: _CheckerboardBackground(),
          ),

          // ── Scan frame ─────────────────────────────────────────────────
          Center(
            child: SizedBox(
              width: 260,
              height: 320,
              child: Stack(
                children: [
                  // Corners
                  ..._buildCorners(),

                  // Animated scan line
                  AnimatedBuilder(
                    animation: _scanLineAnim,
                    builder: (_, __) => Positioned(
                      top: _scanLineAnim.value * 300,
                      left: 12,
                      right: 12,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            _blue.withOpacity(0),
                            _blue.withOpacity(0.9),
                            _blue.withOpacity(0),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Upload from gallery button ──────────────────────────────────
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _pickFromGallery,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.4), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.photo_library_outlined,
                          color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Upload From Gallery',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Scan Bill button ────────────────────────────────────────────
          Positioned(
            bottom: 32,
            left: 24,
            right: 24,
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _triggerScan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28)),
                  elevation: 0,
                ),
                child: const Text(
                  'Scan Bill',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCorners() {
    const size = 28.0;
    const thickness = 3.5;
    const color = Color(0xFF1E88E5);
    const radius = 6.0;

    Widget corner({
      bool top = true,
      bool left = true,
    }) {
      return Positioned(
        top: top ? 0 : null,
        bottom: top ? null : 0,
        left: left ? 0 : null,
        right: left ? null : 0,
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _CornerPainter(
                isTop: top, isLeft: left, color: color,
                thickness: thickness, radius: radius),
          ),
        ),
      );
    }

    return [
      corner(top: true, left: true),
      corner(top: true, left: false),
      corner(top: false, left: true),
      corner(top: false, left: false),
    ];
  }
}

// ── Checkerboard placeholder for camera preview ─────────────────────────────
class _CheckerboardBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _CheckerPainter());
  }
}

class _CheckerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const tileSize = 20.0;
    final p1 = Paint()..color = const Color(0xFF2A2A2A);
    final p2 = Paint()..color = const Color(0xFF1A1A1A);

    for (double y = 0; y < size.height; y += tileSize) {
      for (double x = 0; x < size.width; x += tileSize) {
        final isEven = ((x / tileSize).toInt() + (y / tileSize).toInt()) % 2 == 0;
        canvas.drawRect(
          Rect.fromLTWH(x, y, tileSize, tileSize),
          isEven ? p1 : p2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Corner bracket painter ──────────────────────────────────────────────────
class _CornerPainter extends CustomPainter {
  final bool isTop;
  final bool isLeft;
  final Color color;
  final double thickness;
  final double radius;

  const _CornerPainter({
    required this.isTop,
    required this.isLeft,
    required this.color,
    required this.thickness,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final w = size.width;
    final h = size.height;

    if (isTop && isLeft) {
      path
        ..moveTo(0, h)
        ..lineTo(0, radius)
        ..arcToPoint(Offset(radius, 0),
            radius: Radius.circular(radius), clockwise: true)
        ..lineTo(w, 0);
    } else if (isTop && !isLeft) {
      path
        ..moveTo(0, 0)
        ..lineTo(w - radius, 0)
        ..arcToPoint(Offset(w, radius),
            radius: Radius.circular(radius), clockwise: true)
        ..lineTo(w, h);
    } else if (!isTop && isLeft) {
      path
        ..moveTo(0, 0)
        ..lineTo(0, h - radius)
        ..arcToPoint(Offset(radius, h),
            radius: Radius.circular(radius), clockwise: false)
        ..lineTo(w, h);
    } else {
      path
        ..moveTo(0, h)
        ..lineTo(w - radius, h)
        ..arcToPoint(Offset(w, h - radius),
            radius: Radius.circular(radius), clockwise: false)
        ..lineTo(w, 0);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
