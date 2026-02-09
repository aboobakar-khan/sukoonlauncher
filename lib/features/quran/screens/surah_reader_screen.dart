import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/surah.dart';
import '../providers/quran_provider.dart';
import '../widgets/tafseer_bottom_sheet.dart';
import '../../../providers/arabic_font_provider.dart';
import '../../../providers/tafseer_edition_provider.dart';

// ─── Warm Reading Palette ────────────────────────────────────────────────────
const Color _creamBg = Color(0xFFFDF6EC);
const Color _warmSand = Color(0xFFF5E6C8);
const Color _richBrown = Color(0xFF2C1810);
const Color _warmBrown = Color(0xFF5C4033);
const Color _goldAccent = Color(0xFFC2A366);
const Color _islamicGreen = Color(0xFF2E7D32);
const Color _lightGreen = Color(0xFF43A047);

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
          child: versesAsync.when(
            data: (verses) {
              if (verses.isEmpty) {
                return const Center(
                  child: Text('No verses available', style: TextStyle(color: _warmBrown)),
                );
              }
              if (widget.initialAyah != null && !_hasScrolledToInitial) {
                _scrollToAyah(widget.initialAyah!, verses.length);
              }
              return Column(
                children: [
                  // ── Top Bar ──
                  _buildTopBar(),
                  // ── Sub-header ──
                  _buildSubHeader(),
                  // ── Progress bar ──
                  _buildProgressBar(),
                  // ── Verses ──
                  Expanded(
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification.metrics.maxScrollExtent > 0) {
                          final progress = notification.metrics.pixels /
                              notification.metrics.maxScrollExtent;
                          setState(() => _readingProgress = progress.clamp(0.0, 1.0));
                          final visibleAyah = (progress * verses.length).ceil();
                          final clampedAyah = visibleAyah.clamp(1, verses.length);
                          if (progress >= 0.95) {
                            _saveReadingProgress(verses.length);
                          } else {
                            _saveReadingProgress(clampedAyah);
                          }
                        } else {
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
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        itemCount: verses.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) return _buildSurahBanner();
                          final verse = verses[index - 1];
                          final isHighlighted = widget.initialAyah != null &&
                              verse.id == widget.initialAyah;
                          final isLast = index == verses.length;
                          return _buildVerseItem(verse, arabicFont, isHighlighted, isLast);
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(color: _goldAccent, strokeWidth: 2),
            ),
            error: (error, stack) => Center(
              child: Text('Error: $error', style: const TextStyle(color: Colors.red)),
            ),
          ),
        ),
      ),
    );
  }

  // ── Top Bar — warm cream, matching reference ──
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
      color: _creamBg,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: _richBrown, size: 22),
          ),
          Text(
            widget.surah.transliteration,
            style: const TextStyle(color: _richBrown, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          Icon(Icons.arrow_drop_down, color: _warmBrown.withOpacity(0.6), size: 22),
          const Spacer(),
          IconButton(
            onPressed: _isDownloading ? null : _downloadTafseer,
            icon: _isDownloading
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: _goldAccent))
                : Icon(
                    _isDownloaded ? Icons.cloud_done_rounded : Icons.info_outline_rounded,
                    color: _isDownloaded ? _islamicGreen : _warmBrown, size: 22),
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.settings_outlined, color: _warmBrown.withOpacity(0.6), size: 22),
          ),
        ],
      ),
    );
  }

  // ── Sub-header: surah meaning + reading goal ──
  Widget _buildSubHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 16, 6),
      child: Row(
        children: [
          Text(
            '${widget.surah.id}. ${_getSurahMeaning(widget.surah.transliteration)}',
            style: TextStyle(color: _warmBrown.withOpacity(0.6), fontSize: 13),
          ),
          const Spacer(),
          Text('Reading goal: ', style: TextStyle(color: _warmBrown.withOpacity(0.45), fontSize: 12)),
          Text(
            '${(_readingProgress * widget.surah.totalVerses).round()}/${widget.surah.totalVerses}',
            style: TextStyle(color: _warmBrown.withOpacity(0.65), fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 6),
          SizedBox(width: 18, height: 18,
            child: CircularProgressIndicator(
              value: _readingProgress, strokeWidth: 2,
              backgroundColor: _warmSand, color: _islamicGreen.withOpacity(0.5))),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: _warmBrown.withOpacity(0.35), size: 16),
        ],
      ),
    );
  }

  // ── Thin progress bar ──
  Widget _buildProgressBar() {
    return Container(
      height: 2.5, width: double.infinity,
      color: _warmSand.withOpacity(0.5),
      child: Align(
        alignment: Alignment.centerLeft,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 2.5,
          width: MediaQuery.of(context).size.width * _readingProgress,
          decoration: BoxDecoration(
            color: _islamicGreen.withOpacity(0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  // ── Ornamental Surah Banner — green header matching reference ──
  Widget _buildSurahBanner() {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 28),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_islamicGreen, Color(0xFF388E3C), _lightGreen],
          begin: Alignment.centerLeft, end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _islamicGreen.withOpacity(0.4), width: 2),
        boxShadow: [
          BoxShadow(color: _islamicGreen.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          _buildFlowerOrnament(),
          const Spacer(),
          Text(
            widget.surah.name,
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w500, height: 1.4),
            textDirection: TextDirection.rtl,
          ),
          const Spacer(),
          _buildFlowerOrnament(),
        ],
      ),
    );
  }

  Widget _buildFlowerOrnament() {
    return Container(
      width: 34, height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
      ),
      child: const Center(child: Text('✿', style: TextStyle(fontSize: 15, color: Colors.white))),
    );
  }

  // ── Individual Verse ──
  Widget _buildVerseItem(dynamic verse, dynamic arabicFont, bool isHighlighted, bool isLast) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: isHighlighted ? const EdgeInsets.all(12) : EdgeInsets.zero,
      decoration: isHighlighted
          ? BoxDecoration(
              color: _goldAccent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _goldAccent.withOpacity(0.2)),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          // ── Aya label chip (matching reference: "Aya 1:1 ˅") ──
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  TafseerBottomSheet.show(context,
                    surahId: widget.surah.id, ayahId: verse.id,
                    surahName: widget.surah.transliteration);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: _warmSand.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Aya ${widget.surah.id}:${verse.id}',
                      style: TextStyle(color: _warmBrown.withOpacity(0.55), fontSize: 12, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 3),
                    Icon(Icons.expand_more, color: _islamicGreen.withOpacity(0.5), size: 15),
                  ]),
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 20),
          // ── Arabic text with ornamental verse marker ──
          Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 38),
                child: Text(
                  verse.arabic,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    color: _richBrown,
                    fontSize: 28,
                    height: 2.0,
                    fontWeight: FontWeight.w400,
                    fontFamily: arabicFont.fontFamily,
                  ),
                ),
              ),
              Positioned(
                left: 0, top: 8,
                child: _buildVerseMarker(verse.id),
              ),
            ],
          ),
          // ── Translation ──
          if (verse.translation != null) ...[
            const SizedBox(height: 16),
            Text(
              verse.translation!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _richBrown.withOpacity(0.7),
                fontSize: 15,
                height: 1.7,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
          const SizedBox(height: 28),
          if (!isLast) _buildVerseDivider(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ── Ornamental verse marker ──
  Widget _buildVerseMarker(int num) {
    return SizedBox(
      width: 30, height: 30,
      child: Stack(alignment: Alignment.center, children: [
        Container(width: 30, height: 30,
          decoration: BoxDecoration(shape: BoxShape.circle,
            border: Border.all(color: _goldAccent.withOpacity(0.35), width: 1.5))),
        Container(width: 22, height: 22,
          decoration: BoxDecoration(shape: BoxShape.circle,
            border: Border.all(color: _goldAccent.withOpacity(0.2), width: 1))),
        Text('$num', style: TextStyle(color: _warmBrown.withOpacity(0.55), fontSize: 9, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  // ── Elegant divider ──
  Widget _buildVerseDivider() {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 28, height: 0.5, color: _goldAccent.withOpacity(0.15)),
      const SizedBox(width: 8),
      Text('·', style: TextStyle(color: _goldAccent.withOpacity(0.3), fontSize: 10)),
      const SizedBox(width: 6),
      Text('✦', style: TextStyle(color: _goldAccent.withOpacity(0.2), fontSize: 7)),
      const SizedBox(width: 6),
      Text('·', style: TextStyle(color: _goldAccent.withOpacity(0.3), fontSize: 10)),
      const SizedBox(width: 8),
      Container(width: 28, height: 0.5, color: _goldAccent.withOpacity(0.15)),
    ]);
  }

  String _getSurahMeaning(String t) {
    const m = {'Al-Faatiha':'The Opener','Al-Baqara':'The Cow','Aal-i-Imraan':'Family of Imran',
      'An-Nisaa':'The Women','Al-Maaida':'The Table','Al-An\'aam':'The Cattle',
      'Al-A\'raaf':'The Heights','Al-Anfaal':'Spoils of War','At-Tawba':'Repentance',
      'Yunus':'Jonah','Hud':'Hud','Yusuf':'Joseph','Ar-Ra\'d':'Thunder',
      'Ibrahim':'Abraham','An-Nahl':'The Bee','Al-Kahf':'The Cave','Maryam':'Mary',
      'Ya-Sin':'Ya-Sin','Ar-Rahmaan':'The Merciful','Al-Mulk':'Dominion',
      'Al-Ikhlaas':'Sincerity','Al-Falaq':'Daybreak','An-Naas':'Mankind'};
    return m[t] ?? '';
  }
}
