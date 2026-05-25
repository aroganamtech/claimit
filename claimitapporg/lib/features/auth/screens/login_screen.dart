import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../../../shared/widgets/loading_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final input = _controller.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter your mobile number or email')),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.sendOtp(input);

    if (!mounted) return;

    if (success) {
      context.push('/auth/otp', extra: {
        'phone': input,
        'isRegistration': false,
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.error ?? 'Failed to send OTP'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Watermark image — top-right
          Positioned(
            top: -size.height * 0.05,
            right: -size.width * 0.10,
            child: Opacity(
              opacity: 0.45,
              child: Image.asset(
                'assets/images/watermark_c.png',
                width: size.width * 0.65,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
          // Watermark image — bottom-left (rotated)
          Positioned(
            bottom: -size.height * 0.02,
            left: -size.width * 0.10,
            child: Transform.rotate(
              angle: -0.15,
              child: Opacity(
                opacity: 0.35,
                child: Image.asset(
                  'assets/images/watermark_c.png',
                  width: size.width * 0.58,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),

                  _HomeLogoWidget(),

                  // Responsive gap — 8% of screen height instead of fixed 106 px.
                  SizedBox(height: size.height * 0.08),

                  const Text(
                    'Log in here',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    "Welcome back you've been missed!",
                    style: TextStyle(
                      fontSize: 15,
                      color: Color(0xFF2563EB),
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 36),

                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Enter your mobile number or Email',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF374151),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: _controller,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'Email / Phone',
                      hintStyle: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 15,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: Color(0xFF2563EB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: Color(0xFF2563EB), width: 2),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Consumer<AuthProvider>(
                    builder: (context, auth, _) => LoadingButton(
                      isLoading: auth.isLoading,
                      onPressed: _sendOtp,
                      label: 'Send OTP',
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'New to Claimit -  ',
                        style:
                            TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                      ),
                      GestureDetector(
                        onTap: () => context.go('/auth/register'),
                        child: const Text(
                          'Signup',
                          style: TextStyle(
                            color: Color(0xFF374151),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 52),

                  const Text(
                    'Or continue with',
                    style: TextStyle(
                      color: Color(0xFF2563EB),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _SocialButton(
                        onTap: () {},
                        child: const Text(
                          'G',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4285F4),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      _SocialButton(
                        onTap: () {},
                        child: const Icon(
                          Icons.facebook,
                          size: 28,
                          color: Color(0xFF1877F2),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
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

class _SocialButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  const _SocialButton({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Center(child: child),
      ),
    );
  }
}
