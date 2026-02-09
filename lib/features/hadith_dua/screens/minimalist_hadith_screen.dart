import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../providers/hadith_dua_provider.dart';
import '../models/hadith_dua_models.dart';

// Design Tokens
const Color _gold = Color(0xFFC2A366);
const Color _warmBg = Color(0xFF0D0D0D);
// Warm reading palette for reader
const Color _creamBg = Color(0xFFFDF6EC);
const Color _warmSand = Color(0xFFF5E6C8);
const Color _richBrown = Color(0xFF2C1810);
const Color _warmBrown = Color(0xFF5C4033);
const Color _islamicGreen = Color(0xFF2E7D32);

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
    _box = await Hive.openBox<String>(_boxName);
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(ref),
          _CollectionFilter(
            selectedCollection: selectedCollection,
            onCollectionChanged: (id) {
              ref.read(selectedCollectionProvider.notifier).state = id;
              ref.read(hadithPageProvider.notifier).state = 1;
            },
          ),
          const SizedBox(height: 8),
          Expanded(child: _HadithsList()),
        ],
      ),
    );
  }

  Widget _buildHeader(WidgetRef ref) {
    final readCount = ref.watch(readHadithsProvider).length;
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
            child: Icon(Icons.auto_stories_rounded, color: _islamicGreen.withOpacity(0.6), size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hadith',
                style: TextStyle(color: _richBrown.withOpacity(0.85), fontSize: 20,
                  fontWeight: FontWeight.w600, letterSpacing: -0.3)),
              Text('Prophetic Traditions',
                style: TextStyle(color: _warmBrown.withOpacity(0.4), fontSize: 11,
                  fontWeight: FontWeight.w400, letterSpacing: 0.3)),
            ],
          ),
          const Spacer(),
          if (readCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _islamicGreen.withOpacity(0.06),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bookmark_rounded, color: _islamicGreen.withOpacity(0.5), size: 14),
                  const SizedBox(width: 5),
                  Text('$readCount',
                    style: TextStyle(color: _islamicGreen.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// Collection Filter Pills

class _CollectionFilter extends StatelessWidget {
  final String selectedCollection;
  final ValueChanged<String> onCollectionChanged;
  const _CollectionFilter({required this.selectedCollection, required this.onCollectionChanged});

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
                color: isSelected ? _islamicGreen.withOpacity(0.08) : _warmSand.withOpacity(0.4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? _islamicGreen.withOpacity(0.25) : _warmSand.withOpacity(0.6),
                  width: isSelected ? 1.2 : 0.8,
                ),
              ),
              child: Text(collection.shortName,
                style: TextStyle(
                  color: isSelected ? _islamicGreen.withOpacity(0.8) : _warmBrown.withOpacity(0.45),
                  fontSize: 12, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
            ),
          );
        },
      ),
    );
  }
}

// Hadiths List

class _HadithsList extends ConsumerWidget {
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
            return _HadithCard(hadith: displayedHadiths[index], allHadiths: hadiths);
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
            color: _islamicGreen.withOpacity(0.05), borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _islamicGreen.withOpacity(0.12))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.expand_more, color: _islamicGreen.withOpacity(0.5), size: 20),
              const SizedBox(width: 8),
              Text('Load More ($remaining remaining)',
                style: TextStyle(color: _islamicGreen.withOpacity(0.6), fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 1.5, color: _islamicGreen.withOpacity(0.4))),
      const SizedBox(height: 12),
      Text('Loading hadiths...', style: TextStyle(color: _warmBrown.withOpacity(0.3), fontSize: 12)),
    ]),
  );

  Widget _buildEmptyState() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.auto_stories_rounded, color: _warmBrown.withOpacity(0.15), size: 56),
      const SizedBox(height: 16),
      Text('No hadiths available', style: TextStyle(color: _warmBrown.withOpacity(0.4), fontSize: 14)),
      const SizedBox(height: 4),
      Text('Connect to internet to download', style: TextStyle(color: _warmBrown.withOpacity(0.25), fontSize: 12)),
    ]),
  );

  Widget _buildErrorState(WidgetRef ref) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.error_outline, color: Colors.red.withOpacity(0.4), size: 48),
      const SizedBox(height: 12),
      Text('Failed to load hadiths', style: TextStyle(color: _warmBrown.withOpacity(0.5), fontSize: 14)),
      const SizedBox(height: 16),
      GestureDetector(
        onTap: () => ref.invalidate(collectionHadithsProvider),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: _islamicGreen.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
          child: Text('Try Again', style: TextStyle(color: _islamicGreen.withOpacity(0.7), fontSize: 12)),
        ),
      ),
    ]),
  );
}

// Hadith Card

class _HadithCard extends ConsumerWidget {
  final Hadith hadith;
  final List<Hadith> allHadiths;
  const _HadithCard({required this.hadith, required this.allHadiths});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRead = ref.watch(readHadithsProvider.select(
      (s) => s.contains('${hadith.collection}_${hadith.hadithNumber}')));
    return GestureDetector(
      onTap: () => _openReader(context, ref),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isRead ? _warmSand.withOpacity(0.5) : _warmSand.withOpacity(0.3),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isRead ? _islamicGreen.withOpacity(0.12) : _warmSand.withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: number + grade + read indicator
            Row(children: [
              Text('#${hadith.hadithNumber}',
                style: TextStyle(color: _islamicGreen.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w600)),
              if (hadith.grade != HadithGrade.unknown) ...[
                const SizedBox(width: 8),
                _GradeBadge(grade: hadith.grade),
              ],
              const Spacer(),
              if (isRead) Icon(Icons.check_circle_rounded, color: _islamicGreen.withOpacity(0.4), size: 14),
            ]),
            const SizedBox(height: 12),
            // Preview text
            Text(
              hadith.text.length > 140 ? '${hadith.text.substring(0, 140)}…' : hadith.text,
              style: TextStyle(color: _richBrown.withOpacity(0.65), fontSize: 14, height: 1.6),
              maxLines: 3, overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            // Narrator
            if (hadith.narrator != null || hadith.extractedNarrator != null)
              Text(
                '— ${hadith.narrator ?? hadith.extractedNarrator ?? ''}',
                style: TextStyle(color: _warmBrown.withOpacity(0.3), fontSize: 11, fontStyle: FontStyle.italic),
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
  const _GradeBadge({required this.grade});

  @override
  Widget build(BuildContext context) {
    final color = switch (grade) {
      HadithGrade.sahih => _islamicGreen,
      HadithGrade.hasan => const Color(0xFF00796B),
      HadithGrade.daif => const Color(0xFFE65100),
      _ => _warmBrown,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(grade.displayName,
        style: TextStyle(color: color.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.w500)),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      color: _creamBg,
      child: Row(children: [
        IconButton(
          onPressed: onClose,
          icon: Icon(Icons.arrow_back, color: _richBrown.withOpacity(0.7), size: 22),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(hadith.collection.toUpperCase(),
            style: TextStyle(color: _warmBrown.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
          Text('Hadith ${hadith.hadithNumber}',
            style: TextStyle(color: _richBrown.withOpacity(0.8), fontSize: 14, fontWeight: FontWeight.w500)),
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
            color: isRead ? _gold : _warmBrown.withOpacity(0.35), size: 22),
        ),
        const SizedBox(width: 8),
      ]),
    );
  }
}

// ── Warm Grade Badge ──

class _WarmGradeBadge extends StatelessWidget {
  final HadithGrade grade;
  const _WarmGradeBadge({required this.grade});

  @override
  Widget build(BuildContext context) {
    final color = switch (grade) {
      HadithGrade.sahih => _islamicGreen,
      HadithGrade.hasan => const Color(0xFF00796B),
      HadithGrade.daif => const Color(0xFFE65100),
      _ => _warmBrown,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(grade.displayName,
        style: TextStyle(color: color.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Warm Hadith Page — Book-like reading ──

class _WarmHadithPage extends StatelessWidget {
  final Hadith hadith;
  const _WarmHadithPage({required this.hadith});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Arabic text area ──
          if (hadith.arabicText != null && hadith.arabicText!.isNotEmpty) ...[
            const SizedBox(height: 8),
            // Gold divider
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
                hadith.arabicText!,
                style: const TextStyle(
                  color: _richBrown,
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
              Container(width: 30, height: 0.5, color: _gold.withOpacity(0.2)),
              const SizedBox(width: 10),
              Text('✦', style: TextStyle(fontSize: 8, color: _gold.withOpacity(0.3))),
              const SizedBox(width: 10),
              Container(width: 30, height: 0.5, color: _gold.withOpacity(0.2)),
            ])),
            const SizedBox(height: 20),
          ],

          // ── Narrator line ──
          if (hadith.narrator != null || hadith.extractedNarrator != null) ...[
            Text(
              '— ${hadith.narrator ?? hadith.extractedNarrator ?? ''}',
              style: TextStyle(
                color: _warmBrown.withOpacity(0.5),
                fontSize: 13,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],

          // ── English translation — generous readable typography ──
          Text(
            hadith.text,
            style: TextStyle(
              color: _richBrown.withOpacity(0.85),
              fontSize: 17,
              height: 1.85,
              letterSpacing: 0.1,
            ),
          ),

          const SizedBox(height: 28),

          // ── Minimal metadata ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _warmSand.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Reference line
              Row(children: [
                Text('Reference', style: TextStyle(color: _warmBrown.withOpacity(0.4), fontSize: 11)),
                const Spacer(),
                Text('${hadith.collection.toUpperCase()} · #${hadith.hadithNumber}',
                  style: TextStyle(color: _warmBrown.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.w500)),
              ]),
              if (hadith.book > 0) ...[
                const SizedBox(height: 8),
                Row(children: [
                  Text('Book', style: TextStyle(color: _warmBrown.withOpacity(0.4), fontSize: 11)),
                  const Spacer(),
                  Text('${hadith.book}', style: TextStyle(color: _warmBrown.withOpacity(0.6), fontSize: 12)),
                ]),
              ],
              if (hadith.chapterName != null && hadith.chapterName!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Chapter', style: TextStyle(color: _warmBrown.withOpacity(0.4), fontSize: 11)),
                  const SizedBox(width: 16),
                  Expanded(child: Text(hadith.chapterName!,
                    style: TextStyle(color: _warmBrown.withOpacity(0.6), fontSize: 12),
                    textAlign: TextAlign.end, maxLines: 2, overflow: TextOverflow.ellipsis)),
                ]),
              ],
              if (hadith.grade != HadithGrade.unknown) ...[
                const SizedBox(height: 8),
                Divider(color: _warmBrown.withOpacity(0.08), height: 16),
                Row(children: [
                  Text('Authenticity', style: TextStyle(color: _warmBrown.withOpacity(0.4), fontSize: 11)),
                  const Spacer(),
                  _WarmGradeBadge(grade: hadith.grade),
                ]),
              ],
              if (hadith.scholarGrades.isNotEmpty) ...[
                const SizedBox(height: 10),
                ...hadith.scholarGrades.map((sg) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(sg.displayText,
                    style: TextStyle(color: _warmBrown.withOpacity(0.4), fontSize: 11)),
                )),
              ],
            ]),
          ),

          const SizedBox(height: 24),
          Center(child: Text('← swipe for more →',
            style: TextStyle(color: _warmBrown.withOpacity(0.2), fontSize: 11, letterSpacing: 1))),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ── Warm Action Bar ──

class _WarmReaderActionBar extends StatelessWidget {
  final Hadith hadith;
  final int currentIndex;
  final int total;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  const _WarmReaderActionBar({required this.hadith, required this.currentIndex,
    required this.total, this.onPrevious, this.onNext});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: _creamBg,
        border: Border(top: BorderSide(color: _warmSand.withOpacity(0.5))),
      ),
      child: Row(children: [
        // Previous
        _WarmNavButton(icon: Icons.chevron_left, onTap: onPrevious, enabled: onPrevious != null),
        const Spacer(),
        // Copy
        _WarmActionIcon(icon: Icons.copy_rounded, onTap: () {
          Clipboard.setData(ClipboardData(text: hadith.shareableText));
          HapticFeedback.lightImpact();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Copied', style: TextStyle(color: Colors.white)),
            backgroundColor: _gold,
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
        }),
        const SizedBox(width: 16),
        // Counter
        Text('${currentIndex + 1}/$total',
          style: TextStyle(color: _warmBrown.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(width: 16),
        // Share
        _WarmActionIcon(icon: Icons.share_rounded, onTap: () => Share.share(hadith.shareableText)),
        const Spacer(),
        // Next
        _WarmNavButton(icon: Icons.chevron_right, onTap: onNext, enabled: onNext != null),
      ]),
    );
  }
}

class _WarmNavButton extends StatelessWidget {
  final IconData icon; final VoidCallback? onTap; final bool enabled;
  const _WarmNavButton({required this.icon, this.onTap, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? () { HapticFeedback.lightImpact(); onTap?.call(); } : null,
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

class _WarmActionIcon extends StatelessWidget {
  final IconData icon; final VoidCallback? onTap;
  const _WarmActionIcon({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); onTap?.call(); },
      child: Icon(icon, color: _warmBrown.withOpacity(0.4), size: 20),
    );
  }
}
