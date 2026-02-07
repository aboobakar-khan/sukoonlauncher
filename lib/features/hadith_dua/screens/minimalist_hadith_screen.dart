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
              color: _gold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.auto_stories_rounded, color: _gold, size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hadith',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 20,
                  fontWeight: FontWeight.w600, letterSpacing: -0.3)),
              Text('Prophetic Traditions',
                style: TextStyle(color: _gold.withValues(alpha: 0.5), fontSize: 11,
                  fontWeight: FontWeight.w400, letterSpacing: 0.3)),
            ],
          ),
          const Spacer(),
          if (readCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bookmark_rounded, color: _gold.withValues(alpha: 0.7), size: 14),
                  const SizedBox(width: 5),
                  Text('$readCount',
                    style: TextStyle(color: _gold.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w600)),
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
                color: isSelected ? _gold.withValues(alpha: 0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? _gold.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.06),
                  width: isSelected ? 1.2 : 0.8,
                ),
              ),
              child: Text(collection.shortName,
                style: TextStyle(
                  color: isSelected ? _gold : Colors.white.withValues(alpha: 0.4),
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
            color: _gold.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _gold.withValues(alpha: 0.15))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.expand_more, color: _gold.withValues(alpha: 0.6), size: 20),
              const SizedBox(width: 8),
              Text('Load More ($remaining remaining)',
                style: TextStyle(color: _gold.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 1.5, color: _gold.withValues(alpha: 0.4))),
      const SizedBox(height: 12),
      Text('Loading hadiths...', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12)),
    ]),
  );

  Widget _buildEmptyState() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.auto_stories_rounded, color: Colors.white.withValues(alpha: 0.12), size: 56),
      const SizedBox(height: 16),
      Text('No hadiths available', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 14)),
      const SizedBox(height: 4),
      Text('Connect to internet to download', style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 12)),
    ]),
  );

  Widget _buildErrorState(WidgetRef ref) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.error_outline, color: Colors.red.withValues(alpha: 0.4), size: 48),
      const SizedBox(height: 12),
      Text('Failed to load hadiths', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14)),
      const SizedBox(height: 16),
      GestureDetector(
        onTap: () => ref.invalidate(collectionHadithsProvider),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: _gold.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
          child: const Text('Try Again', style: TextStyle(color: _gold, fontSize: 12)),
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
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isRead ? _gold.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.025),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isRead ? _gold.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.04)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _gold.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                child: Text('#${hadith.hadithNumber}',
                  style: TextStyle(color: _gold.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w600)),
              ),
              if (hadith.grade != HadithGrade.unknown) ...[
                const SizedBox(width: 8),
                _GradeBadge(grade: hadith.grade),
              ],
              const Spacer(),
              if (isRead) Icon(Icons.bookmark_rounded, color: _gold.withValues(alpha: 0.4), size: 16),
            ]),
            const SizedBox(height: 14),
            Text(
              hadith.text.length > 150 ? '${hadith.text.substring(0, 150)}...' : hadith.text,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14, height: 1.6),
              maxLines: 3, overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(children: [
              if (hadith.narrator != null || hadith.extractedNarrator != null) ...[
                Icon(Icons.person_outline, size: 12, color: Colors.white.withValues(alpha: 0.2)),
                const SizedBox(width: 4),
                Expanded(child: Text(hadith.narrator ?? hadith.extractedNarrator ?? '',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 11),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              ] else
                const Spacer(),
              Icon(Icons.arrow_forward_ios, size: 10, color: Colors.white.withValues(alpha: 0.15)),
            ]),
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
      HadithGrade.sahih => const Color(0xFF4CAF50),
      HadithGrade.hasan => const Color(0xFF009688),
      HadithGrade.daif => const Color(0xFFFF9800),
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(grade.displayName,
        style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 10, fontWeight: FontWeight.w500)),
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
    return Scaffold(
      backgroundColor: _warmBg,
      body: SafeArea(
        child: Column(children: [
          _ReaderHeader(hadith: hadiths[_currentIndex], onClose: () => Navigator.pop(context)),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: hadiths.length,
              onPageChanged: (i) {
                setState(() => _currentIndex = i);
                HapticFeedback.selectionClick();
                ref.read(readHadithsProvider.notifier).markAsRead(hadiths[i]);
              },
              itemBuilder: (_, i) => _HadithPage(hadith: hadiths[i]),
            ),
          ),
          _ReaderActionBar(
            hadith: hadiths[_currentIndex],
            onPrevious: _currentIndex > 0 ? () => _pageController.previousPage(
              duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic) : null,
            onNext: _currentIndex < hadiths.length - 1 ? () => _pageController.nextPage(
              duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic) : null,
          ),
        ]),
      ),
    );
  }
}

// Reader Header

class _ReaderHeader extends ConsumerWidget {
  final Hadith hadith;
  final VoidCallback onClose;
  const _ReaderHeader({required this.hadith, required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRead = ref.watch(readHadithsProvider.select(
      (s) => s.contains('${hadith.collection}_${hadith.hadithNumber}')));
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(children: [
        GestureDetector(
          onTap: onClose,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.arrow_back_ios_new, color: Colors.white.withValues(alpha: 0.4), size: 16),
          ),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(hadith.collection.toUpperCase(),
            style: TextStyle(color: _gold.withValues(alpha: 0.6), fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
          Text('Hadith ${hadith.hadithNumber}',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13, fontWeight: FontWeight.w500)),
        ]),
        const Spacer(),
        if (hadith.grade != HadithGrade.unknown) ...[_GradeBadge(grade: hadith.grade), const SizedBox(width: 8)],
        GestureDetector(
          onTap: () { HapticFeedback.lightImpact(); ref.read(readHadithsProvider.notifier).toggleRead(hadith); },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isRead ? _gold.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10)),
            child: Icon(isRead ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
              color: isRead ? _gold : Colors.white.withValues(alpha: 0.3), size: 18),
          ),
        ),
      ]),
    );
  }
}

// Hadith Page — Book-like Layout

class _HadithPage extends StatelessWidget {
  final Hadith hadith;
  const _HadithPage({required this.hadith});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Arabic text
          if (hadith.arabicText != null && hadith.arabicText!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Center(child: Container(width: 60, height: 1.5,
              decoration: BoxDecoration(gradient: LinearGradient(
                colors: [Colors.transparent, _gold.withValues(alpha: 0.3), Colors.transparent])))),
            const SizedBox(height: 24),
            Text(hadith.arabicText!,
              style: const TextStyle(color: Colors.white, fontSize: 24, height: 2.2),
              textDirection: TextDirection.rtl, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 0.5, color: _gold.withValues(alpha: 0.15)),
              const SizedBox(width: 12),
              Icon(Icons.star, size: 8, color: _gold.withValues(alpha: 0.2)),
              const SizedBox(width: 12),
              Container(width: 40, height: 0.5, color: _gold.withValues(alpha: 0.15)),
            ])),
            const SizedBox(height: 24),
          ],
          // English translation
          Text(hadith.text,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.82), fontSize: 17, height: 1.85, letterSpacing: 0.1)),
          const SizedBox(height: 32),
          // Metadata
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02), borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.03))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (hadith.narrator != null || hadith.extractedNarrator != null) ...[
                _MetaRow(icon: Icons.person_outline, label: 'Narrator', value: hadith.narrator ?? hadith.extractedNarrator ?? 'Unknown'),
                const SizedBox(height: 10),
              ],
              _MetaRow(icon: Icons.menu_book_rounded, label: 'Reference', value: '${hadith.collection.toUpperCase()} ${hadith.hadithNumber}'),
              if (hadith.book > 0) ...[const SizedBox(height: 10),
                _MetaRow(icon: Icons.folder_outlined, label: 'Book', value: hadith.book.toString())],
              if (hadith.chapterName != null && hadith.chapterName!.isNotEmpty) ...[const SizedBox(height: 10),
                _MetaRow(icon: Icons.bookmark_border, label: 'Chapter', value: hadith.chapterName!)],
              if (hadith.grade != HadithGrade.unknown) ...[
                const SizedBox(height: 10),
                Divider(color: Colors.white.withValues(alpha: 0.04), height: 20),
                Row(children: [
                  Icon(Icons.verified_outlined, size: 14, color: Colors.white.withValues(alpha: 0.2)),
                  const SizedBox(width: 8),
                  Text('Authenticity', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12)),
                  const Spacer(),
                  _GradeBadge(grade: hadith.grade),
                ]),
              ],
              if (hadith.scholarGrades.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...hadith.scholarGrades.map((sg) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(children: [
                    Icon(Icons.school_outlined, size: 12, color: Colors.white.withValues(alpha: 0.2)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(sg.displayText, style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 11))),
                  ]),
                )),
              ],
            ]),
          ),
          const SizedBox(height: 20),
          Center(child: Text('\u2190 swipe for more \u2192',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.1), fontSize: 11, letterSpacing: 1))),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon; final String label; final String value;
  const _MetaRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.2)),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12)),
      const Spacer(),
      Flexible(child: Text(value,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12, fontWeight: FontWeight.w500),
        textAlign: TextAlign.end, maxLines: 2, overflow: TextOverflow.ellipsis)),
    ]);
  }
}

// Bottom Action Bar

class _ReaderActionBar extends StatelessWidget {
  final Hadith hadith; final VoidCallback? onPrevious; final VoidCallback? onNext;
  const _ReaderActionBar({required this.hadith, this.onPrevious, this.onNext});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(color: _warmBg,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.03)))),
      child: Row(children: [
        _ActionIcon(icon: Icons.chevron_left, onTap: onPrevious, enabled: onPrevious != null),
        const Spacer(),
        _ActionIcon(icon: Icons.copy_rounded, onTap: () {
          Clipboard.setData(ClipboardData(text: hadith.shareableText));
          HapticFeedback.lightImpact();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Copied to clipboard'),
            backgroundColor: _gold.withValues(alpha: 0.9),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
        }),
        const SizedBox(width: 20),
        _ActionIcon(icon: Icons.share_rounded, onTap: () => Share.share(hadith.shareableText)),
        const Spacer(),
        _ActionIcon(icon: Icons.chevron_right, onTap: onNext, enabled: onNext != null),
      ]),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon; final VoidCallback? onTap; final bool enabled;
  const _ActionIcon({required this.icon, this.onTap, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? () { HapticFeedback.lightImpact(); onTap?.call(); } : null,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: enabled ? 0.04 : 0.02),
          borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: Colors.white.withValues(alpha: enabled ? 0.5 : 0.12), size: 20),
      ),
    );
  }
}
