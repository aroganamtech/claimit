import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/loading_button.dart';

/// Shown after Facebook login when phone number or email is missing.
/// The user must fill both so they can log in via mobile OTP or email OTP later.
class SocialCompleteProfileScreen extends StatefulWidget {
  const SocialCompleteProfileScreen({super.key});

  @override
  State<SocialCompleteProfileScreen> createState() =>
      _SocialCompleteProfileScreenState();
}

class _SocialCompleteProfileScreenState
    extends State<SocialCompleteProfileScreen> {
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill email if Facebook already gave us one
    final user = context.read<AuthProvider>().user;
    if (user?.email != null && user!.email!.isNotEmpty) {
      _emailController.text = user.email!;
    }
    if (user?.phone.isNotEmpty == true) {
      _phoneController.text = user!.phone;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  bool get _emailAlreadySet {
    final user = context.read<AuthProvider>().user;
    return user?.email != null && user!.email!.isNotEmpty;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();

    setState(() => _submitting = true);

    final authProvider = context.read<AuthProvider>();
    final apiClient = authProvider.apiClientForSocial;

    bool ok = true;

    // 1. Save phone
    try {
      final res = await apiClient.post(
        AppConstants.updatePhone,
        data: {'phone': phone},
      );
      if (res.statusCode != 200 && res.statusCode != 201) {
        ok = false;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  (res.data is Map && res.data['detail'] != null)
                      ? res.data['detail'].toString()
                      : 'Failed to save phone number'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      ok = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }

    // 2. Save email (if not already present)
    if (ok && !_emailAlreadySet) {
      try {
        final res = await apiClient.post(
          AppConstants.updateProfile,
          data: {'email': email},
        );
        if (res.statusCode != 200 && res.statusCode != 201) {
          ok = false;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    (res.data is Map && res.data['detail'] != null)
                        ? res.data['detail'].toString()
                        : 'Failed to save email'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        ok = false;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(e.toString()), backgroundColor: Colors.red),
          );
        }
      }
    }

    if (!mounted) return;
    setState(() => _submitting = false);

    if (ok) {
      // Update local user model so needsProfileCompletion becomes false
      authProvider.markProfileCompleted(
        phone: phone,
        email: _emailAlreadySet ? null : email,
      );
      context.go('/auth/success');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final emailLocked = _emailAlreadySet;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Watermark top-right
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
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    _HomeLogoWidget(),
                    SizedBox(height: size.height * 0.06),

                    const Text(
                      'Complete Your Profile',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'Add your mobile number and email so you can log in with OTP next time.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF2563EB),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    const SizedBox(height: 36),

                    // ── Mobile number ─────────────────────────────────────
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Mobile Number',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF374151),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: _inputDecoration('Enter your mobile number'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Mobile number is required';
                        }
                        final digits = v.trim().replaceAll(RegExp(r'\D'), '');
                        if (digits.length < 10) {
                          return 'Enter a valid mobile number';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // ── Email ─────────────────────────────────────────────
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Email',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF374151),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      readOnly: emailLocked,
                      decoration: _inputDecoration(
                        'Enter your email',
                        locked: emailLocked,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Email is required';
                        }
                        if (!v.contains('@') || !v.contains('.')) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    if (emailLocked)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Email already provided by Facebook',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF6B7280)),
                          ),
                        ),
                      ),

                    const SizedBox(height: 32),

                    LoadingButton(
                      isLoading: _submitting,
                      onPressed: _submit,
                      label: 'Save & Continue',
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, {bool locked = false}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 15),
      filled: true,
      fillColor: locked ? const Color(0xFFF9FAFB) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      suffixIcon: locked
          ? const Icon(Icons.lock_outline, size: 18, color: Color(0xFF9CA3AF))
          : null,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF2563EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 2),
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
