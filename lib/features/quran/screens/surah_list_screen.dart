import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/quran_provider.dart';
import '../models/surah.dart';
import 'surah_reader_screen.dart';

class SurahListScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  
  const SurahListScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<SurahListScreen> createState() => _SurahListScreenState();
}

class _SurahListScreenState extends ConsumerState<SurahListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Surah> _filteredSurahs = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _filterSurahs(List<Surah> allSurahs, String query) {
    if (query.isEmpty) {
      _filteredSurahs = allSurahs;
    } else {
      _filteredSurahs = allSurahs.where((surah) {
        final searchLower = query.toLowerCase();
        return surah.name.toLowerCase().contains(searchLower) ||
            surah.transliteration.toLowerCase().contains(searchLower) ||
            surah.id.toString().contains(searchLower);
      }).toList();
    }
  }

  void _navigateToSurah(Surah surah, {int? scrollToAyah}) {
    ref.read(selectedSurahProvider.notifier).state = surah;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SurahReaderScreen(
          surah: surah,
          initialAyah: scrollToAyah,
        ),
      ),
    );
  }

  Future<void> _resumeReading(LastReadPosition position, List<Surah> surahs) async {
    HapticFeedback.mediumImpact();
    
    // Find the surah
    final surah = surahs.firstWhere(
      (s) => s.id == position.surahId,
      orElse: () => surahs.first,
    );
    
    _navigateToSurah(surah, scrollToAyah: position.ayahNumber);
  }

  @override
  Widget build(BuildContext context) {
    final surahsAsync = ref.watch(surahsProvider);
    final readingProgress = ref.watch(readingProgressProvider);

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.3),
      body: SafeArea(
        child: Column(
          children: [
          // Resume Reading Card
          if (!readingProgress.isLoading && readingProgress.lastPosition != null)
            surahsAsync.when(
              data: (surahs) => _buildResumeReadingCard(readingProgress.lastPosition!, surahs),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          
          // Collapsible search - icon only when not searching
          if (_isSearching)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'search...',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 13,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Colors.white.withValues(alpha: 0.4),
                          size: 16,
                        ),
                        prefixIconConstraints: const BoxConstraints(minWidth: 36),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.06),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (value) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _searchController.clear();
                        _isSearching = false;
                      });
                    },
                    child: Text(
                      'cancel',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            // Just a subtle search hint row
            GestureDetector(
              onTap: () => setState(() => _isSearching = true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.search,
                      color: Colors.white.withValues(alpha: 0.25),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'search',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.25),
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Surah List
          Expanded(
            child: surahsAsync.when(
              data: (surahs) {
                _filterSurahs(surahs, _searchController.text);

                if (_filteredSurahs.isEmpty) {
                  return Center(
                    child: Text(
                      'No Surah found',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 16,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  physics: const BouncingScrollPhysics(
                    decelerationRate: ScrollDecelerationRate.fast,
                  ),
                  cacheExtent: 500,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filteredSurahs.length,
                  itemBuilder: (context, index) {
                    final surah = _filteredSurahs[index];
                    return Card(
                      color: const Color(0xFF1A1A1A),
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: const Color(0xFFC2A366).withValues(alpha: 0.08),
                        ),
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFC2A366).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                            '${surah.id}',
                            style: const TextStyle(
                              color: Color(0xFFC2A366),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                surah.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                ),
                                textDirection: TextDirection.rtl,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              surah.transliteration,
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              surah.type == 'meccan' ? 'Meccan' : 'Medinan',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '${surah.totalVerses} verses',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          color: const Color(0xFFC2A366).withValues(alpha: 0.4),
                          size: 14,
                        ),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _navigateToSurah(surah);
                        },
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFFC2A366)),
              ),
              error: (error, stack) => Center(
                child: Text(
                  'Error loading Quran: $error',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildResumeReadingCard(LastReadPosition position, List<Surah> surahs) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      decoration: BoxDecoration(
        color: const Color(0xFFC2A366).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFC2A366).withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _resumeReading(position, surahs),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Play icon
                const Icon(
                  Icons.play_circle_filled,
                  color: Color(0xFFC2A366),
                  size: 18,
                ),
                const SizedBox(width: 10),
                
                // Text - single line
                Expanded(
                  child: RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: const TextStyle(fontSize: 13),
                      children: [
                        TextSpan(
                          text: position.surahTransliteration,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        TextSpan(
                          text: '  ·  ayah ${position.ayahNumber}/${position.totalVerses}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Arrow
                Icon(
                  Icons.chevron_right,
                  color: const Color(0xFFC2A366).withValues(alpha: 0.7),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
