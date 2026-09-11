import 'package:flutter/material.dart';

import '../models/privilege_models.dart';
import '../services/privilege_service.dart';
import '../widgets/privilege_common.dart';
import 'privilege_approved_screen.dart' show PrivilegeTime;

// ─────────────────────────────────────────────────────────────────────────────
// My Privileges — every discount this user has actually had approved.
//
// This is what replaces the "Scan Final Bill" button on the approved screen:
// Ramesh asked for history instead. Admin sees the same records from the web
// panel, so a shop disputing a discount can be checked against a real log.
//
// Approved passes only. An issued-but-never-approved pass is one the user
// never benefited from, and listing it would make this look like a record of
// discounts received when it isn't.
// ─────────────────────────────────────────────────────────────────────────────

class PrivilegeHistoryScreen extends StatefulWidget {
  const PrivilegeHistoryScreen({super.key});

  @override
  State<PrivilegeHistoryScreen> createState() => _PrivilegeHistoryScreenState();
}

class _PrivilegeHistoryScreenState extends State<PrivilegeHistoryScreen> {
  List<PrivilegePass> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await PrivilegeService.instance.fetchHistory();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPrivBg,
      appBar: const PrivilegeHeader(),
      bottomNavigationBar: const PrivilegeBottomBar(current: 2),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 90),
                        Icon(Icons.local_offer_outlined,
                            size: 46, color: kPrivMuted),
                        SizedBox(height: 10),
                        Center(
                          child: Text('No privileges used yet',
                              style:
                                  TextStyle(fontSize: 14, color: kPrivMuted)),
                        ),
                        SizedBox(height: 4),
                        Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              'Discounts you have approved at a counter will '
                              'appear here.',
                              textAlign: TextAlign.center,
                              style:
                                  TextStyle(fontSize: 12.5, color: kPrivMuted),
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
                      itemCount: _items.length,
                      itemBuilder: (_, i) => _HistoryCard(pass: _items[i]),
                    ),
            ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final PrivilegePass pass;
  const _HistoryCard({required this.pass});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kPrivLine),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text('${pass.percentText}%',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: kPrivGreen)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(pass.partnerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: kPrivInk)),
                if (pass.partnerArea.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(pass.partnerArea,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: kPrivMuted)),
                ],
                const SizedBox(height: 4),
                Text(PrivilegeTime.pretty(pass.approvedAt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: kPrivMuted)),
                const SizedBox(height: 2),
                Text('Ref : ${pass.reference}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: kPrivBlue)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
