import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/hadith_dua_provider.dart';
import '../models/hadith_dua_models.dart';

// ── Warm Reading Palette ──
const Color _creamBg = Color(0xFFFDF6EC);
const Color _warmSand = Color(0xFFF5E6C8);
const Color _richBrown = Color(0xFF2C1810);
const Color _warmBrown = Color(0xFF5C4033);
const Color _gold = Color(0xFFC2A366);
const Color _islamicGreen = Color(0xFF2E7D32);

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
    {'id': 'Morning & Evening', 'name': 'Morning', 'icon': Icons.nights_stay_outlined},
    {'id': 'Protection', 'name': 'Protection', 'icon': Icons.shield_outlined},
    {'id': 'Sleep', 'name': 'Sleep', 'icon': Icons.bedtime_outlined},
    {'id': 'Food & Drink', 'name': 'Food', 'icon': Icons.restaurant_outlined},
    {'id': 'Travel', 'name': 'Travel', 'icon': Icons.flight_outlined},
    {'id': 'Forgiveness', 'name': 'Forgiveness', 'icon': Icons.favorite_outline},
    {'id': 'Distress', 'name': 'Distress', 'icon': Icons.healing_outlined},
    {'id': 'Guidance', 'name': 'Guidance', 'icon': Icons.explore_outlined},
    {'id': 'Gratitude', 'name': 'Gratitude', 'icon': Icons.volunteer_activism_outlined},
    {'id': 'Health', 'name': 'Health', 'icon': Icons.health_and_safety_outlined},
    {'id': 'Knowledge', 'name': 'Knowledge', 'icon': Icons.school_outlined},
    {'id': 'Family', 'name': 'Family', 'icon': Icons.family_restroom_outlined},
    {'id': 'General', 'name': 'General', 'icon': Icons.star_outline},
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
              color: _islamicGreen.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.favorite_outline, color: _islamicGreen.withOpacity(0.6), size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Duas',
                style: TextStyle(color: _richBrown.withOpacity(0.85), fontSize: 18, fontWeight: FontWeight.w600)),
              Text('Supplications from Quran & Sunnah',
                style: TextStyle(color: _warmBrown.withOpacity(0.4), fontSize: 11)),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _islamicGreen.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('${allDuas.length}',
              style: TextStyle(color: _islamicGreen.withOpacity(0.6), fontSize: 13, fontWeight: FontWeight.w600)),
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
                    ? _islamicGreen.withOpacity(0.08)
                    : _warmSand.withOpacity(0.4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? _islamicGreen.withOpacity(0.25)
                      : _warmSand.withOpacity(0.6),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    category['icon'] as IconData,
                    size: 14,
                    color: isSelected
                        ? _islamicGreen.withOpacity(0.7)
                        : _warmBrown.withOpacity(0.35),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    category['name']!,
                    style: TextStyle(
                      color: isSelected
                          ? _islamicGreen.withOpacity(0.8)
                          : _warmBrown.withOpacity(0.45),
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
                            ? _islamicGreen.withOpacity(0.12)
                            : _warmSand.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          color: isSelected
                              ? _islamicGreen.withOpacity(0.7)
                              : _warmBrown.withOpacity(0.35),
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
              color: _warmSand.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.favorite_outline,
                color: _warmBrown.withOpacity(0.3), size: 24),
          ),
          const SizedBox(height: 16),
          Text('No duas in this category',
            style: TextStyle(color: _warmBrown.withOpacity(0.5), fontSize: 14)),
          const SizedBox(height: 4),
          Text('Try selecting a different category',
            style: TextStyle(color: _warmBrown.withOpacity(0.3), fontSize: 12)),
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
          color: _warmSand.withOpacity(0.3),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _warmSand.withOpacity(0.5)),
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
                    color: _islamicGreen.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: _islamicGreen.withOpacity(0.6),
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
                      color: _richBrown.withOpacity(0.8),
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
                      color: _islamicGreen.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      dua.category!.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(
                        color: _islamicGreen.withOpacity(0.5),
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
                color: Colors.white.withOpacity(0.4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                dua.arabicText.length > 100
                    ? '${dua.arabicText.substring(0, 100)}...'
                    : dua.arabicText,
                style: TextStyle(
                  color: _richBrown.withOpacity(0.7),
                  fontSize: 18,
                  height: 1.8,
                  fontFamily: 'Amiri',
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
                      color: _warmBrown.withOpacity(0.45),
                      fontSize: 12,
                      height: 1.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_ios,
                    size: 10, color: _gold.withOpacity(0.3)),
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: _creamBg,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: _creamBg,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _creamBg,
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
      ),
    );
  }

  Widget _buildReaderHeader(BuildContext context, Dua dua) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
      color: _creamBg,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back, color: _richBrown.withOpacity(0.6), size: 22),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (dua.category != null)
                  Text(
                    dua.category!.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      color: _warmBrown.withOpacity(0.4),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                Text(
                  dua.title,
                  style: TextStyle(
                    color: _richBrown.withOpacity(0.75),
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
              color: _islamicGreen.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${_currentIndex + 1} / ${widget.allDuas?.length ?? 1}',
              style: TextStyle(
                color: _islamicGreen.withOpacity(0.55),
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
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: _creamBg,
        border: Border(top: BorderSide(color: _warmSand.withOpacity(0.5))),
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
          GestureDetector(
            onTap: () {
              final text =
                  '${dua.arabicText}\n\n${dua.transliteration}\n\n${dua.translation}\n\n— ${dua.source ?? "Islamic Dua"}';
              Clipboard.setData(ClipboardData(text: text));
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text('Copied', style: TextStyle(color: Colors.white)),
                backgroundColor: _gold,
                duration: const Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ));
            },
            child: Icon(Icons.copy_rounded, color: _warmBrown.withOpacity(0.4), size: 20),
          ),
          const SizedBox(width: 20),
          Text('${_currentIndex + 1}/$totalCount',
            style: TextStyle(color: _warmBrown.withOpacity(0.35), fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(width: 20),
          GestureDetector(
            onTap: () {
              final text =
                  '${dua.title}\n\n${dua.arabicText}\n\n${dua.transliteration}\n\n${dua.translation}\n\n— ${dua.source ?? "Islamic Dua"}';
              Share.share(text);
            },
            child: Icon(Icons.share_rounded, color: _warmBrown.withOpacity(0.4), size: 20),
          ),
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
      onTap: enabled ? () { HapticFeedback.lightImpact(); onTap(); } : null,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: enabled ? _warmSand.withOpacity(0.5) : _warmSand.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: enabled ? _warmBrown.withOpacity(0.6) : _warmBrown.withOpacity(0.2), size: 20),
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
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Center(child: Container(width: 50, height: 1,
            decoration: BoxDecoration(gradient: LinearGradient(
              colors: [Colors.transparent, _gold.withOpacity(0.3), Colors.transparent])))),
          const SizedBox(height: 20),
          // Arabic in warm sand container
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              color: _warmSand.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              dua.arabicText,
              style: const TextStyle(
                color: _richBrown,
                fontSize: 26,
                height: 2.2,
                fontFamily: 'Amiri',
              ),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          // Ornamental divider
          Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 30, height: 0.5, color: _gold.withOpacity(0.2)),
            const SizedBox(width: 10),
            Text('✦', style: TextStyle(fontSize: 8, color: _gold.withOpacity(0.3))),
            const SizedBox(width: 10),
            Container(width: 30, height: 0.5, color: _gold.withOpacity(0.2)),
          ])),
          const SizedBox(height: 20),
          // Transliteration
          if (dua.transliteration.isNotEmpty) ...[
            Text(
              dua.transliteration,
              style: TextStyle(
                color: _warmBrown.withOpacity(0.55),
                fontSize: 15,
                fontStyle: FontStyle.italic,
                height: 1.7,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],
          // Translation
          Text(
            dua.translation,
            style: TextStyle(
              color: _richBrown.withOpacity(0.8),
              fontSize: 17,
              height: 1.85,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 28),
          // Source
          if (dua.source != null && dua.source!.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _warmSand.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Text('Source', style: TextStyle(color: _warmBrown.withOpacity(0.4), fontSize: 12)),
                  const Spacer(),
                  Flexible(
                    child: Text(dua.source!,
                      style: TextStyle(color: _warmBrown.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.end, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          Center(child: Text('← swipe for more →',
            style: TextStyle(color: _warmBrown.withOpacity(0.2), fontSize: 11, letterSpacing: 1))),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
