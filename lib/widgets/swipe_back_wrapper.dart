import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reusable bottom swipe-up wrapper for pushed screens.
///
/// Adds a bottom-center pill indicator and swipe-up gesture
/// that pops the screen (Navigator.pop), mimicking Android's
/// system navigation gesture — but for our own pushed pages
/// (Settings, Prayer Analytics, Dhikr Analytics, Challenge Analytics).
///
/// Does NOT conflict with vertical scroll inside children because
/// it only captures gestures in a thin bottom zone.
class SwipeBackWrapper extends StatelessWidget {
  final Widget child;

  const SwipeBackWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main content
        child,

        // Bottom swipe-up zone → pop screen
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 40,
          child: GestureDetector(
            onVerticalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity < -250) {
                HapticFeedback.lightImpact();
                Navigator.of(context).pop();
              }
            },
            behavior: HitTestBehavior.opaque,
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
