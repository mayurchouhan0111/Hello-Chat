import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

/// Available visual styles for the SVG in-between page transition.
enum SvgTransitionStyle {
  /// Cyber portal with rotating vector rings, golden starburst, and cyan tech marks.
  cyberPortal,

  /// Luminous golden diamond flare burst with high-velocity light streak wipe.
  goldenFlare,

  /// Angled cyber blade shutter wipe with neon borders.
  diagonalWipe,
}

/// A high-performance, 60fps vector SVG animated in-between transition widget.
///
/// Complies with Hello Chat Flutter architecture guidelines:
/// - Wrapped in [RepaintBoundary] to isolate animating raster/vector layers.
/// - Pure build method without heavy allocation on each tick.
/// - Gracefully coordinates entry, peak vector flash, and smooth reveal.
class SvgPageTransition extends StatelessWidget {
  const SvgPageTransition({
    super.key,
    required this.animation,
    required this.child,
    this.secondaryAnimation,
    this.style = SvgTransitionStyle.cyberPortal,
  });

  /// The primary transition animation (0.0 -> 1.0).
  final Animation<double> animation;

  /// The secondary transition animation (when another route is pushed on top).
  final Animation<double>? secondaryAnimation;

  /// The destination child screen.
  final Widget child;

  /// Visual theme style for the vector SVG transition.
  final SvgTransitionStyle style;

  @override
  Widget build(BuildContext context) {
    // Curved animation drivers
    final enterCurve = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    final portalCurve = CurvedAnimation(
      parent: animation,
      curve: Curves.easeInOutQuart,
    );

    // 1. Destination Screen Scale & Fade Animation
    // Starts subtly scaling up (0.94 -> 1.0) and fades in after midpoint
    final childScale = Tween<double>(begin: 0.94, end: 1.0).animate(enterCurve);
    final childOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 35),
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 65),
    ]).animate(animation);

    // 2. Secondary animation (when a new route is pushed on top of this one)
    Widget transformedChild = child;
    if (secondaryAnimation != null) {
      final secondaryScale = Tween<double>(begin: 1.0, end: 0.96).animate(
        CurvedAnimation(parent: secondaryAnimation!, curve: Curves.easeInOutCubic),
      );
      final secondaryOpacity = Tween<double>(begin: 1.0, end: 0.75).animate(
        CurvedAnimation(parent: secondaryAnimation!, curve: Curves.easeInOutCubic),
      );
      transformedChild = FadeTransition(
        opacity: secondaryOpacity,
        child: ScaleTransition(
          scale: secondaryScale,
          child: child,
        ),
      );
    }

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;

        // If animation is fully completed, render only the child (zero overlay overhead)
        if (t >= 1.0) {
          return child;
        }

        // If animation is at zero and dismissed, render nothing or initial state
        if (t <= 0.0) {
          return const SizedBox.shrink();
        }

        return RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Destination Page (Settling into place) ────────
              FadeTransition(
                opacity: childOpacity,
                child: ScaleTransition(
                  scale: childScale,
                  child: transformedChild,
                ),
              ),

              // ── In-Between SVG Transition Overlay ────────────
              // Block touches during flight, pass through when done
              IgnorePointer(
                ignoring: t >= 0.9,
                child: _buildSvgOverlay(context, t, portalCurve.value),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSvgOverlay(BuildContext context, double t, double curvedT) {
    // Overlay opacity: ramps up rapidly (0.0 -> 0.4), holds briefly (0.4 -> 0.6), dissolves (0.6 -> 1.0)
    double overlayOpacity;
    if (t < 0.4) {
      overlayOpacity = (t / 0.4).clamp(0.0, 1.0);
    } else if (t < 0.6) {
      overlayOpacity = 1.0;
    } else {
      overlayOpacity = ((1.0 - t) / 0.4).clamp(0.0, 1.0);
    }

    // Dynamic Backdrop Curtain (Dark luxury cyber gradient)
    final backdropOpacity = (overlayOpacity * 0.92).clamp(0.0, 0.95);

    // Vector Portal Scale & Rotation dynamics
    // Portal enters from scale 0.4 -> expands to 2.2 -> blasts through camera
    final portalScale = 0.45 + (curvedT * 1.75);
    final portalRotation = curvedT * math.pi * 1.25; // 225 deg spin

    return Opacity(
      opacity: overlayOpacity,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          // 1. Dark Glass Cyber Backdrop with luminous edge vignette
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.1,
                colors: [
                  const Color(0xFF140D2B).withValues(alpha: backdropOpacity * 0.85),
                  const Color(0xFF070913).withValues(alpha: backdropOpacity),
                  const Color(0xFF030408).withValues(alpha: backdropOpacity),
                ],
                stops: const [0.0, 0.65, 1.0],
              ),
            ),
          ),

          // 2. Vector Shutter Blades (if diagonal wipe style)
          if (style == SvgTransitionStyle.diagonalWipe)
            _buildDiagonalWipeBlades(t),

          // 3. Central Animated Vector SVG Portal / Flare
          Center(
            child: Transform.rotate(
              angle: portalRotation,
              child: Transform.scale(
                scale: portalScale,
                child: SizedBox(
                  width: 320,
                  height: 320,
                  child: SvgPicture.string(
                    rawPortalSvg,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),

          // 4. Counter-Rotating Inner Diamond Shimmer (for enhanced 3D vector depth)
          Center(
            child: Transform.rotate(
              angle: -portalRotation * 1.5,
              child: Transform.scale(
                scale: (portalScale * 0.65).clamp(0.1, 1.8),
                child: SizedBox(
                  width: 160,
                  height: 160,
                  child: SvgPicture.string(
                    rawInnerDiamondSvg,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),

          // 5. Flash Burst at the Apex (t ≈ 0.48 - 0.58)
          if (t >= 0.42 && t <= 0.65)
            _buildApexLightBurst(t),
        ],
      ),
    );
  }

  /// Builds high-voltage flash burst at mid-transition apex
  Widget _buildApexLightBurst(double t) {
    // Peak at t = 0.50
    final flashStrength = 1.0 - ((t - 0.50).abs() / 0.12).clamp(0.0, 1.0);
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 0.75,
            colors: [
              Colors.white.withValues(alpha: 0.65 * flashStrength),
              const Color(0xFFFFE066).withValues(alpha: 0.40 * flashStrength),
              const Color(0xFF00F5D4).withValues(alpha: 0.20 * flashStrength),
              Colors.transparent,
            ],
            stops: const [0.0, 0.35, 0.7, 1.0],
          ),
        ),
      ),
    );
  }

  /// Builds diagonal cyber wipe blades
  Widget _buildDiagonalWipeBlades(double t) {
    final offset = (1.0 - t) * 1.2;
    return Transform.translate(
      offset: Offset(offset * 200, 0),
      child: SvgPicture.string(
        rawCyberBladeWipeSvg,
        fit: BoxFit.cover,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GoRouter & Navigator Route Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Creates a [CustomTransitionPage] using the animated SVG in-between transition.
///
/// Ideal for [GoRoute.pageBuilder]:
/// ```dart
/// GoRoute(
///   path: AppRoutes.leaderboard,
///   pageBuilder: (context, state) => buildSvgTransitionPage(
///     key: state.pageKey,
///     child: const LeaderboardScreen(),
///   ),
/// );
/// ```
CustomTransitionPage<T> buildSvgTransitionPage<T>({
  required LocalKey key,
  required Widget child,
  SvgTransitionStyle style = SvgTransitionStyle.cyberPortal,
  Duration duration = const Duration(milliseconds: 620),
  Duration reverseDuration = const Duration(milliseconds: 480),
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: reverseDuration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SvgPageTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        style: style,
        child: child,
      );
    },
  );
}

/// A standard [PageRouteBuilder] using the animated SVG in-between transition.
///
/// Ideal for direct imperative navigation:
/// ```dart
/// Navigator.of(context).push(SvgPageRoute(builder: (_) => const MyScreen()));
/// ```
class SvgPageRoute<T> extends PageRouteBuilder<T> {
  SvgPageRoute({
    required WidgetBuilder builder,
    super.settings,
    this.style = SvgTransitionStyle.cyberPortal,
    Duration duration = const Duration(milliseconds: 620),
    Duration reverseDuration = const Duration(milliseconds: 480),
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionDuration: duration,
          reverseTransitionDuration: reverseDuration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SvgPageTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              style: style,
              child: child,
            );
          },
        );

  final SvgTransitionStyle style;
}

// ─────────────────────────────────────────────────────────────────────────────
// Embedded High-Detail Vector SVGs (Guarantees 0ms disk I/O & zero delay)
// ─────────────────────────────────────────────────────────────────────────────

/// Full Cyber Portal with concentric rings, tech ticks, starburst flares & gradient shields
const String rawPortalSvg = '''
<svg width="512" height="512" viewBox="0 0 512 512" fill="none" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <radialGradient id="portalGlow" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="#FFE066" stop-opacity="0.85" />
      <stop offset="35%" stop-color="#FF9E00" stop-opacity="0.55" />
      <stop offset="70%" stop-color="#7928CA" stop-opacity="0.25" />
      <stop offset="100%" stop-color="#000000" stop-opacity="0" />
    </radialGradient>

    <radialGradient id="coreGlow" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="#FFFFFF" stop-opacity="1" />
      <stop offset="25%" stop-color="#FFEAA7" stop-opacity="0.9" />
      <stop offset="60%" stop-color="#FFA500" stop-opacity="0.6" />
      <stop offset="100%" stop-color="#FF5E62" stop-opacity="0" />
    </radialGradient>

    <linearGradient id="goldGradient" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#FFF9D2" />
      <stop offset="30%" stop-color="#FFD700" />
      <stop offset="70%" stop-color="#FF9E00" />
      <stop offset="100%" stop-color="#B8860B" />
    </linearGradient>

    <linearGradient id="cyberCyan" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#00F5D4" />
      <stop offset="50%" stop-color="#00BBF9" />
      <stop offset="100%" stop-color="#7B2CBF" />
    </linearGradient>

    <linearGradient id="beamGradH" x1="0%" y1="50%" x2="100%" y2="50%">
      <stop offset="0%" stop-color="#FFD700" stop-opacity="0" />
      <stop offset="45%" stop-color="#FFEAA7" stop-opacity="0.9" />
      <stop offset="50%" stop-color="#FFFFFF" stop-opacity="1" />
      <stop offset="55%" stop-color="#FFEAA7" stop-opacity="0.9" />
      <stop offset="100%" stop-color="#FFD700" stop-opacity="0" />
    </linearGradient>

    <linearGradient id="beamGradV" x1="50%" y1="0%" x2="50%" y2="100%">
      <stop offset="0%" stop-color="#FFD700" stop-opacity="0" />
      <stop offset="45%" stop-color="#FFEAA7" stop-opacity="0.9" />
      <stop offset="50%" stop-color="#FFFFFF" stop-opacity="1" />
      <stop offset="55%" stop-color="#FFEAA7" stop-opacity="0.9" />
      <stop offset="100%" stop-color="#FFD700" stop-opacity="0" />
    </linearGradient>
  </defs>

  <circle cx="256" cy="256" r="240" fill="url(#portalGlow)" />
  <circle cx="256" cy="256" r="220" stroke="url(#cyberCyan)" stroke-width="2" stroke-dasharray="12 18" opacity="0.6" />
  <circle cx="256" cy="256" r="200" stroke="url(#goldGradient)" stroke-width="3" stroke-dasharray="32 8 8 8" opacity="0.8" />

  <polygon points="256,76 412,166 412,346 256,436 100,346 100,166" 
           stroke="url(#goldGradient)" stroke-width="2.5" fill="none" opacity="0.75" />
  <polygon points="256,92 398,174 398,338 256,420 114,338 114,174" 
           stroke="url(#cyberCyan)" stroke-width="1" stroke-dasharray="6 10" fill="none" opacity="0.5" />

  <polygon points="256,16 261,256 256,496 251,256" fill="url(#beamGradV)" opacity="0.9" />
  <polygon points="16,256 256,261 496,256 256,251" fill="url(#beamGradH)" opacity="0.9" />

  <g transform="rotate(45 256 256)">
    <polygon points="256,56 259,256 256,456 253,256" fill="url(#beamGradV)" opacity="0.7" />
    <polygon points="56,256 256,259 456,256 256,253" fill="url(#beamGradH)" opacity="0.7" />
  </g>

  <circle cx="256" cy="256" r="160" stroke="#FFFFFF" stroke-width="1.5" stroke-dasharray="4 8" opacity="0.6" />
  <circle cx="256" cy="256" r="140" stroke="url(#goldGradient)" stroke-width="4" stroke-dasharray="40 12 10 12" />
  <circle cx="256" cy="256" r="120" stroke="url(#cyberCyan)" stroke-width="2" stroke-dasharray="2 6" opacity="0.8" />

  <circle cx="256" cy="256" r="95" stroke="url(#goldGradient)" stroke-width="3" opacity="0.9" />
  <circle cx="256" cy="256" r="75" fill="url(#coreGlow)" />

  <polygon points="256,180 274,244 332,256 274,268 256,332 238,268 180,256 238,244" 
           fill="url(#goldGradient)" stroke="#FFFFFF" stroke-width="2" />

  <g transform="rotate(45 256 256)">
    <polygon points="256,204 268,248 308,256 268,264 256,308 244,264 204,256 244,248" 
             fill="#FFFFFF" opacity="0.9" />
  </g>

  <circle cx="256" cy="256" r="18" fill="#FFFFFF" />
  <circle cx="256" cy="256" r="8" fill="#FFF9E6" />
</svg>
''';

/// Inner counter-rotating diamond vector star
const String rawInnerDiamondSvg = '''
<svg width="256" height="256" viewBox="0 0 256 256" fill="none" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="innerGold" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#FFFFFF" />
      <stop offset="40%" stop-color="#FFD700" />
      <stop offset="100%" stop-color="#FF8C00" />
    </linearGradient>
    <linearGradient id="innerCyan" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#00F5D4" />
      <stop offset="100%" stop-color="#7B2CBF" />
    </linearGradient>
  </defs>
  <circle cx="128" cy="128" r="90" stroke="url(#innerCyan)" stroke-width="2" stroke-dasharray="6 6" />
  <polygon points="128,18 140,116 238,128 140,140 128,238 116,140 18,128 116,116" 
           fill="url(#innerGold)" stroke="#FFFFFF" stroke-width="1.5" />
  <circle cx="128" cy="128" r="24" fill="#FFFFFF" />
</svg>
''';

/// Diagonal cyber blade shutter wipe
const String rawCyberBladeWipeSvg = '''
<svg width="400" height="800" viewBox="0 0 400 800" fill="none" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bladeBg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#0B0E14" stop-opacity="0.95" />
      <stop offset="50%" stop-color="#151A2E" stop-opacity="0.92" />
      <stop offset="100%" stop-color="#241442" stop-opacity="0.95" />
    </linearGradient>
    <linearGradient id="bladeGold" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#FFD700" stop-opacity="0" />
      <stop offset="50%" stop-color="#FFEAA7" stop-opacity="1" />
      <stop offset="100%" stop-color="#FF9E00" stop-opacity="0.8" />
    </linearGradient>
    <linearGradient id="bladeCyan" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#00F5D4" stop-opacity="1" />
      <stop offset="100%" stop-color="#7B2CBF" stop-opacity="0" />
    </linearGradient>
  </defs>
  <path d="M0,0 L320,0 L400,200 L0,200 Z" fill="url(#bladeBg)" />
  <line x1="0" y1="200" x2="400" y2="200" stroke="url(#bladeGold)" stroke-width="2.5" />
  <path d="M0,200 L400,200 L320,400 L0,400 Z" fill="url(#bladeBg)" />
  <line x1="0" y1="400" x2="320" y2="400" stroke="url(#bladeCyan)" stroke-width="2" />
  <path d="M0,400 L320,400 L400,600 L0,600 Z" fill="url(#bladeBg)" />
  <line x1="0" y1="600" x2="400" y2="600" stroke="url(#bladeGold)" stroke-width="2.5" />
  <path d="M0,600 L400,600 L300,800 L0,800 Z" fill="url(#bladeBg)" />
  <line x1="0" y1="800" x2="300" y2="800" stroke="url(#bladeCyan)" stroke-width="2" />
</svg>
''';
