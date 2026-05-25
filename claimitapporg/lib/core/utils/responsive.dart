/// Responsive scaling utilities — Flutter equivalent of React Native's
/// moderateScale / verticalScale / horizontalScale.
///
/// Usage:
///   import 'package:claimit/core/utils/responsive.dart';
///
///   // In a widget's build():
///   final r = Responsive.of(context);
///   Container(
///     width:  r.w(90),          // 90% of screen width
///     height: r.vs(200),        // vertically scaled from 800 dp baseline
///     child: Text('Hi', style: TextStyle(fontSize: r.sp(16))),
///   );
///
/// OR use the static helpers after calling Responsive.init(context):
///   fontSize: R.sp(16)
///   height:   R.vs(48)
///   padding:  EdgeInsets.all(R.ms(16))

import 'package:flutter/widgets.dart';

class Responsive {
  /// Design baseline — matches the Figma frame size your team used.
  static const double _designWidth  = 360.0;
  static const double _designHeight = 800.0;

  final double _width;
  final double _height;

  const Responsive._({required double width, required double height})
      : _width  = width,
        _height = height;

  /// Obtain a [Responsive] instance scoped to [context].
  factory Responsive.of(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Responsive._(width: size.width, height: size.height);
  }

  // ── Percentage helpers ────────────────────────────────────────────────────

  /// Returns [percent]% of the screen width.
  /// e.g. w(90) → 324 on a 360-dp phone, 370 on a 412-dp phone.
  double w(double percent) => _width * percent / 100;

  /// Returns [percent]% of the screen height.
  double h(double percent) => _height * percent / 100;

  // ── Proportional scale ────────────────────────────────────────────────────

  /// Horizontally scale a value relative to the design width baseline.
  double hs(double size) => size * (_width / _designWidth);

  /// Vertically scale a value relative to the design height baseline.
  double vs(double size) => size * (_height / _designHeight);

  /// Moderate scale — scales less aggressively than [hs].
  /// [factor] 0.5 = halfway between no-scale and full-scale (recommended).
  double ms(double size, [double factor = 0.5]) =>
      size + (hs(size) - size) * factor;

  // ── Font size ─────────────────────────────────────────────────────────────

  /// Responsive font size — moderately scaled so text is never too small or
  /// too large across phones with different display densities.
  double sp(double size) => ms(size, 0.3);

  // ── Static singleton ──────────────────────────────────────────────────────
  // Allows R.sp(16) shorthand after R.init(context) in the root widget.

  static late Responsive _instance;

  /// Call once in your root widget's build() to enable the [R] shorthand.
  static void init(BuildContext context) =>
      _instance = Responsive.of(context);

  static double Function(double)         get sp  => _instance.sp;
  static double Function(double)         get hs  => _instance.hs;
  static double Function(double)         get vs  => _instance.vs;
  static double Function(double, [double]) get ms => _instance.ms;
  static double Function(double)         get w   => _instance.w;
  static double Function(double)         get h   => _instance.h;
}

/// Short alias — use as `R.sp(16)`, `R.vs(48)`, `R.w(90)` etc.
typedef R = Responsive;
