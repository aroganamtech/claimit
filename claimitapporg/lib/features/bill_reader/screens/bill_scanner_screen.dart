import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BillScannerScreen — live camera viewfinder with real flash + capture
// ─────────────────────────────────────────────────────────────────────────────

class BillScannerScreen extends StatefulWidget {
  const BillScannerScreen({super.key});

  @override
  State<BillScannerScreen> createState() => _BillScannerScreenState();
}

class _BillScannerScreenState extends State<BillScannerScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const _blue = Color(0xFF1565C0);

  CameraController? _camCtrl;
  bool _cameraReady = false;
  bool _torchOn = false;
  bool _capturing = false;
  String? _camError;

  late AnimationController _scanLineCtrl;
  late Animation<double> _scanLineAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _scanLineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scanLineAnim = Tween<double>(begin: 0, end: 1).animate(_scanLineCtrl);

    _initCamera();
  }

  // ── Camera lifecycle ────────────────────────────────────────────────────────

  Future<void> _initCamera() async {
    // Request camera permission
    final status = await Permission.camera.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      if (mounted) {
        setState(() => _camError =
            'Camera permission denied.\nPlease enable it in App Settings.');
      }
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _camError = 'No camera found on device.');
        return;
      }

      // Use back camera
      final backCam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final ctrl = CameraController(
        backCam,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await ctrl.initialize();

      if (!mounted) {
        ctrl.dispose();
        return;
      }

      setState(() {
        _camCtrl = ctrl;
        _cameraReady = true;
      });
    } catch (e) {
      if (mounted) setState(() => _camError = 'Camera error: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_camCtrl == null || !_cameraReady) return;
    if (state == AppLifecycleState.inactive) {
      _camCtrl!.dispose();
      setState(() => _cameraReady = false);
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanLineCtrl.dispose();
    _camCtrl?.dispose();
    super.dispose();
  }

  // ── Flash toggle ────────────────────────────────────────────────────────────

  Future<void> _toggleFlash() async {
    if (_camCtrl == null || !_cameraReady) return;
    try {
      final next = !_torchOn;
      await _camCtrl!.setFlashMode(
        next ? FlashMode.torch : FlashMode.off,
      );
      setState(() => _torchOn = next);
    } catch (_) {}
  }

  // ── Capture + navigate ──────────────────────────────────────────────────────

  Future<void> _captureAndScan() async {
    if (_capturing) return;
    setState(() => _capturing = true);

    try {
      // Turn off torch before capture so it doesn't blow out the image
      if (_torchOn) {
        await _camCtrl?.setFlashMode(FlashMode.off);
        setState(() => _torchOn = false);
      }

      final file = await _camCtrl!.takePicture();
      if (!mounted) return;
      _navigateToScan(file.path);
    } catch (e) {
      if (mounted) {
        setState(() => _capturing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Capture failed: $e')),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    final img = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (img != null && mounted) {
      _navigateToScan(img.path);
    }
  }

  void _navigateToScan(String imagePath) {
    context.push('/bill-reader/scanning', extra: {'imagePath': imagePath});
  }

  // ── Build ───────────────────────────────────────────────────────────────────

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
          'Bill Scanner',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: false,
        actions: [
          // Flash toggle — no 3-dot menu
          IconButton(
            icon: Icon(
              _torchOn
                  ? Icons.flashlight_on_rounded
                  : Icons.flashlight_off_rounded,
              color: _torchOn ? Colors.yellow : Colors.white,
              size: 28,
            ),
            onPressed: _toggleFlash,
            tooltip: _torchOn ? 'Flash Off' : 'Flash On',
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Camera preview ─────────────────────────────────────────────
          Positioned.fill(child: _buildCameraView()),

          // ── Dark overlay with transparent scan window ──────────────────
          Positioned.fill(child: _ScanOverlay()),

          // ── Corner brackets + scan line ────────────────────────────────
          Center(
            child: SizedBox(
              width: 270,
              height: 360,
              child: Stack(
                children: [
                  ..._buildCorners(),
                  // Animated scan line
                  AnimatedBuilder(
                    animation: _scanLineAnim,
                    builder: (_, __) => Positioned(
                      top: _scanLineAnim.value * 340,
                      left: 14,
                      right: 14,
                      child: Container(
                        height: 2.5,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            _blue.withOpacity(0),
                            _blue.withOpacity(0.95),
                            _blue.withOpacity(0),
                          ]),
                          boxShadow: [
                            BoxShadow(
                              color: _blue.withOpacity(0.5),
                              blurRadius: 4,
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Hint text ──────────────────────────────────────────────────
          const Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Text(
              'Point camera at the bill\nAlign total amount inside frame',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),

          // ── Gallery button ─────────────────────────────────────────────
          Positioned(
            bottom: 110,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _capturing ? null : _pickFromGallery,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.4), width: 1),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.photo_library_outlined,
                          color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text('Upload from Gallery',
                          style:
                              TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Scan Bill button ───────────────────────────────────────────
          Positioned(
            bottom: 36,
            left: 24,
            right: 24,
            child: SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: (_cameraReady && !_capturing)
                    ? _captureAndScan
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  disabledBackgroundColor: _blue.withOpacity(0.5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28)),
                  elevation: 0,
                ),
                child: _capturing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Scan Bill',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Camera view widget ──────────────────────────────────────────────────────

  Widget _buildCameraView() {
    if (_camError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.camera_alt_outlined,
                  color: Colors.white38, size: 64),
              const SizedBox(height: 16),
              Text(
                _camError!,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: Colors.white60, fontSize: 14),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  setState(() => _camError = null);
                  _initCamera();
                },
                child: const Text('Retry',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    if (!_cameraReady || _camCtrl == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white54),
      );
    }

    return ClipRect(
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _camCtrl!.value.previewSize!.height,
            height: _camCtrl!.value.previewSize!.width,
            child: CameraPreview(_camCtrl!),
          ),
        ),
      ),
    );
  }

  // ── Corner brackets ─────────────────────────────────────────────────────────

  List<Widget> _buildCorners() {
    const size = 32.0;
    const thickness = 4.0;
    const color = Color(0xFF42A5F5);
    const radius = 6.0;

    Widget corner({bool top = true, bool left = true}) => Positioned(
          top: top ? 0 : null,
          bottom: top ? null : 0,
          left: left ? 0 : null,
          right: left ? null : 0,
          child: SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _CornerPainter(
                  isTop: top,
                  isLeft: left,
                  color: color,
                  thickness: thickness,
                  radius: radius),
            ),
          ),
        );

    return [
      corner(top: true, left: true),
      corner(top: true, left: false),
      corner(top: false, left: true),
      corner(top: false, left: false),
    ];
  }
}

// ── Semi-transparent overlay with a transparent cut-out ─────────────────────

class _ScanOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _OverlayPainter());
  }
}

class _OverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const frameW = 270.0;
    const frameH = 360.0;
    final frameL = (size.width - frameW) / 2;
    final frameT = (size.height - frameH) / 2;
    final frameRect =
        RRect.fromLTRBR(frameL, frameT, frameL + frameW, frameT + frameH,
            const Radius.circular(8));

    final paint = Paint()..color = Colors.black.withOpacity(0.55);
    final fullPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final holePath = Path()..addRRect(frameRect);
    final overlay = Path.combine(PathOperation.difference, fullPath, holePath);
    canvas.drawPath(overlay, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Corner bracket painter ───────────────────────────────────────────────────

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
