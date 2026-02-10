import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/zen_mode_provider.dart';
import '../screens/zen_mode_entry_screen.dart';

/// ─────────────────────────────────────────────
/// Zen Mode Widget — Dashboard compact card
/// ─────────────────────────────────────────────

class ZenModeWidget extends ConsumerWidget {
  const ZenModeWidget({super.key});

  static const _leafGreen = Color(0xFF22C55E);
  static const _deepGreen = Color(0xFF166534);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zen = ref.watch(zenModeProvider);

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ZenModeEntryScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D0D),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: zen.isActive
                ? _leafGreen.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.06),
          ),
          boxShadow: zen.isActive
              ? [
                  BoxShadow(
                    color: _leafGreen.withValues(alpha: 0.08),
                    blurRadius: 16,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: zen.isActive
                      ? [_leafGreen, _deepGreen]
                      : [
                          Colors.white.withValues(alpha: 0.08),
                          Colors.white.withValues(alpha: 0.04),
                        ],
                ),
              ),
              child: Icon(
                Icons.spa_rounded,
                color: zen.isActive
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.4),
                size: 20,
              ),
            ),
            const SizedBox(width: 14),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Zen Mode',
                    style: TextStyle(
                      color: zen.isActive
                          ? _leafGreen
                          : Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    zen.isActive
                        ? '${zen.remainingFormatted} remaining'
                        : 'Lock your phone, find peace',
                    style: TextStyle(
                      color: zen.isActive
                          ? _leafGreen.withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.35),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            // Status indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: zen.isActive
                    ? _leafGreen.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: zen.isActive
                      ? _leafGreen.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Text(
                zen.isActive ? 'Active' : 'Start',
                style: TextStyle(
                  color: zen.isActive
                      ? _leafGreen
                      : Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
