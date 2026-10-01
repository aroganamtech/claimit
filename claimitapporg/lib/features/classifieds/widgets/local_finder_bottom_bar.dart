import 'package:flutter/material.dart';

import '../../../core/widgets/claimit_bottom_bar.dart';

/// Kept as a name so the Local Finder screens' existing imports and call sites
/// do not have to change, but it is no longer a copy of anything: it renders
/// the home page's own bar, [ClaimitBottomBar].
///
/// The earlier version of this file was a hand-made lookalike, and it drifted —
/// different height, different blue, a gold circle the dashboard does not have.
/// There is now exactly one bar in the app.
class LocalFinderBottomBar extends StatelessWidget {
  const LocalFinderBottomBar({super.key});

  @override
  Widget build(BuildContext context) => const ClaimitBottomBar();
}
