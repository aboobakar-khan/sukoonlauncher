import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/deen_mode_provider.dart';
import 'deen_mode_screen.dart';

/// Deen Mode Entry Screen - Duration and purpose selection
class DeenModeEntryScreen extends ConsumerStatefulWidget {
  const DeenModeEntryScreen({super.key});

  @override
  ConsumerState<DeenModeEntryScreen> createState() => _DeenModeEntryScreenState();
}

class _DeenModeEntryScreenState extends ConsumerState<DeenModeEntryScreen> {
  int _selectedDuration = 60; // minutes
  String _selectedPurpose = 'quran';

  static const List<Map<String, dynamic>> _durations = [
    {'label': '30 min', 'minutes': 30},
    {'label': '1 hour', 'minutes': 60},
    {'label': '2 hours', 'minutes': 120},
    {'label': '3 hours', 'minutes': 180},
  ];

  static const List<Map<String, String>> _purposes = [
    {'id': 'quran', 'icon': '📖', 'label': 'Quran'},
    {'id': 'prayer', 'icon': '🤲', 'label': 'Prayer'},
    {'id': 'learning', 'icon': '📚', 'label': 'Learning'},
    {'id': 'reflect', 'icon': '🌙', 'label': 'Reflect'},
  ];

  void _startDeenMode() {
    HapticFeedback.mediumImpact();
    ref.read(deenModeProvider.notifier).startDeenMode(
      durationMinutes: _selectedDuration,
      purpose: _selectedPurpose,
    );
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const DeenModeScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Back button
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(
                    Icons.arrow_back,
                    color: Colors.white.withValues(alpha: 0.5),
                    size: 24,
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Header
              Center(
                child: Column(
                  children: [
                    Text(
                      '☪',
                      style: TextStyle(
                        color: const Color(0xFFC2A366).withValues(alpha: 0.7),
                        fontSize: 32,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Enter Deen Mode',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 24,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Block distractions. Focus on faith.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 48),
              
              // Duration section
              Text(
                'Duration',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: _durations.map((d) {
                  final isSelected = d['minutes'] == _selectedDuration;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedDuration = d['minutes']);
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? const Color(0xFFC2A366).withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected 
                                ? const Color(0xFFC2A366).withValues(alpha: 0.3)
                                : Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Text(
                          d['label'],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected 
                                ? const Color(0xFFC2A366)
                                : Colors.white.withValues(alpha: 0.5),
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 32),
              
              // Purpose section
              Text(
                'Purpose',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _purposes.map((p) {
                  final isSelected = p['id'] == _selectedPurpose;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedPurpose = p['id']!);
                    },
                    child: Container(
                      width: (MediaQuery.of(context).size.width - 60) / 2,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? const Color(0xFFC2A366).withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected 
                              ? const Color(0xFFC2A366).withValues(alpha: 0.3)
                              : Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            p['icon']!,
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            p['label']!,
                            style: TextStyle(
                              color: isSelected 
                                  ? const Color(0xFFC2A366)
                                  : Colors.white.withValues(alpha: 0.5),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              
              const Spacer(),
              
              // Warning
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFF6B35).withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: const Color(0xFFFF6B35).withValues(alpha: 0.7),
                      size: 18,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Notifications will be muted. Exiting requires a 10-second hold and confirmation.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Start button
              GestureDetector(
                onTap: _startDeenMode,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFC2A366).withValues(alpha: 0.3),
                        const Color(0xFFA67B5B).withValues(alpha: 0.3),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFC2A366).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '☪',
                        style: TextStyle(
                          color: const Color(0xFFC2A366).withValues(alpha: 0.9),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'START DEEN MODE',
                        style: TextStyle(
                          color: const Color(0xFFC2A366).withValues(alpha: 0.95),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
