import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../../../shared/widgets/loading_button.dart';

// 6 OTP boxes — matches the 6-digit OTP the backend generates
const int _kOtpLength = 6;
const int _kResendSeconds = 30;

class OtpScreen extends StatefulWidget {
  final String phone;
  final bool isRegistration;

  const OtpScreen({
    super.key,
    required this.phone,
    required this.isRegistration,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  // ── Initialised in initState so hot-reload recreates them at the
  //    correct length when _kOtpLength changes.
  late List<FocusNode> _focusNodes;
  late List<TextEditingController> _boxControllers;

  String _otp = '';
  int _seconds = _kResendSeconds;
  Timer? _timer;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _focusNodes = List.generate(_kOtpLength, (_) => FocusNode());
    _boxControllers =
        List.generate(_kOtpLength, (_) => TextEditingController());
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[0].requestFocus();
    });
  }

  void _startTimer() {
    setState(() {
      _seconds = _kResendSeconds;
      _canResend = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_seconds == 0) {
        setState(() => _canResend = true);
        t.cancel();
      } else {
        setState(() => _seconds--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final n in _focusNodes) {
      n.dispose();
    }
    for (final c in _boxControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onBoxChanged(String value, int index) {
    if (value.length == 1) {
      if (index < _kOtpLength - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    final combined = _boxControllers.map((c) => c.text).join();
    setState(() => _otp = combined);

    if (combined.length == _kOtpLength) {
      _verifyOtp();
    }
  }

  Future<void> _verifyOtp() async {
    if (_otp.length != _kOtpLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the complete OTP')),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.verifyOtp(widget.phone, _otp);

    if (!mounted) return;

    if (success) {
      context.go('/auth/success');
    } else {
      for (final c in _boxControllers) {
        c.clear();
      }
      setState(() => _otp = '');
      _focusNodes[0].requestFocus();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.error ?? 'Invalid OTP'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _resendOtp() async {
    if (!_canResend) return;
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.sendOtp(widget.phone);
    if (!mounted) return;
    if (success) {
      _startTimer();
      for (final c in _boxControllers) {
        c.clear();
      }
      setState(() => _otp = '');
      _focusNodes[0].requestFocus();
    }
  }

  String get _maskedPhone {
    final p = widget.phone;
    if (p.length > 5) {
      return '${p.substring(0, p.length - 5)}xxxxx';
    }
    return p;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 32),

              _HomeLogoWidget(),

              const SizedBox(height: 36),

              const Text(
                'Verify OTP',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A),
                ),
              ),

              const SizedBox(height: 10),

              Text(
                'Enter the OTP sent to +91 $_maskedPhone',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF2563EB),
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 40),

              // ── 6 OTP boxes — responsive width ─────────────────────────
              LayoutBuilder(
  builder: (context, constraints) {
    final boxWidth =
        (constraints.maxWidth - (_kOtpLength * 10)) /
            _kOtpLength;
    final clampedWidth = boxWidth.clamp(36.0, 52.0);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_kOtpLength, (i) {
        final filled = i < _boxControllers.length &&
            _boxControllers[i].text.isNotEmpty;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: clampedWidth,
          height: clampedWidth, // 🟢 Make it a perfect square
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: filled
                  ? const Color(0xFF2563EB)
                  : const Color(0xFFCBD5E1),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          // 🟢 Center the inner block vertically and horizontally
          child: Center(
            child: TextField(
              controller: _boxControllers[i],
              focusNode: _focusNodes[i],
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              maxLength: 1,
              showCursor: false,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
              decoration: const InputDecoration(
                counterText: '',
                contentPadding: EdgeInsets.zero, // Clears layout side-padding
                border: InputBorder.none,
                isDense: true, // Forces text bounds to collapse tightly to the digit
              ),
              onChanged: (v) => _onBoxChanged(v, i),
            ),
          ),
        );
      }),
    );
  },
),
              const SizedBox(height: 20),

              Text(
                'Time remaining : 0:${_seconds.toString().padLeft(2, '0')} sec',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                ),
              ),

              const SizedBox(height: 20),

              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Color(0xFF2563EB),
                  shape: BoxShape.circle,
                ),
              ),

              const SizedBox(height: 28),

              Consumer<AuthProvider>(
                builder: (context, auth, _) => LoadingButton(
                  isLoading: auth.isLoading,
                  onPressed: _verifyOtp,
                  label: 'Verify OTP',
                ),
              ),

              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Didn't receive the OTP? ",
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                  ),
                  GestureDetector(
                    onTap: _canResend ? _resendOtp : null,
                    child: Text(
                      'Resend',
                      style: TextStyle(
                        color: _canResend
                            ? const Color(0xFF374151)
                            : const Color(0xFF9CA3AF),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeLogoWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/home_main_logo.png',
      height: 64,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/icons/main_icon.png',
            width: 48,
            height: 48,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
          const Text(
            'claimit',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1565C0),
            ),
          ),
        ],
      ),
    );
  }
}
