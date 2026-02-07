import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../providers/hadith_dua_provider.dart';
import '../models/hadith_dua_models.dart';

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

/// Minimalist Hadith Screen - sunnah.com style
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
          // Header with read count
          _buildHeader(ref),
          
          // Collection pills
          _CollectionFilter(
            selectedCollection: selectedCollection,
            onCollectionChanged: (id) {
              ref.read(selectedCollectionProvider.notifier).state = id;
              ref.read(hadithPageProvider.notifier).state = 1; // Reset pagination
            },
          ),
          
          // Hadiths list
          Expanded(
            child: _HadithsList(),
          ),
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFC2A366).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.menu_book,
              color: Color(0xFFC2A366),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hadith',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Authentic prophetic traditions',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Read count badge
          if (readCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFC2A366).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle,
                    color: const Color(0xFFC2A366),
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$readCount read',
                    style: const TextStyle(
                      color: Color(0xFFC2A366),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CollectionFilter extends StatelessWidget {
  final String selectedCollection;
  final ValueChanged<String> onCollectionChanged;
  
  const _CollectionFilter({
    required this.selectedCollection,
    required this.onCollectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: HadithCollection.collections.length,
        itemBuilder: (context, index) {
          final collection = HadithCollection.collections[index];
          final isSelected = selectedCollection == collection.id;
          
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onCollectionChanged(collection.id);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected 
                    ? const Color(0xFFC2A366).withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected 
                      ? const Color(0xFFC2A366).withValues(alpha: 0.4)
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Text(
                collection.shortName,
                style: TextStyle(
                  color: isSelected 
                      ? const Color(0xFFC2A366)
                      : Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HadithsList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hadithsAsync = ref.watch(collectionHadithsProvider);
    final currentPage = ref.watch(hadithPageProvider);
    
    return hadithsAsync.when(
      data: (hadiths) {
        if (hadiths.isEmpty) {
          return _buildEmptyState();
        }
        
        // Paginate hadiths
        final displayCount = currentPage * _pageSize;
        final displayedHadiths = hadiths.take(displayCount).toList();
        final hasMore = displayCount < hadiths.length;
        final remaining = hadiths.length - displayCount;
        
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          itemCount: displayedHadiths.length + (hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            // Load More button at the end
            if (index == displayedHadiths.length) {
              return _buildLoadMoreButton(ref, remaining, hadiths.length);
            }
            return _HadithCard(
              hadith: displayedHadiths[index],
              allHadiths: hadiths, // Pass all hadiths for navigation
            );
          },
        );
      },
      loading: () => _buildLoadingState(),
      error: (error, _) => _buildErrorState(ref),
    );
  }

  Widget _buildLoadMoreButton(WidgetRef ref, int remaining, int total) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          ref.read(hadithPageProvider.notifier).state++;
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFC2A366).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFC2A366).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.expand_more,
                color: const Color(0xFFC2A366),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Load More ($remaining remaining)',
                style: const TextStyle(
                  color: Color(0xFFC2A366),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: const Color(0xFFC2A366).withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Loading hadiths...',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book,
            color: Colors.white.withValues(alpha: 0.2),
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            'No hadiths available',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Connect to internet to download',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red.withValues(alpha: 0.5),
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            'Failed to load hadiths',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => ref.invalidate(collectionHadithsProvider),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFC2A366).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Try Again',
                style: TextStyle(
                  color: Color(0xFFC2A366),
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HadithCard extends ConsumerWidget {
  final Hadith hadith;
  final List<Hadith> allHadiths;
  
  const _HadithCard({required this.hadith, required this.allHadiths});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRead = ref.watch(readHadithsProvider.select((s) => s.contains('${hadith.collection}_${hadith.hadithNumber}')));
    
    return GestureDetector(
      onTap: () => _openHadithReader(context, ref),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isRead 
              ? const Color(0xFFC2A366).withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isRead 
                ? const Color(0xFFC2A366).withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Source info with read button
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC2A366).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${hadith.collection.toUpperCase()} ${hadith.hadithNumber}',
                    style: TextStyle(
                      color: const Color(0xFFC2A366).withValues(alpha: 0.8),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (hadith.grade != HadithGrade.unknown) ...[
                  const SizedBox(width: 8),
                  _buildGradeBadge(),
                ],
                const Spacer(),
                // Mark as Read button
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref.read(readHadithsProvider.notifier).toggleRead(hadith);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isRead 
                          ? const Color(0xFFC2A366).withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isRead ? Icons.check_circle : Icons.circle_outlined,
                      color: isRead 
                          ? const Color(0xFFC2A366)
                          : Colors.white.withValues(alpha: 0.3),
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Arabic text preview
            if (hadith.arabicText != null && hadith.arabicText!.isNotEmpty)
              Text(
                hadith.arabicText!.length > 100 
                    ? '${hadith.arabicText!.substring(0, 100)}...'
                    : hadith.arabicText!,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 16,
                  height: 1.8,
                ),
                textDirection: TextDirection.rtl,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            
            if (hadith.arabicText != null && hadith.arabicText!.isNotEmpty) 
              const SizedBox(height: 8),
            
            // English translation preview
            Text(
              hadith.text.length > 120 
                  ? '${hadith.text.substring(0, 120)}...'
                  : hadith.text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 13,
                height: 1.5,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            
            const SizedBox(height: 8),
            
            // Tap hint
            Row(
              children: [
                Text(
                  'Tap to read full hadith',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.2),
                    fontSize: 10,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.chevron_right,
                  color: Colors.white.withValues(alpha: 0.2),
                  size: 16,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradeBadge() {
    Color color;
    switch (hadith.grade) {
      case HadithGrade.sahih:
        color = Colors.green;
      case HadithGrade.hasan:
        color = Colors.teal;
      case HadithGrade.daif:
        color = Colors.orange;
      default:
        color = Colors.grey;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        hadith.grade.displayName,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _openHadithReader(BuildContext context, WidgetRef ref) {
    // Mark as read when opening
    ref.read(readHadithsProvider.notifier).markAsRead(hadith);
    
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => HadithReaderScreen(
          hadith: hadith,
          allHadiths: allHadiths,
        ),
      ),
    );
  }
}

/// Full-screen Hadith Reader - sunnah.com style
class HadithReaderScreen extends ConsumerWidget {
  final Hadith hadith;
  final List<Hadith>? allHadiths;  // Optional: for navigation
  
  const HadithReaderScreen({
    super.key, 
    required this.hadith,
    this.allHadiths,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRead = ref.watch(readHadithsProvider.select((s) => s.contains('${hadith.collection}_${hadith.hadithNumber}')));
    
    // Find current index for navigation
    final currentIndex = allHadiths?.indexWhere((h) => 
      h.hadithNumber == hadith.hadithNumber && h.collection == hadith.collection
    );
    final hasNext = allHadiths != null && currentIndex != null && currentIndex >= 0 && currentIndex < allHadiths!.length - 1;
    
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context, ref, isRead),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Reference badge
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC2A366).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${hadith.collection.toUpperCase()} • Hadith ${hadith.hadithNumber}',
                          style: const TextStyle(
                            color: Color(0xFFC2A366),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Arabic text
                    if (hadith.arabicText != null && hadith.arabicText!.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: Text(
                          hadith.arabicText!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            height: 2.0,
                          ),
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    
                    // English translation
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Translation',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            hadith.text,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 16,
                              height: 1.7,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Metadata
                    _buildMetadata(),
                    
                    const SizedBox(height: 24),
                    
                    // Actions
                    _buildActions(context, ref, isRead),
                    
                    // Next Hadith Button
                    if (hasNext) ...[
                      const SizedBox(height: 16),
                      _buildNextHadithButton(context, ref, currentIndex!),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, bool isRead) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.close,
                color: Colors.white.withValues(alpha: 0.5),
                size: 20,
              ),
            ),
          ),
          const Spacer(),
          // Read status
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              ref.read(readHadithsProvider.notifier).toggleRead(hadith);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isRead 
                    ? const Color(0xFFC2A366).withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isRead ? Icons.check_circle : Icons.circle_outlined,
                    color: isRead ? const Color(0xFFC2A366) : Colors.white.withValues(alpha: 0.4),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isRead ? 'Read' : 'Mark as Read',
                    style: TextStyle(
                      color: isRead ? const Color(0xFFC2A366) : Colors.white.withValues(alpha: 0.4),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (hadith.grade != HadithGrade.unknown)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: hadith.grade == HadithGrade.sahih 
                    ? Colors.green.withValues(alpha: 0.15)
                    : hadith.grade == HadithGrade.hasan 
                        ? Colors.teal.withValues(alpha: 0.15)
                        : Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                hadith.grade.displayName,
                style: TextStyle(
                  color: hadith.grade == HadithGrade.sahih 
                      ? Colors.green
                      : hadith.grade == HadithGrade.hasan 
                          ? Colors.teal
                          : Colors.orange,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetadata() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main reference info
          _buildMetadataRow('Collection', hadith.collection.toUpperCase()),
          if (hadith.book > 0)
            _buildMetadataRow('Book', hadith.book.toString()),
          _buildMetadataRow('Hadith Number', hadith.hadithNumber.toString()),
          
          // Narrator information
          if (hadith.narrator != null || hadith.extractedNarrator != null) ...[
            const SizedBox(height: 12),
            Divider(color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 12),
            _buildMetadataRow('Narrator', hadith.narrator ?? hadith.extractedNarrator ?? 'Unknown'),
          ],
          
          // Chapter/Section name
          if (hadith.chapterName != null && hadith.chapterName!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildMetadataRow('Chapter', hadith.chapterName!),
          ],
          
          // Hadith grading information
          if (hadith.grade != HadithGrade.unknown) ...[
            const SizedBox(height: 12),
            Divider(color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Authenticity',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getGradeColor(hadith.grade).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    hadith.grade.displayName,
                    style: TextStyle(
                      color: _getGradeColor(hadith.grade),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
          
          // Scholar grades if available
          if (hadith.scholarGrades.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...hadith.scholarGrades.map((sg) => Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.school,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      sg.displayText,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }
  
  Color _getGradeColor(HadithGrade grade) {
    switch (grade) {
      case HadithGrade.sahih:
        return Colors.green;
      case HadithGrade.hasan:
        return Colors.teal;
      case HadithGrade.daif:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _buildMetadataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, WidgetRef ref, bool isRead) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildActionButton(Icons.copy, 'Copy', () {
          Clipboard.setData(ClipboardData(text: hadith.shareableText));
          HapticFeedback.lightImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Hadith copied'),
              backgroundColor: const Color(0xFFC2A366).withValues(alpha: 0.9),
              duration: const Duration(seconds: 1),
            ),
          );
        }),
        const SizedBox(width: 16),
        _buildActionButton(Icons.share, 'Share', () {
          Share.share(hadith.shareableText);
        }),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.5), size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildNextHadithButton(BuildContext context, WidgetRef ref, int currentIndex) {
    final nextHadith = allHadiths![currentIndex + 1];
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        // Replace current screen with next hadith
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (context) => HadithReaderScreen(
              hadith: nextHadith,
              allHadiths: allHadiths,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFC2A366).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFC2A366).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Next Hadith',
              style: TextStyle(
                color: Color(0xFFC2A366),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward,
              color: const Color(0xFFC2A366),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

