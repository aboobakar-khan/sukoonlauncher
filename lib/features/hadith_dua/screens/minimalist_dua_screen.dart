import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/hadith_dua_provider.dart';
import '../models/hadith_dua_models.dart';

// Design Tokens
const Color _gold = Color(0xFFC2A366);
const Color _warmBg = Color(0xFF0D0D0D);

/// Minimalist Dua Screen — Redesigned
///
/// Matches Hadith screen quality:
/// - Gold accent design language
/// - Clean typography with decorative dividers
/// - Swipeable PageView reader
/// - Category filter with count badges
class MinimalistDuaScreen extends ConsumerStatefulWidget {
  const MinimalistDuaScreen({super.key});

  @override
  ConsumerState<MinimalistDuaScreen> createState() =>
      _MinimalistDuaScreenState();
}

class _MinimalistDuaScreenState extends ConsumerState<MinimalistDuaScreen> {
  String _selectedCategory = 'all';

  static const List<Map<String, dynamic>> _categories = [
    {'id': 'all', 'name': 'All', 'icon': Icons.auto_awesome_outlined},
    {'id': 'daily', 'name': 'Daily', 'icon': Icons.wb_sunny_outlined},
    {'id': 'morning_evening', 'name': 'Morning', 'icon': Icons.nights_stay_outlined},
    {'id': 'prayer', 'name': 'Prayer', 'icon': Icons.mosque_outlined},
    {'id': 'protection', 'name': 'Protection', 'icon': Icons.shield_outlined},
    {'id': 'travel', 'name': 'Travel', 'icon': Icons.flight_outlined},
    {'id': 'food', 'name': 'Food', 'icon': Icons.restaurant_outlined},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildCategoryFilter(),
          const SizedBox(height: 8),
          Expanded(child: _buildDuasList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final allDuas = ref.watch(allDuasProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.favorite_outline, color: _gold, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Duas',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Supplications from Quran & Sunnah',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${allDuas.length}',
              style: TextStyle(
                color: _gold.withValues(alpha: 0.6),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    final allDuas = ref.watch(allDuasProvider);

    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category['id'];
          final count = category['id'] == 'all'
              ? allDuas.length
              : allDuas.where((d) => d.category == category['id']).length;

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedCategory = category['id']!);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? _gold.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? _gold.withValues(alpha: 0.35)
                      : Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    category['icon'] as IconData,
                    size: 14,
                    color: isSelected
                        ? _gold
                        : Colors.white.withValues(alpha: 0.35),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    category['name']!,
                    style: TextStyle(
                      color: isSelected
                          ? _gold
                          : Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _gold.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          color: isSelected
                              ? _gold.withValues(alpha: 0.8)
                              : Colors.white.withValues(alpha: 0.3),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDuasList() {
    final allDuas = ref.watch(allDuasProvider);

    final filteredDuas = _selectedCategory == 'all'
        ? allDuas
        : allDuas.where((d) => d.category == _selectedCategory).toList();

    if (filteredDuas.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      physics: const BouncingScrollPhysics(
          decelerationRate: ScrollDecelerationRate.fast),
      itemCount: filteredDuas.length,
      itemBuilder: (context, index) =>
          _DuaCard(dua: filteredDuas[index], allDuas: filteredDuas, index: index),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.favorite_outline,
                color: _gold.withValues(alpha: 0.3), size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            'No duas in this category',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try selecting a different category',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.2),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// DUA CARD

class _DuaCard extends StatelessWidget {
  final Dua dua;
  final List<Dua> allDuas;
  final int index;

  const _DuaCard({
    required this.dua,
    required this.allDuas,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => DuaReaderScreen(
                dua: dua, allDuas: allDuas, initialIndex: index),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _gold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: _gold.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    dua.title,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (dua.category != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _gold.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      dua.category!.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(
                        color: _gold.withValues(alpha: 0.6),
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                dua.arabicText.length > 100
                    ? '${dua.arabicText.substring(0, 100)}...'
                    : dua.arabicText,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 18,
                  height: 1.8,
                ),
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    dua.translation,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 12,
                      height: 1.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_ios,
                    size: 10, color: _gold.withValues(alpha: 0.3)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// DUA READER — Immersive Swipeable Reading

class DuaReaderScreen extends StatefulWidget {
  final Dua dua;
  final List<Dua>? allDuas;
  final int initialIndex;

  const DuaReaderScreen({
    super.key,
    required this.dua,
    this.allDuas,
    this.initialIndex = 0,
  });

  @override
  State<DuaReaderScreen> createState() => _DuaReaderScreenState();
}

class _DuaReaderScreenState extends State<DuaReaderScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final duas = widget.allDuas ?? [widget.dua];

    return Scaffold(
      backgroundColor: _warmBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildReaderHeader(context, duas[_currentIndex]),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: duas.length,
                onPageChanged: (i) {
                  setState(() => _currentIndex = i);
                  HapticFeedback.selectionClick();
                },
                itemBuilder: (_, i) => _DuaPage(dua: duas[i]),
              ),
            ),
            _buildActionBar(context, duas[_currentIndex], duas.length),
          ],
        ),
      ),
    );
  }

  Widget _buildReaderHeader(BuildContext context, Dua dua) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.arrow_back_ios_new,
                  color: Colors.white.withValues(alpha: 0.4), size: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (dua.category != null)
                  Text(
                    dua.category!.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      color: _gold.withValues(alpha: 0.6),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                Text(
                  dua.title,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${_currentIndex + 1} / ${widget.allDuas?.length ?? 1}',
              style: TextStyle(
                color: _gold.withValues(alpha: 0.6),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(BuildContext context, Dua dua, int totalCount) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: _warmBg,
        border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.03))),
      ),
      child: Row(
        children: [
          _buildNavButton(
            Icons.chevron_left,
            enabled: _currentIndex > 0,
            onTap: () => _pageController.previousPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
            ),
          ),
          const Spacer(),
          _buildActionIcon(Icons.copy_rounded, 'Copy', () {
            final text =
                '${dua.arabicText}\n\n${dua.transliteration}\n\n${dua.translation}\n\n— ${dua.source ?? "Islamic Dua"}';
            Clipboard.setData(ClipboardData(text: text));
            HapticFeedback.lightImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Dua copied'),
                backgroundColor: _gold.withValues(alpha: 0.9),
                duration: const Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            );
          }),
          const SizedBox(width: 16),
          _buildActionIcon(Icons.share_rounded, 'Share', () {
            final text =
                '${dua.title}\n\n${dua.arabicText}\n\n${dua.transliteration}\n\n${dua.translation}\n\n— ${dua.source ?? "Islamic Dua"}';
            Share.share(text);
          }),
          const Spacer(),
          _buildNavButton(
            Icons.chevron_right,
            enabled: _currentIndex < totalCount - 1,
            onTap: () => _pageController.nextPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton(IconData icon,
      {required bool enabled, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: enabled
          ? () {
              HapticFeedback.lightImpact();
              onTap();
            }
          : null,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: enabled ? 0.04 : 0.02),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon,
            color: Colors.white.withValues(alpha: enabled ? 0.5 : 0.12),
            size: 20),
      ),
    );
  }

  Widget _buildActionIcon(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.5), size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// DUA PAGE — Book-like content layout

class _DuaPage extends StatelessWidget {
  final Dua dua;
  const _DuaPage({required this.dua});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 60,
              height: 1.5,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.transparent,
                  _gold.withValues(alpha: 0.3),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            dua.arabicText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              height: 2.2,
            ),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 40,
                    height: 0.5,
                    color: _gold.withValues(alpha: 0.15)),
                const SizedBox(width: 12),
                Icon(Icons.star,
                    size: 8, color: _gold.withValues(alpha: 0.2)),
                const SizedBox(width: 12),
                Container(
                    width: 40,
                    height: 0.5,
                    color: _gold.withValues(alpha: 0.15)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (dua.transliteration.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: _gold.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.record_voice_over_outlined,
                          size: 14,
                          color: _gold.withValues(alpha: 0.4)),
                      const SizedBox(width: 6),
                      Text(
                        'Transliteration',
                        style: TextStyle(
                          color: _gold.withValues(alpha: 0.5),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    dua.transliteration,
                    style: TextStyle(
                      color: _gold.withValues(alpha: 0.8),
                      fontSize: 15,
                      fontStyle: FontStyle.italic,
                      height: 1.7,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            dua.translation,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 17,
              height: 1.85,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 28),
          if (dua.source != null && dua.source!.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.03)),
              ),
              child: Row(
                children: [
                  Icon(Icons.menu_book_rounded,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.2)),
                  const SizedBox(width: 8),
                  Text(
                    'Source',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      dua.source!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.end,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              '\u2190 swipe for more \u2192',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.1),
                fontSize: 11,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
