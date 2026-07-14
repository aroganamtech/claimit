import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/payment_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shared widgets used by both posting flows:
//   - Local Finds business registration (local_find_add_listing_flow.dart)
//   - Local Classifieds self-posting (add_post_flow.dart)
// ─────────────────────────────────────────────────────────────────────────────

/// Plain bordered text field, same look across both flows.
class ListingField extends StatelessWidget {
  const ListingField({
    super.key,
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        suffixIcon: suffixIcon,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
        ),
      ),
    );
  }
}

/// Multi-line description field that enforces a max WORD count (not
/// character count) — matches the PDF spec's "up to 25 words".
class WordLimitedField extends StatefulWidget {
  const WordLimitedField({
    super.key,
    required this.controller,
    required this.hint,
    this.maxWords = 25,
  });

  final TextEditingController controller;
  final String hint;
  final int maxWords;

  @override
  State<WordLimitedField> createState() => _WordLimitedFieldState();
}

class _WordLimitedFieldState extends State<WordLimitedField> {
  int _wordCount = 0;

  @override
  void initState() {
    super.initState();
    _wordCount = _count(widget.controller.text);
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  int _count(String text) =>
      text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;

  void _onChanged() {
    final words = widget.controller.text.trim().split(RegExp(r'\s+'));
    if (words.length > widget.maxWords && widget.controller.text.isNotEmpty) {
      // Trim back down to the word limit instead of blocking input outright.
      final capped = words.take(widget.maxWords).join(' ');
      final sel = capped.length;
      widget.controller.value = TextEditingValue(
        text: capped,
        selection: TextSelection.collapsed(offset: sel),
      );
    }
    setState(() => _wordCount = _count(widget.controller.text));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ListingField(controller: widget.controller, hint: widget.hint, maxLines: 4),
        Padding(
          padding: const EdgeInsets.only(top: 4, right: 4),
          child: Text(
            '$_wordCount / ${widget.maxWords} words',
            style: TextStyle(
              fontSize: 11,
              color: _wordCount >= widget.maxWords
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF94A3B8),
            ),
          ),
        ),
      ],
    );
  }
}

class ListingPrimaryButton extends StatelessWidget {
  const ListingPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.loading = false,
  });
  final String label;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1D4ED8),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: Colors.white),
              )
            : Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
      ),
    );
  }
}

/// Section heading used at the top of every step ("Business Name",
/// "Contact Details", ...).
class ListingStepTitle extends StatelessWidget {
  const ListingStepTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF2563EB),
        fontWeight: FontWeight.bold,
        fontSize: 15,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Payment step — creates a Cashfree payment link for [amount], opens
// Cashfree's hosted checkout in the browser, then polls the backend until
// it's marked PAID. Calls [onPaid] exactly once when that happens.
// ─────────────────────────────────────────────────────────────────────────────

class PaymentStep extends StatefulWidget {
  const PaymentStep({
    super.key,
    required this.amount,
    required this.purpose,
    required this.onPaid,
  });

  final double amount;
  final String purpose;
  final VoidCallback onPaid;

  @override
  State<PaymentStep> createState() => _PaymentStepState();
}

enum _PayState { idle, creatingLink, awaitingPayment, checking, paid, error }

class _PaymentStepState extends State<PaymentStep> {
  _PayState _state = _PayState.idle;
  String? _linkId;
  String? _error;
  Timer? _pollTimer;
  int _pollAttempts = 0;

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _startPayment() async {
    setState(() {
      _state = _PayState.creatingLink;
      _error = null;
    });
    final link = await PaymentService.instance.createLink(
      amount: widget.amount,
      purpose: widget.purpose,
    );
    if (!mounted) return;
    if (link == null) {
      setState(() {
        _state = _PayState.error;
        _error =
            "Couldn't start payment. Payments may not be configured yet — "
            'please try again shortly.';
      });
      return;
    }
    _linkId = link.linkId;
    final opened = await PaymentService.instance.openCheckout(link.url);
    if (!mounted) return;
    if (!opened) {
      setState(() {
        _state = _PayState.error;
        _error = 'Could not open the payment page.';
      });
      return;
    }
    setState(() => _state = _PayState.awaitingPayment);
    _pollAttempts = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  Future<void> _poll() async {
    if (_linkId == null || !mounted) return;
    _pollAttempts++;
    final status = await PaymentService.instance.checkStatus(_linkId!);
    if (!mounted) return;
    if (status == 'PAID') {
      _pollTimer?.cancel();
      setState(() => _state = _PayState.paid);
      widget.onPaid();
    } else if (status == 'EXPIRED' || status == 'CANCELLED') {
      _pollTimer?.cancel();
      setState(() {
        _state = _PayState.error;
        _error = 'Payment was not completed. Please try again.';
      });
    } else if (_pollAttempts >= 40) {
      // ~2 minutes of polling — stop and let the user check manually.
      _pollTimer?.cancel();
    }
  }

  Future<void> _checkNow() async {
    if (_linkId == null) return;
    setState(() => _state = _PayState.checking);
    final status = await PaymentService.instance.checkStatus(_linkId!);
    if (!mounted) return;
    if (status == 'PAID') {
      setState(() => _state = _PayState.paid);
      widget.onPaid();
    } else {
      setState(() => _state = _PayState.awaitingPayment);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Amount  ',
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
            Text(
              '₹ ${widget.amount.toStringAsFixed(0)}/-',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(widget.purpose,
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
        const SizedBox(height: 20),

        if (_state == _PayState.awaitingPayment) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Waiting for payment to complete in your browser…',
                    style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _checkNow,
            child: const Text("I've paid — check now"),
          ),
        ],

        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Text(
              _error!,
              style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
            ),
          ),
          const SizedBox(height: 12),
        ],

        const Spacer(),
        ListingPrimaryButton(
          label: _state == _PayState.awaitingPayment
              ? 'Open Payment Page Again'
              : 'Pay ₹${widget.amount.toStringAsFixed(0)}',
          loading: _state == _PayState.creatingLink || _state == _PayState.checking,
          onTap: _startPayment,
        ),
      ],
    );
  }
}
