import 'package:flutter/material.dart';

/// A reusable top‑toast notification.
/// Shows a small, rounded‑corner, glass‑like overlay at the top of the screen.
/// It slides down from the top, stays for [duration] and then fades out.
/// Use [showTopToast] to display it.
class TopToast extends StatefulWidget {
  final String message;
  final Color backgroundColor;
  final Duration duration;

  const TopToast({
    super.key,
    required this.message,
    this.backgroundColor = const Color(0xFF323232),
    this.duration = const Duration(seconds: 3),
  });

  @override
  State<TopToast> createState() => _TopToastState();
}

class _TopToastState extends State<TopToast> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: const Offset(0, 0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _opacityAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
    // Auto‑dismiss after the specified duration.
    Future.delayed(widget.duration, () => _dismiss());
  }

  void _dismiss() async {
    await _controller.reverse();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _offsetAnimation,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: SafeArea(
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: widget.backgroundColor.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  widget.message,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper to show the toast.
/// Example:
/// ```dart
/// showTopToast(context, 'Scheme added');
/// ```
Future<void> showTopToast(
  BuildContext context,
  String message, {
  Color backgroundColor = const Color(0xFF323232),
  Duration duration = const Duration(seconds: 3),
}) async {
  final overlay = Overlay.of(context);
  if (overlay == null) return;

  final entry = OverlayEntry(
    builder: (_) => TopToast(
      message: message,
      backgroundColor: backgroundColor,
      duration: duration,
    ),
  );

  overlay.insert(entry);
  await Future.delayed(duration + const Duration(milliseconds: 350));
  entry.remove();
}
