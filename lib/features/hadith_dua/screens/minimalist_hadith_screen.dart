import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../providers/hadith_dua_provider.dart';
import '../models/hadith_dua_models.dart';
import '../../../providers/islamic_theme_provider.dart';
import '../../../utils/hive_box_manager.dart';

/// Provider for read hadiths tracking
final readHadithsProvider = StateNotifierProvider<ReadHadithsNotifier, Set<String>>((ref) {
  return ReadHadithsNotifier();
});

class ReadHadithsNotifier extends StateNotifier<Set<String>> {
  static const String _boxName = 'read_hadiths';
  Box<String>? _box;

  ReadHadithsNotifier() : super({}) {
    _init();
  }

  Future<void> _init() async {
    _box = await HiveBoxManager.get<String>(_boxName);
    final saved = _box?.get('read_list');
    if (saved != null) {
      state = saved.split(',').where((s) => s.isNotEmpty).toSet();
    }
  }

  String _getKey(Hadith hadith) => '${hadith.collection}_${hadith.hadithNumber}';
  bool isRead(Hadith hadith) => state.contains(_getKey(hadith));

  void toggleRead(Hadith hadith) {
    final key = _getKey(hadith);
    if (state.contains(key)) {
      state = Set.from(state)..remove(key);
    } else {
      state = Set.from(state)..add(key);
    }
    _save();
  }

  void markAsRead(Hadith hadith) {
    final key = _getKey(hadith);
    if (!state.contains(key)) {
      state = Set.from(state)..add(key);
      _save();
    }
  }

  Future<void> _save() async {
    await _box?.put('read_list', state.join(','));
  }

  int get readCount => state.length;
}

/// Provider for pagination
final hadithPageProvider = StateProvider<int>((ref) => 1);
const int _pageSize = 20;

// MINIMALIST HADITH SCREEN

class MinimalistHadithScreen extends ConsumerWidget {
  const MinimalistHadithScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCollection = ref.watch(selectedCollectionProvider);
    final tc = ref.watch(islamicThemeColorsProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(ref, tc),
          _CollectionFilter(
            selectedCollection: selectedCollection,
            onCollectionChanged: (id) {
              ref.read(selectedCollectionProvider.notifier).state = id;
              ref.read(hadithPageProvider.notifier).state = 1;
              // Reset chapter filter when collection changes
              ref.read(selectedBookFilterProvider.notifier).state = null;
            },
            tc: tc,
          ),
          const SizedBox(height: 4),
          _ChapterFilter(tc: tc),
          const SizedBox(height: 4),
          Expanded(child: _HadithsList(tc: tc)),
        ],
      ),
    );
  }

  Widget _buildHeader(WidgetRef ref, IslamicThemeColors tc) {
    final readCount = ref.watch(readHadithsProvider).length;
    final currentLang = ref.watch(hadithLanguageProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: tc.green.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.auto_stories_rounded, color: tc.green.withValues(alpha: 0.6), size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hadith',
                style: TextStyle(color: tc.text.withValues(alpha: 0.85), fontSize: 20,
                  fontWeight: FontWeight.w600, letterSpacing: -0.3)),
              Text('Prophetic Traditions',
                style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.4), fontSize: 11,
                  fontWeight: FontWeight.w400, letterSpacing: 0.3)),
            ],
          ),
          const Spacer(),
          // Language picker
          GestureDetector(
            onTap: () => _showLanguagePicker(ref, tc),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: tc.green.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.translate_rounded, color: tc.green.withValues(alpha: 0.5), size: 14),
                  const SizedBox(width: 5),
                  Text(currentLang.code.toUpperCase(),
                    style: TextStyle(color: tc.green.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          if (readCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: tc.green.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bookmark_rounded, color: tc.green.withValues(alpha: 0.5), size: 14),
                  const SizedBox(width: 5),
                  Text('$readCount',
                    style: TextStyle(color: tc.green.withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showLanguagePicker(WidgetRef ref, IslamicThemeColors tc) {
    final context = ref.context;
    final currentLang = ref.read(hadithLanguageProvider);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: BoxDecoration(
          color: tc.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: tc.textSecondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Hadith Language',
              style: TextStyle(color: tc.text.withValues(alpha: 0.85), fontSize: 16,
                fontWeight: FontWeight.w600, letterSpacing: -0.2)),
            const SizedBox(height: 4),
            Text('Choose the language for hadith text',
              style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.4), fontSize: 12)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: HadithLanguage.available.map((lang) {
                final isSelected = lang.code == currentLang.code;
                return GestureDetector(
                  onTap: () {
                    ref.read(hadithLanguageProvider.notifier).setLanguage(lang);
                    ref.read(hadithPageProvider.notifier).state = 1;
                    Navigator.pop(ctx);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? tc.green.withValues(alpha: 0.12) : tc.green.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? tc.green.withValues(alpha: 0.3) : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Text(lang.name,
                      style: TextStyle(
                        color: isSelected ? tc.green.withValues(alpha: 0.8) : tc.text.withValues(alpha: 0.5),
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// Collection Filter Pills

class _CollectionFilter extends StatelessWidget {
  final String selectedCollection;
  final ValueChanged<String> onCollectionChanged;
  final IslamicThemeColors tc;
  const _CollectionFilter({required this.selectedCollection, required this.onCollectionChanged, required this.tc});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: HadithCollection.collections.length,
        itemBuilder: (context, index) {
          final collection = HadithCollection.collections[index];
          final isSelected = selectedCollection == collection.id;
          return GestureDetector(
            onTap: () { HapticFeedback.selectionClick(); onCollectionChanged(collection.id); },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? tc.green.withValues(alpha: 0.08) : tc.surface.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? tc.green.withValues(alpha: 0.25) : tc.surface.withValues(alpha: 0.6),
                  width: isSelected ? 1.2 : 0.8,
                ),
              ),
              child: Text(collection.shortName,
                style: TextStyle(
                  color: isSelected ? tc.green.withValues(alpha: 0.8) : tc.textSecondary.withValues(alpha: 0.45),
                  fontSize: 12, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
            ),
          );
        },
      ),
    );
  }
}

// Chapter / Book Filter — horizontal pill list showing parts/chapters from the API

class _ChapterFilter extends ConsumerWidget {
  final IslamicThemeColors tc;
  const _ChapterFilter({required this.tc});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chaptersAsync = ref.watch(collectionChaptersProvider);
    final selectedBook = ref.watch(selectedBookFilterProvider);

    return chaptersAsync.when(
      data: (chapters) {
        if (chapters.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 34,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: chapters.length + 1, // +1 for "All" pill
            itemBuilder: (context, index) {
              if (index == 0) {
                // "All" pill
                final isSelected = selectedBook == null;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(selectedBookFilterProvider.notifier).state = null;
                    ref.read(hadithPageProvider.notifier).state = 1;
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? tc.accent.withValues(alpha: 0.10) : tc.surface.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? tc.accent.withValues(alpha: 0.30) : tc.surface.withValues(alpha: 0.5),
                        width: isSelected ? 1.0 : 0.6,
                      ),
                    ),
                    child: Text('All',
                      style: TextStyle(
                        color: isSelected ? tc.accent.withValues(alpha: 0.85) : tc.textSecondary.withValues(alpha: 0.4),
                        fontSize: 11, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
                  ),
                );
              }
              final entry = chapters.entries.elementAt(index - 1);
              final bookNum = entry.key;
              final chapterName = entry.value;
              final isSelected = selectedBook == bookNum;
              // Truncate long chapter names
              final displayName = chapterName.length > 28
                  ? '${chapterName.substring(0, 25)}…'
                  : chapterName;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(selectedBookFilterProvider.notifier).state = bookNum;
                  ref.read(hadithPageProvider.notifier).state = 1;
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? tc.accent.withValues(alpha: 0.10) : tc.surface.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? tc.accent.withValues(alpha: 0.30) : tc.surface.withValues(alpha: 0.5),
                      width: isSelected ? 1.0 : 0.6,
                    ),
                  ),
                  child: Text('$bookNum. $displayName',
                    style: TextStyle(
                      color: isSelected ? tc.accent.withValues(alpha: 0.85) : tc.textSecondary.withValues(alpha: 0.4),
                      fontSize: 11, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
                ),
              );
            },
          ),
        );
      },
      loading: () => const SizedBox(height: 34),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

// Hadiths List

class _HadithsList extends ConsumerWidget {
  final IslamicThemeColors tc;
  const _HadithsList({required this.tc});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hadithsAsync = ref.watch(collectionHadithsProvider);
    final currentPage = ref.watch(hadithPageProvider);
    return hadithsAsync.when(
      data: (hadiths) {
        if (hadiths.isEmpty) return _buildEmptyState();
        final displayCount = currentPage * _pageSize;
        final displayedHadiths = hadiths.take(displayCount).toList();
        final hasMore = displayCount < hadiths.length;
        final remaining = hadiths.length - displayCount;
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          itemCount: displayedHadiths.length + (hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == displayedHadiths.length) return _buildLoadMoreButton(ref, remaining);
            return _HadithCard(hadith: displayedHadiths[index], allHadiths: hadiths, tc: tc);
          },
        );
      },
      loading: () => _buildLoadingState(),
      error: (error, _) => _buildErrorState(ref),
    );
  }

  Widget _buildLoadMoreButton(WidgetRef ref, int remaining) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: GestureDetector(
        onTap: () { HapticFeedback.lightImpact(); ref.read(hadithPageProvider.notifier).state++; },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: tc.green.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tc.green.withValues(alpha: 0.12))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.expand_more, color: tc.green.withValues(alpha: 0.5), size: 20),
              const SizedBox(width: 8),
              Text('Load More ($remaining remaining)',
                style: TextStyle(color: tc.green.withValues(alpha: 0.6), fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 1.5, color: tc.green.withValues(alpha: 0.4))),
      const SizedBox(height: 12),
      Text('Loading hadiths...', style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.3), fontSize: 12)),
    ]),
  );

  Widget _buildEmptyState() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.auto_stories_rounded, color: tc.textSecondary.withValues(alpha: 0.15), size: 56),
      const SizedBox(height: 16),
      Text('No hadiths available', style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.4), fontSize: 14)),
      const SizedBox(height: 4),
      Text('Connect to internet to download', style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.25), fontSize: 12)),
    ]),
  );

  Widget _buildErrorState(WidgetRef ref) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.error_outline, color: Colors.red.withValues(alpha: 0.4), size: 48),
      const SizedBox(height: 12),
      Text('Failed to load hadiths', style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.5), fontSize: 14)),
      const SizedBox(height: 16),
      GestureDetector(
        onTap: () => ref.invalidate(collectionHadithsProvider),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: tc.green.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
          child: Text('Try Again', style: TextStyle(color: tc.green.withValues(alpha: 0.7), fontSize: 12)),
        ),
      ),
    ]),
  );
}

// Hadith Card

class _HadithCard extends ConsumerWidget {
  final Hadith hadith;
  final List<Hadith> allHadiths;
  final IslamicThemeColors tc;
  const _HadithCard({required this.hadith, required this.allHadiths, required this.tc});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRead = ref.watch(readHadithsProvider.select(
      (s) => s.contains('${hadith.collection}_${hadith.hadithNumber}')));
    final lang = ref.watch(hadithLanguageProvider);
    final isRtl = lang.direction == 'rtl';
    return GestureDetector(
      onTap: () => _openReader(context, ref),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isRead ? tc.surface.withValues(alpha: 0.5) : tc.surface.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isRead ? tc.green.withValues(alpha: 0.12) : tc.surface.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Top row: number + grade + read indicator
            Row(children: [
              Text('#${hadith.hadithNumber}',
                style: TextStyle(color: tc.green.withValues(alpha: 0.5), fontSize: 12, fontWeight: FontWeight.w600)),
              if (hadith.grade != HadithGrade.unknown) ...[
                const SizedBox(width: 8),
                _GradeBadge(grade: hadith.grade, tc: tc),
              ],
              const Spacer(),
              if (isRead) Icon(Icons.check_circle_rounded, color: tc.green.withValues(alpha: 0.4), size: 14),
            ]),
            // Chapter/Book info
            if (hadith.chapterName != null && hadith.chapterName!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.menu_book_rounded, color: tc.textSecondary.withValues(alpha: 0.25), size: 12),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Book ${hadith.book} · ${hadith.chapterName}',
                    style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.35), fontSize: 11),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ],
            const SizedBox(height: 12),
            // Preview text
            Text(
              hadith.text.length > 140 ? '${hadith.text.substring(0, 140)}…' : hadith.text,
              style: TextStyle(color: tc.text.withValues(alpha: 0.65), fontSize: 14, height: 1.6),
              maxLines: 3, overflow: TextOverflow.ellipsis,
              textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
            ),
            const SizedBox(height: 10),
            // Narrator
            if (hadith.narrator != null || hadith.extractedNarrator != null)
              Text(
                '— ${hadith.narrator ?? hadith.extractedNarrator ?? ''}',
                style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.3), fontSize: 11, fontStyle: FontStyle.italic),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }

  void _openReader(BuildContext context, WidgetRef ref) {
    ref.read(readHadithsProvider.notifier).markAsRead(hadith);
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        fullscreenDialog: true,
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (context, animation, _) => HadithReaderScreen(hadith: hadith, allHadiths: allHadiths),
        transitionsBuilder: (context, animation, _, child) =>
          FadeTransition(opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut), child: child),
      ),
    );
  }
}

class _GradeBadge extends StatelessWidget {
  final HadithGrade grade;
  final IslamicThemeColors tc;
  const _GradeBadge({required this.grade, required this.tc});

  @override
  Widget build(BuildContext context) {
    final color = switch (grade) {
      HadithGrade.sahih => tc.green,
      HadithGrade.hasan => const Color(0xFF00796B),
      HadithGrade.daif => const Color(0xFFE65100),
      _ => tc.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(grade.displayName,
        style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.w500)),
    );
  }
}

// HADITH READER — Immersive Swipeable Reading Experience

class HadithReaderScreen extends ConsumerStatefulWidget {
  final Hadith hadith;
  final List<Hadith>? allHadiths;
  const HadithReaderScreen({super.key, required this.hadith, this.allHadiths});

  @override
  ConsumerState<HadithReaderScreen> createState() => _HadithReaderScreenState();
}

class _HadithReaderScreenState extends ConsumerState<HadithReaderScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.allHadiths?.indexWhere((h) =>
      h.hadithNumber == widget.hadith.hadithNumber && h.collection == widget.hadith.collection) ?? 0;
    if (_currentIndex < 0) _currentIndex = 0;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() { _pageController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final hadiths = widget.allHadiths ?? [widget.hadith];
    final tc = ref.watch(islamicThemeColorsProvider);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: tc.background,
        statusBarIconBrightness: tc.statusBarBrightness,
        systemNavigationBarColor: tc.background,
        systemNavigationBarIconBrightness: tc.statusBarBrightness,
      ),
      child: Scaffold(
        backgroundColor: tc.background,
        body: SafeArea(
          child: Column(children: [
            _WarmReaderHeader(hadith: hadiths[_currentIndex], onClose: () => Navigator.pop(context)),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: hadiths.length,
                onPageChanged: (i) {
                  setState(() => _currentIndex = i);
                  HapticFeedback.selectionClick();
                  ref.read(readHadithsProvider.notifier).markAsRead(hadiths[i]);
                },
                itemBuilder: (_, i) => _WarmHadithPage(hadith: hadiths[i]),
              ),
            ),
            _WarmReaderActionBar(
              hadith: hadiths[_currentIndex],
              currentIndex: _currentIndex,
              total: hadiths.length,
              onPrevious: _currentIndex > 0 ? () => _pageController.previousPage(
                duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic) : null,
              onNext: _currentIndex < hadiths.length - 1 ? () => _pageController.nextPage(
                duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic) : null,
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Warm Reader Header ──

class _WarmReaderHeader extends ConsumerWidget {
  final Hadith hadith;
  final VoidCallback onClose;
  const _WarmReaderHeader({required this.hadith, required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRead = ref.watch(readHadithsProvider.select(
      (s) => s.contains('${hadith.collection}_${hadith.hadithNumber}')));
    final tc = ref.watch(islamicThemeColorsProvider);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      color: tc.background,
      child: Row(children: [
        IconButton(
          onPressed: onClose,
          icon: Icon(Icons.arrow_back, color: tc.text.withValues(alpha: 0.7), size: 22),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(hadith.collection.toUpperCase(),
            style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.5), fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
          Text('Hadith ${hadith.hadithNumber}',
            style: TextStyle(color: tc.text.withValues(alpha: 0.8), fontSize: 14, fontWeight: FontWeight.w500)),
        ]),
        const Spacer(),
        if (hadith.grade != HadithGrade.unknown) ...[
          _WarmGradeBadge(grade: hadith.grade),
          const SizedBox(width: 8),
        ],
        GestureDetector(
          onTap: () { HapticFeedback.lightImpact(); ref.read(readHadithsProvider.notifier).toggleRead(hadith); },
          child: Icon(
            isRead ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
            color: isRead ? tc.accent : tc.textSecondary.withValues(alpha: 0.35), size: 22),
        ),
        const SizedBox(width: 8),
      ]),
    );
  }
}

// ── Warm Grade Badge ──

class _WarmGradeBadge extends ConsumerWidget {
  final HadithGrade grade;
  const _WarmGradeBadge({required this.grade});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tc = ref.watch(islamicThemeColorsProvider);
    final color = switch (grade) {
      HadithGrade.sahih => tc.green,
      HadithGrade.hasan => const Color(0xFF00796B),
      HadithGrade.daif => const Color(0xFFE65100),
      _ => tc.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(grade.displayName,
        style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Warm Hadith Page — Book-like reading ──

class _WarmHadithPage extends ConsumerWidget {
  final Hadith hadith;
  const _WarmHadithPage({required this.hadith});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tc = ref.watch(islamicThemeColorsProvider);
    final lang = ref.watch(hadithLanguageProvider);
    final isRtl = lang.direction == 'rtl';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
      physics: const ClampingScrollPhysics(),
      child: Column(
        crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.stretch,
        children: [
          // ── Arabic text area ──
          if (hadith.arabicText != null && hadith.arabicText!.isNotEmpty) ...[
            const SizedBox(height: 8),
            // Gold divider
            Center(child: Container(width: 50, height: 1,
              decoration: BoxDecoration(gradient: LinearGradient(
                colors: [Colors.transparent, tc.accent.withValues(alpha: 0.3), Colors.transparent])))),
            const SizedBox(height: 20),
            // Arabic in warm sand container
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                color: tc.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                hadith.arabicText!,
                style: TextStyle(
                  color: tc.arabicText,
                  fontSize: 24,
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
              Container(width: 30, height: 0.5, color: tc.accent.withValues(alpha: 0.2)),
              const SizedBox(width: 10),
              Text('✦', style: TextStyle(fontSize: 8, color: tc.accent.withValues(alpha: 0.3))),
              const SizedBox(width: 10),
              Container(width: 30, height: 0.5, color: tc.accent.withValues(alpha: 0.2)),
            ])),
            const SizedBox(height: 20),
          ],

          // ── Narrator line ──
          if (hadith.narrator != null || hadith.extractedNarrator != null) ...[
            Text(
              '— ${hadith.narrator ?? hadith.extractedNarrator ?? ''}',
              style: TextStyle(
                color: tc.textSecondary.withValues(alpha: 0.5),
                fontSize: 13,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],

          // ── Translation text — generous readable typography ──
          Text(
            hadith.text,
            style: TextStyle(
              color: tc.text.withValues(alpha: 0.85),
              fontSize: 17,
              height: 1.85,
              letterSpacing: 0.1,
            ),
            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          ),

          const SizedBox(height: 28),

          // ── Minimal metadata ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: tc.surface.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Reference line
              Row(children: [
                Text('Reference', style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.4), fontSize: 11)),
                const Spacer(),
                Text('${hadith.collection.toUpperCase()} · #${hadith.hadithNumber}',
                  style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.w500)),
              ]),
              if (hadith.book > 0) ...[
                const SizedBox(height: 8),
                Row(children: [
                  Text('Book', style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.4), fontSize: 11)),
                  const Spacer(),
                  Text('${hadith.book}', style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.6), fontSize: 12)),
                ]),
              ],
              if (hadith.chapterName != null && hadith.chapterName!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Chapter', style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.4), fontSize: 11)),
                  const SizedBox(width: 16),
                  Expanded(child: Text(hadith.chapterName!,
                    style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.6), fontSize: 12),
                    textAlign: TextAlign.end, maxLines: 2, overflow: TextOverflow.ellipsis)),
                ]),
              ],
              if (hadith.grade != HadithGrade.unknown) ...[
                const SizedBox(height: 8),
                Divider(color: tc.textSecondary.withValues(alpha: 0.08), height: 16),
                Row(children: [
                  Text('Authenticity', style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.4), fontSize: 11)),
                  const Spacer(),
                  _WarmGradeBadge(grade: hadith.grade),
                ]),
              ],
              if (hadith.scholarGrades.isNotEmpty) ...[
                const SizedBox(height: 10),
                ...hadith.scholarGrades.map((sg) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(sg.displayText,
                    style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.4), fontSize: 11)),
                )),
              ],
            ]),
          ),

          const SizedBox(height: 24),
          Center(child: Text('← swipe for more →',
            style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.2), fontSize: 11, letterSpacing: 1))),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ── Warm Action Bar ──

class _WarmReaderActionBar extends ConsumerWidget {
  final Hadith hadith;
  final int currentIndex;
  final int total;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  const _WarmReaderActionBar({required this.hadith, required this.currentIndex,
    required this.total, this.onPrevious, this.onNext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tc = ref.watch(islamicThemeColorsProvider);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: tc.background,
        border: Border(top: BorderSide(color: tc.surface.withValues(alpha: 0.5))),
      ),
      child: Row(children: [
        // Previous
        _WarmNavButton(icon: Icons.chevron_left, onTap: onPrevious, enabled: onPrevious != null, tc: tc),
        const Spacer(),
        // Copy
        _WarmActionIcon(icon: Icons.copy_rounded, tc: tc, onTap: () {
          Clipboard.setData(ClipboardData(text: hadith.shareableText));
          HapticFeedback.lightImpact();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Copied', style: TextStyle(color: Colors.white)),
            backgroundColor: tc.accent,
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
        }),
        const SizedBox(width: 16),
        // Counter
        Text('${currentIndex + 1}/$total',
          style: TextStyle(color: tc.textSecondary.withValues(alpha: 0.4), fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(width: 16),
        // Share
        _WarmActionIcon(icon: Icons.share_rounded, tc: tc, onTap: () => Share.share(hadith.shareableText)),
        const Spacer(),
        // Next
        _WarmNavButton(icon: Icons.chevron_right, onTap: onNext, enabled: onNext != null, tc: tc),
      ]),
    );
  }
}

class _WarmNavButton extends StatelessWidget {
  final IconData icon; final VoidCallback? onTap; final bool enabled; final IslamicThemeColors tc;
  const _WarmNavButton({required this.icon, this.onTap, this.enabled = true, required this.tc});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? () { HapticFeedback.lightImpact(); onTap?.call(); } : null,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: enabled ? tc.surface.withValues(alpha: 0.5) : tc.surface.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: enabled ? tc.textSecondary.withValues(alpha: 0.6) : tc.textSecondary.withValues(alpha: 0.2), size: 20),
      ),
    );
  }
}

class _WarmActionIcon extends StatelessWidget {
  final IconData icon; final VoidCallback? onTap; final IslamicThemeColors tc;
  const _WarmActionIcon({required this.icon, this.onTap, required this.tc});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); onTap?.call(); },
      child: Icon(icon, color: tc.textSecondary.withValues(alpha: 0.4), size: 20),
    );
  }
}
