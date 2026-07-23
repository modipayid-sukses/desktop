import 'package:flutter/material.dart';
import 'dart:math' as math;

enum LockState {
  locked,
  unlocked,
  loading,
}

class AnimatedLockIcon extends StatefulWidget {
  final LockState state;
  final Color lockedColor;
  final Color unlockedColor;
  final Color loadingColor;
  final double size;
  final VoidCallback? onTap;
  final Duration animationDuration;
  final bool interactive;

  const AnimatedLockIcon({
    required this.state,
    this.lockedColor = Colors.red,
    this.unlockedColor = Colors.green,
    this.loadingColor = Colors.blue,
    this.size = 48,
    this.onTap,
    this.animationDuration = const Duration(milliseconds: 300),
    this.interactive = false,
  });

  @override
  State<AnimatedLockIcon> createState() => _AnimatedLockIconState();
}

class _AnimatedLockIconState extends State<AnimatedLockIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _rotationAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _updateAnimation();
  }

  @override
  void didUpdateWidget(AnimatedLockIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _updateAnimation();
    }
  }

  void _updateAnimation() {
    if (widget.state == LockState.loading) {
      _animationController.repeat();
    } else {
      _animationController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.interactive ? widget.onTap : null,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          Color color;
          if (widget.state == LockState.locked) {
            color = widget.lockedColor;
          } else if (widget.state == LockState.unlocked) {
            color = widget.unlockedColor;
          } else {
            color = widget.loadingColor;
          }

          return Transform.rotate(
            angle: widget.state == LockState.loading
                ? _rotationAnimation.value * 2 * math.pi
                : 0,
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: CustomPaint(
                size: Size(widget.size, widget.size),
                painter: LockIconPainter(
                  state: widget.state,
                  color: color,
                  animation: _rotationAnimation.value,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}

class LockIconPainter extends CustomPainter {
  final LockState state;
  final Color color;
  final double animation;

  LockIconPainter({
    required this.state,
    required this.color,
    this.animation = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Draw lock body (rectangle)
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(centerX, centerY + 2),
        width: size.width * 0.5,
        height: size.height * 0.4,
      ),
      Radius.circular(4),
    );
    canvas.drawRRect(bodyRect, fillPaint);
    canvas.drawRRect(bodyRect, paint);

    // Draw keyhole
    canvas.drawCircle(
      Offset(centerX, centerY + 2),
      2.5,
      paint,
    );

    // Draw shackle (animated based on lock state)
    if (state == LockState.locked) {
      // Closed shackle
      final shacklePath = Path();
      shacklePath.addArc(
        Rect.fromCenter(
          center: Offset(centerX, centerY - size.height * 0.15),
          width: size.width * 0.45,
          height: size.height * 0.4,
        ),
        math.pi,
        math.pi,
      );
      canvas.drawPath(shacklePath, paint);
    } else if (state == LockState.unlocked) {
      // Open shackle (rotated up)
      canvas.save();
      canvas.translate(centerX, centerY - size.height * 0.1);
      canvas.rotate(math.pi / 4 + (animation * math.pi / 4));
      canvas.translate(-centerX, -centerY + size.height * 0.1);

      final shacklePath = Path();
      shacklePath.addArc(
        Rect.fromCenter(
          center: Offset(centerX, centerY - size.height * 0.15),
          width: size.width * 0.45,
          height: size.height * 0.4,
        ),
        math.pi,
        math.pi * 0.75,
      );
      canvas.drawPath(shacklePath, paint);
      canvas.restore();
    } else {
      // Loading - pulsing shackle
      final pulsatingOpacity = 0.3 + (animation * 0.7);
      final pulsingPaint = Paint()
        ..color = color.withOpacity(pulsatingOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;

      final shacklePath = Path();
      shacklePath.addArc(
        Rect.fromCenter(
          center: Offset(centerX, centerY - size.height * 0.15),
          width: size.width * 0.45,
          height: size.height * 0.4,
        ),
        math.pi,
        math.pi,
      );
      canvas.drawPath(shacklePath, pulsingPaint);
    }
  }

  @override
  bool shouldRepaint(LockIconPainter oldDelegate) {
    return oldDelegate.state != state ||
        oldDelegate.color != color ||
        oldDelegate.animation != animation;
  }
}

/// Helper widget for displaying lock status
class LockStatusIndicator extends StatelessWidget {
  final LockState state;
  final String? label;
  final Color? lockedColor;
  final Color? unlockedColor;
  final Color? loadingColor;

  const LockStatusIndicator({
    required this.state,
    this.label,
    this.lockedColor,
    this.unlockedColor,
    this.loadingColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedLockIcon(
          state: state,
          size: 64,
          lockedColor: lockedColor ?? Colors.red,
          unlockedColor: unlockedColor ?? Colors.green,
          loadingColor: loadingColor ?? Colors.blue,
        ),
        if (label != null) ...[
          SizedBox(height: 8),
          Text(
            label!,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _getColorForState(),
            ),
          ),
        ],
      ],
    );
  }

  Color _getColorForState() {
    switch (state) {
      case LockState.locked:
        return lockedColor ?? Colors.red;
      case LockState.unlocked:
        return unlockedColor ?? Colors.green;
      case LockState.loading:
        return loadingColor ?? Colors.blue;
    }
  }
}
