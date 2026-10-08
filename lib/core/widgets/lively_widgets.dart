import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A tactile spring-bounce tap wrapper with instant haptic feedback.
/// Inspired by top Dribbble mobile interactions where every touch feels tangible.
class BouncyTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleFactor;
  final Duration duration;
  final BorderRadius? borderRadius;

  const BouncyTap({
    super.key,
    required this.child,
    this.onTap,
    this.scaleFactor = 0.96,
    this.duration = const Duration(milliseconds: 120),
    this.borderRadius,
  });

  @override
  State<BouncyTap> createState() => _BouncyTapState();
}

class _BouncyTapState extends State<BouncyTap> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleFactor,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap == null) return;
    HapticFeedback.lightImpact();
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onTap == null) return;
    _controller.reverse();
    widget.onTap?.call();
  }

  void _onTapCancel() {
    if (widget.onTap == null) return;
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) {
      return widget.child;
    }
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Concentric pulsing ripple beacon (radar wave) for live status & awaiting PIN state.
class PulsingBeacon extends StatefulWidget {
  final Color color;
  final double size;
  final bool showRipple;

  const PulsingBeacon({
    super.key,
    this.color = const Color(0xFF10B981),
    this.size = 10,
    this.showRipple = true,
  });

  @override
  State<PulsingBeacon> createState() => _PulsingBeaconState();
}

class _PulsingBeaconState extends State<PulsingBeacon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showRipple) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        final rippleSize = widget.size + (widget.size * 1.8 * progress);
        final opacity = (1.0 - progress).clamp(0.0, 1.0);

        return SizedBox(
          width: widget.size * 2.8,
          height: widget.size * 2.8,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer wave
              Container(
                width: rippleSize,
                height: rippleSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: opacity * 0.35),
                  border: Border.all(
                    color: widget.color.withValues(alpha: opacity * 0.6),
                    width: 1.2,
                  ),
                ),
              ),
              // Inner glowing core
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.6),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Smooth Count-Up Animation for financial amounts (e.g. GH₵ 0.00 -> GH₵ 1,450.00)
class AnimatedCountUp extends StatefulWidget {
  final double value;
  final String prefix;
  final TextStyle? style;
  final Duration duration;

  const AnimatedCountUp({
    super.key,
    required this.value,
    this.prefix = 'GH₵ ',
    this.style,
    this.duration = const Duration(milliseconds: 1000),
  });

  @override
  State<AnimatedCountUp> createState() => _AnimatedCountUpState();
}

class _AnimatedCountUpState extends State<AnimatedCountUp> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(begin: 0, end: widget.value).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutExpo),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedCountUp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = Tween<double>(begin: oldWidget.value, end: widget.value).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutExpo),
      );
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final val = _animation.value;
        final formatted = _formatMoney(val);
        return Text(
          '${widget.prefix}$formatted',
          style: widget.style,
        );
      },
    );
  }

  String _formatMoney(double val) {
    final parts = val.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts[1];
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final formattedInt = intPart.replaceAllMapped(reg, (Match m) => '${m[1]},');
    return '$formattedInt.$decPart';
  }
}

/// Dribbble-style celebration particle burst & checkmark bounce
class SuccessCelebrationBurst extends StatefulWidget {
  final Widget child;

  const SuccessCelebrationBurst({super.key, required this.child});

  @override
  State<SuccessCelebrationBurst> createState() => _SuccessCelebrationBurstState();
}

class _SuccessCelebrationBurstState extends State<SuccessCelebrationBurst>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    final colors = [
      const Color(0xFF10B981), // Emerald
      const Color(0xFF229ED9), // Telegram Sky
      const Color(0xFFF59E0B), // Amber
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFFEC4899), // Pink
      const Color(0xFF14B8A6), // Teal
    ];

    for (int i = 0; i < 28; i++) {
      final angle = _random.nextDouble() * 2 * math.pi;
      final distance = 60.0 + _random.nextDouble() * 90.0;
      final size = 4.0 + _random.nextDouble() * 5.0;
      final color = colors[_random.nextInt(colors.length)];
      _particles.add(_Particle(
        angle: angle,
        maxDistance: distance,
        size: size,
        color: color,
        isCircle: _random.nextBool(),
      ));
    }

    _controller.forward();
    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        final scale = Tween<double>(begin: 0.2, end: 1.0)
            .animate(CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: Curves.elasticOut)))
            .value;

        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Custom particle burst
            if (progress < 1.0)
              CustomPaint(
                size: const Size(200, 200),
                painter: _ParticlePainter(_particles, progress),
              ),
            // Central bounce widget
            Transform.scale(
              scale: scale,
              child: widget.child,
            ),
          ],
        );
      },
    );
  }
}

class _Particle {
  final double angle;
  final double maxDistance;
  final double size;
  final Color color;
  final bool isCircle;

  _Particle({
    required this.angle,
    required this.maxDistance,
    required this.size,
    required this.color,
    required this.isCircle,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ParticlePainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final opacity = (1.0 - progress).clamp(0.0, 1.0);

    for (final p in particles) {
      final easeOutDist = Curves.easeOutQuad.transform(progress) * p.maxDistance;
      final dx = center.dx + math.cos(p.angle) * easeOutDist;
      final dy = center.dy + math.sin(p.angle) * easeOutDist;
      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      if (p.isCircle) {
        canvas.drawCircle(Offset(dx, dy), p.size * (1.0 - progress * 0.4), paint);
      } else {
        canvas.save();
        canvas.translate(dx, dy);
        canvas.rotate(progress * math.pi * 2);
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 1.5),
          paint,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}

/// Dribbble-style Frosted Glass Card with subtle gradient border
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final List<Color>? borderGradientColors;
  final double blurAmount;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius,
    this.backgroundColor,
    this.borderGradientColors,
    this.blurAmount = 10,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = borderRadius ?? BorderRadius.circular(20);
    final bg = backgroundColor ??
        (isDark ? const Color(0xFF1E1E22).withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.85));

    return ClipRRect(
      borderRadius: r,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: r,
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.6),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Ambient glow halo around icons, status badges or avatars
class GlowHalo extends StatelessWidget {
  final Widget child;
  final Color glowColor;
  final double blurRadius;
  final double spreadRadius;

  const GlowHalo({
    super.key,
    required this.child,
    required this.glowColor,
    this.blurRadius = 16,
    this.spreadRadius = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.35),
            blurRadius: blurRadius,
            spreadRadius: spreadRadius,
          ),
        ],
      ),
      child: child,
    );
  }
}

