import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BillReaderIntroScreen extends StatelessWidget {
  const BillReaderIntroScreen({super.key});

  static const _blue = Color(0xFF1565C0);
  static const _lightBlue = Color(0xFFE3F2FD);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _blue, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Bill Reader',
          style: TextStyle(
            color: _blue,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        top: false,          // AppBar handles top inset
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subtitle
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Text(
              'scan your bill to apply your discount or cashback',
              style: TextStyle(
                color: _blue,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // Scan card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE0E0E0)),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _lightBlue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.camera_alt_outlined, color: _blue, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scan the Bill',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Scan your shop bill using your phone camera',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Demo video label
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'How to Scan your Bill - Demo Video',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Demo video placeholder
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Placeholder background
                    Container(
                      color: const Color(0xFFF5F5F5),
                      child: Image.network(
                        'https://images.unsplash.com/photo-1601784551446-20c9e07cdbdb?w=700&q=80',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFFE8EAF6),
                          child: const Icon(Icons.receipt_long_rounded,
                              size: 80, color: Color(0xFF9FA8DA)),
                        ),
                      ),
                    ),
                    // Play button overlay
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 40),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Scan Bill button — bottom padding accounts for home bar on tall phones.
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => context.push('/bill-reader/scanner'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Scan Bill',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
        ),       // Column
      ),         // SafeArea
    );
  }
}
