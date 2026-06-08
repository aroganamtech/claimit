// Privacy Policy, Terms & Conditions, and Help & Support screens.
//
// These render the same content that's published as public pages on the
// Claimit website (see claimit_web_org/frontend — required for the Play
// Store "Privacy Policy URL" field). Keep both copies in sync if you edit
// the source document.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/legal_content.dart';
import '../../../core/constants/app_constants.dart';

const _kInk = Color(0xFF1A1A2E);
const _kAccent = Color(0xFF2563EB);
const _kBg = Color(0xFFF5F5F5);

/// Shared scaffold for all static legal/support screens.
class _LegalScaffold extends StatelessWidget {
  final String title;
  final List<LegalSection> sections;
  final String? subtitle;
  final String onlineUrl;

  const _LegalScaffold({
    required this.title,
    required this.sections,
    required this.onlineUrl,
    this.subtitle,
  });

  Future<void> _openOnline(BuildContext context) async {
    final uri = Uri.parse(onlineUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $onlineUrl')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 26, color: _kInk),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _kInk,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'View online',
            icon: const Icon(Icons.open_in_new_rounded, color: _kAccent),
            onPressed: () => _openOnline(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Claimit',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _kAccent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle ?? legalEffectiveDate,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...sections.map((s) => _SectionCard(section: s)),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final LegalSection section;
  const _SectionCard({required this.section});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.heading,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _kInk,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            section.body,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Public screens (registered in app_router.dart) ───────────────────────────

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalScaffold(
      title: 'Privacy Policy',
      sections: privacyPolicySections,
      onlineUrl: AppConstants.privacyPolicyUrl,
    );
  }
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalScaffold(
      title: 'Terms & Conditions',
      sections: termsSections,
      onlineUrl: AppConstants.termsUrl,
    );
  }
}

class RefundPolicyScreen extends StatelessWidget {
  const RefundPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalScaffold(
      title: 'Refund Policy',
      sections: refundPolicySections,
      onlineUrl: AppConstants.refundPolicyUrl,
    );
  }
}

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalScaffold(
      title: 'Help & Support',
      subtitle: 'We usually reply within 1 business day.',
      sections: supportSections,
      onlineUrl: AppConstants.supportUrl,
    );
  }
}
