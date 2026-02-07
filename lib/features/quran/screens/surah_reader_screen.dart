import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/surah.dart';
import '../providers/quran_provider.dart';
import '../widgets/tafseer_bottom_sheet.dart';
import '../../../providers/arabic_font_provider.dart';
import '../../../providers/tafseer_edition_provider.dart';

class SurahReaderScreen extends ConsumerStatefulWidget {
  final Surah surah;
  final int? initialAyah;

  const SurahReaderScreen({
    super.key, 
    required this.surah,
    this.initialAyah,
  });

  @override
  ConsumerState<SurahReaderScreen> createState() => _SurahReaderScreenState();
}

class _SurahReaderScreenState extends ConsumerState<SurahReaderScreen> {
  bool _isDownloading = false;
  bool _isDownloaded = false;
  final ScrollController _scrollController = ScrollController();
  
  // For tracking visible verse
  int _currentVisibleAyah = 1;
  bool _hasScrolledToInitial = false;
  
  // Reading progress (0.0 to 1.0)
  double _readingProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _checkDownloadStatus();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Debounce scroll events to avoid excessive saves
    // We'll save progress when a new ayah comes into view
  }

  Future<void> _checkDownloadStatus() async {
    final service = ref.read(tafseerServiceProvider);
    final edition = ref.read(selectedTafseerEditionProvider);
    final downloaded = await service.isSurahDownloaded(widget.surah.id, edition: edition.slug);
    if (mounted) {
      setState(() => _isDownloaded = downloaded);
    }
  }

  Future<void> _downloadTafseer() async {
    setState(() => _isDownloading = true);

    final service = ref.read(tafseerServiceProvider);
    final edition = ref.read(selectedTafseerEditionProvider);
    final success = await service.downloadSurahTafseer(
      widget.surah.id,
      widget.surah.totalVerses,
      edition: edition.slug,
    );

    if (mounted) {
      setState(() {
        _isDownloading = false;
        _isDownloaded = success;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? '${edition.name} downloaded for offline'
              : 'Failed to download tafseer'),
          backgroundColor: success ? const Color(0xFFA67B5B) : Colors.red,
        ),
      );
    }
  }

  void _saveReadingProgress(int ayahNumber) {
    if (ayahNumber != _currentVisibleAyah) {
      _currentVisibleAyah = ayahNumber;
      ref.read(readingProgressProvider.notifier).saveProgress(
        surahId: widget.surah.id,
        surahName: widget.surah.name,
        surahTransliteration: widget.surah.transliteration,
        ayahNumber: ayahNumber,
        totalVerses: widget.surah.totalVerses,
      );
    }
  }

  void _scrollToAyah(int ayahNumber, int totalVerses) {
    if (_hasScrolledToInitial) return;
    _hasScrolledToInitial = true;

    // Calculate approximate scroll position
    // Each verse card is roughly 200-300 pixels tall
    const estimatedCardHeight = 280.0;
    final scrollPosition = (ayahNumber - 1) * estimatedCardHeight;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final targetPosition = scrollPosition.clamp(0.0, maxScroll);
        
        _scrollController.animateTo(
          targetPosition,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final versesAsync = ref.watch(versesProvider(widget.surah.id));
    final arabicFont = ref.watch(arabicFontProvider);

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.3),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              widget.surah.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              widget.surah.transliteration,
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          // Download tafseer button
          IconButton(
            onPressed: _isDownloading ? null : _downloadTafseer,
            icon: _isDownloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFC2A366),
                    ),
                  )
                : Icon(
                    _isDownloaded ? Icons.cloud_done : Icons.cloud_download_outlined,
                    color: _isDownloaded ? const Color(0xFFC2A366) : Colors.white70,
                  ),
            tooltip: _isDownloaded ? 'Tafseer available offline' : 'Download tafseer for offline',
          ),
        ],
      ),
      body: versesAsync.when(
        data: (verses) {
          if (verses.isEmpty) {
            return const Center(
              child: Text(
                'No verses available',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          // Scroll to initial ayah if specified
          if (widget.initialAyah != null && !_hasScrolledToInitial) {
            _scrollToAyah(widget.initialAyah!, verses.length);
          }

          return Column(
            children: [
              // Reading progress bar - thin horizontal line
              Container(
                height: 3,
                width: double.infinity,
                color: Colors.grey[900],
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 3,
                    width: MediaQuery.of(context).size.width * _readingProgress,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFC2A366),
                          const Color(0xFFC2A366).withValues(alpha: 0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              
              // Verses list
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    // Track scroll progress
                    if (notification.metrics.maxScrollExtent > 0) {
                      final progress = notification.metrics.pixels / 
                          notification.metrics.maxScrollExtent;
                      setState(() {
                        _readingProgress = progress.clamp(0.0, 1.0);
                      });
                      
                      // Calculate visible ayah based on scroll progress
                      // This is more accurate than fixed card height
                      final visibleAyah = (progress * verses.length).ceil();
                      final clampedAyah = visibleAyah.clamp(1, verses.length);
                      
                      // If scrolled to near the end (95%+), mark as reading last verse
                      if (progress >= 0.95) {
                        _saveReadingProgress(verses.length);
                      } else {
                        _saveReadingProgress(clampedAyah);
                      }
                    } else {
                      // Single verse surah or very short content
                      _saveReadingProgress(verses.length);
                    }
                    return false;
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(
                      decelerationRate: ScrollDecelerationRate.fast,
                    ),
                    cacheExtent: 800,
                    padding: const EdgeInsets.all(16),
              itemCount: verses.length,
              itemBuilder: (context, index) {
                final verse = verses[index];
                final isHighlighted = widget.initialAyah != null && verse.id == widget.initialAyah;
                
                return Card(
                  color: isHighlighted 
                      ? const Color(0xFFC2A366).withValues(alpha: 0.15)
                      : Colors.grey[900],
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: isHighlighted 
                      ? RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(
                            color: Color(0xFFC2A366),
                            width: 2,
                          ),
                        )
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Verse number and tafseer button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: isHighlighted
                                  ? const Color(0xFFC2A366)
                                  : const Color(0xFFC2A366).withValues(alpha: 0.15),
                              child: Text(
                                '${verse.id}',
                                style: TextStyle(
                                  color: isHighlighted
                                      ? Colors.white
                                      : const Color(0xFFC2A366),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            // Tafseer button
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                TafseerBottomSheet.show(
                                  context,
                                  surahId: widget.surah.id,
                                  ayahId: verse.id,
                                  surahName: widget.surah.transliteration,
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFA67B5B).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFC2A366).withValues(alpha: 0.4),
                                    width: 1,
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.menu_book_outlined,
                                      size: 14,
                                      color: Color(0xFFC2A366),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Tafseer',
                                      style: TextStyle(
                                        color: Color(0xFFC2A366),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Arabic text
                        Text(
                          verse.arabic,
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            height: 2.0,
                            fontWeight: FontWeight.w500,
                            fontFamily: arabicFont.fontFamily,
                          ),
                        ),
                        // English translation
                        if (verse.translation != null) ...[
                          const SizedBox(height: 16),
                          const Divider(color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            verse.translation!,
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              color: Colors.grey[300],
                              fontSize: 16,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
            ],
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Color(0xFFC2A366))),
        error: (error, stack) => Center(
          child: Text(
            'Error loading verses: $error',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ),
    );
  }
}
