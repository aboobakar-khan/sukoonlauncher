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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: zen.isActive
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _leafGreen.withValues(alpha: 0.12),
                    _deepGreen.withValues(alpha: 0.06),
                  ],
                )
              : null,
          color: zen.isActive ? null : const Color(0xFF0D0D0D),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: zen.isActive
                ? _leafGreen.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.06),
            width: zen.isActive ? 1.5 : 1,
          ),
          boxShadow: zen.isActive
              ? [
                  BoxShadow(
                    color: _leafGreen.withValues(alpha: 0.1),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Icon — larger, prominent
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
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
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),

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
                              : Colors.white.withValues(alpha: 0.85),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
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
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                // CTA button — prominent
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: zen.isActive
                        ? LinearGradient(colors: [_leafGreen, _deepGreen])
                        : null,
                    color: zen.isActive ? null : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: zen.isActive
                          ? _leafGreen.withValues(alpha: 0.4)
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (zen.isActive)
                        Icon(Icons.timer_rounded, size: 14, color: Colors.white.withValues(alpha: 0.8)),
                      if (zen.isActive) const SizedBox(width: 4),
                      Text(
                        zen.isActive ? 'Active' : 'Start →',
                        style: TextStyle(
                          color: zen.isActive
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Active indicator bar
            if (zen.isActive) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: zen.progress,
                  minHeight: 3,
                  backgroundColor: _leafGreen.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(_leafGreen.withValues(alpha: 0.6)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
