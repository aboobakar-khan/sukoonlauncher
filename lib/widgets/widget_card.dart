import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';

/// Reusable glass-morphism widget card
/// Used for dashboard widgets like To-Do, Notes, Calendar
class WidgetCard extends ConsumerWidget {
  final String title;
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final double? height;
  final EdgeInsets? padding;

  const WidgetCard({
    super.key,
    required this.title,
    required this.child,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.height,
    this.padding,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeColor = ref.watch(themeColorProvider);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        padding: padding ?? const EdgeInsets.all(20),
        decoration: BoxDecoration(
          // Subtle gradient background with theme color tint for visual depth
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.black.withValues(alpha: 0.85),
              Colors.black.withValues(alpha: 0.75),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            // Theme-aware border with subtle glow effect
            color: themeColor.color.withValues(alpha: 0.3),
            width: 1.5,
          ),
          // Soft shadow for card elevation
          boxShadow: [
            BoxShadow(
              color: themeColor.color.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Enhanced title with theme color gradient
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [
                      themeColor.color.withValues(alpha: 0.7),
                      themeColor.color.withValues(alpha: 0.4),
                    ],
                  ).createShader(bounds),
                  child: Text(
                    title.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w600,
                      color: Colors.white, // Will be masked by gradient
                    ),
                  ),
                ),
                Row(
                  children: [
                    if (onDelete != null)
                      GestureDetector(
                        onTap: onDelete,
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.red.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            Icons.delete_outline,
                            size: 14,
                            color: Colors.red.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    if (onEdit != null)
                      GestureDetector(
                        onTap: onEdit,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: themeColor.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: themeColor.color.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            Icons.edit,
                            size: 14,
                            color: themeColor.color.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Content
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// Empty state widget for cards with no content
class EmptyCardState extends ConsumerWidget {
  final String message;
  final IconData icon;
  final VoidCallback? onAdd;

  const EmptyCardState({
    super.key,
    required this.message,
    required this.icon,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeColor = ref.watch(themeColorProvider);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Enhanced icon with theme color glow
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: themeColor.color.withValues(alpha: 0.08),
              border: Border.all(
                color: themeColor.color.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              size: 32,
              color: themeColor.color.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: themeColor.color.withValues(alpha: 0.5),
              fontSize: 14,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          if (onAdd != null) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      themeColor.color.withValues(alpha: 0.15),
                      themeColor.color.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: themeColor.color.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_circle_outline,
                      size: 16,
                      color: themeColor.color.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Add',
                      style: TextStyle(
                        color: themeColor.color.withValues(alpha: 0.7),
                        fontSize: 13,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
