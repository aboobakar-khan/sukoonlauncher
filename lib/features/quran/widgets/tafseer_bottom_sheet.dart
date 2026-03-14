import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/quran_provider.dart';
import '../services/tafseer_service.dart';
import '../../../providers/tafseer_edition_provider.dart';
import '../../../providers/islamic_theme_provider.dart';

/// Bottom sheet for displaying Tafseer content with clean formatting
class TafseerBottomSheet extends ConsumerWidget {
  final int surahId;
  final int ayahId;
  final String surahName;

  const TafseerBottomSheet({
    super.key,
    required this.surahId,
    required this.ayahId,
    required this.surahName,
  });

  static void show(BuildContext context, {
    required int surahId,
    required int ayahId,
    required String surahName,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TafseerBottomSheet(
        surahId: surahId,
        ayahId: ayahId,
        surahName: surahName,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tafseerAsync = ref.watch(tafseerProvider((surahId: surahId, ayahId: ayahId)));
    final selectedEdition = ref.watch(selectedTafseerEditionProvider);
    final tc = ref.watch(islamicThemeColorsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: tc.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: tc.border, width: 1),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: tc.textSecondary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: tc.green.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.menu_book_rounded,
                        color: tc.green.withValues(alpha: 0.6),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tafseer edition selector — tap to change
                          GestureDetector(
                            onTap: () => _showEditionPicker(context, ref),
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    selectedEdition.name,
                                    style: TextStyle(
                                      color: tc.text.withValues(alpha: 0.85),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: tc.accent.withValues(alpha: 0.6),
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '$surahName • Ayah $ayahId',
                            style: TextStyle(
                              color: tc.textSecondary.withValues(alpha: 0.45),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Copy button
                    IconButton(
                      onPressed: () {
                        final tafseer = tafseerAsync.valueOrNull;
                        if (tafseer != null) {
                          Clipboard.setData(ClipboardData(text: tafseer.text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Copied to clipboard'),
                              backgroundColor: tc.accent,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        }
                      },
                      icon: Icon(
                        Icons.copy_outlined,
                        color: tc.textSecondary.withValues(alpha: 0.6),
                        size: 20,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close,
                        color: tc.textSecondary.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              
              Divider(color: tc.border, height: 1),
              
              // Content
              Expanded(
                child: tafseerAsync.when(
                  data: (tafseer) {
                    if (tafseer == null || tafseer.text.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: tc.textSecondary.withValues(alpha: 0.4),
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Tafseer not available',
                              style: TextStyle(
                                color: tc.textSecondary,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try selecting a different edition in Settings',
                              style: TextStyle(
                                color: tc.textSecondary.withValues(alpha: 0.5),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    
                    return SingleChildScrollView(
                      controller: scrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        tafseer.text,
                        style: TextStyle(
                          color: tc.text.withValues(alpha: 0.85),
                          fontSize: 17,
                          height: 1.9,
                          letterSpacing: 0.2,
                        ),
                      ),
                    );
                  },
                  loading: () => Center(
                    child: CircularProgressIndicator(
                      color: tc.green.withValues(alpha: 0.5),
                    ),
                  ),
                  error: (error, _) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cloud_off,
                          color: tc.textSecondary.withValues(alpha: 0.4),
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Could not load tafseer',
                          style: TextStyle(
                            color: tc.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Check your internet connection',
                          style: TextStyle(
                            color: tc.textSecondary.withValues(alpha: 0.5),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Edition picker — switch tafseer right from the bottom sheet
  void _showEditionPicker(BuildContext context, WidgetRef ref) {
    final editionsAsync = ref.read(tafseerEditionsProvider);

    editionsAsync.whenData((editions) {
      final sortedEditions = [...editions];
      sortedEditions.sort((a, b) {
        if (a.language.toLowerCase() == 'english' && b.language.toLowerCase() != 'english') return -1;
        if (a.language.toLowerCase() != 'english' && b.language.toLowerCase() == 'english') return 1;
        return a.name.compareTo(b.name);
      });

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => Consumer(
          builder: (ctx, innerRef, _) {
            final selected = innerRef.watch(selectedTafseerEditionProvider);
            final colors = innerRef.watch(islamicThemeColorsProvider);
            return Container(
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: colors.textSecondary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Choose Tafseer',
                      style: TextStyle(
                        color: colors.text.withValues(alpha: 0.85),
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 300,
                      child: ListView.builder(
                        itemCount: sortedEditions.length,
                        itemBuilder: (ctx, i) {
                          final edition = sortedEditions[i];
                          final isSelected = selected.slug == edition.slug;
                          return _EditionPickerTile(
                            edition: edition,
                            isSelected: isSelected,
                            colors: colors,
                            onSelect: () {
                              innerRef.read(selectedTafseerEditionProvider.notifier).setEdition(edition);
                              Navigator.pop(ctx);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    });
  }
}

/// Stateful tile for each edition with download support
class _EditionPickerTile extends StatefulWidget {
  final TafseerEdition edition;
  final bool isSelected;
  final IslamicThemeColors colors;
  final VoidCallback onSelect;

  const _EditionPickerTile({
    required this.edition,
    required this.isSelected,
    required this.colors,
    required this.onSelect,
  });

  @override
  State<_EditionPickerTile> createState() => _EditionPickerTileState();
}

class _EditionPickerTileState extends State<_EditionPickerTile> {
  bool _isDownloading = false;
  bool _isFullDownloaded = false;
  int _downloadedCount = 0;

  @override
  void initState() {
    super.initState();
    _checkDownloadStatus();
  }

  Future<void> _checkDownloadStatus() async {
    final service = TafseerService();
    final isFullDownloaded = await service.isFullTafseerDownloaded(edition: widget.edition.slug);
    final count = await service.getDownloadedSurahCount(edition: widget.edition.slug);
    if (mounted) {
      setState(() {
        _isFullDownloaded = isFullDownloaded;
        _downloadedCount = count;
      });
    }
  }

  Future<void> _downloadFullTafseer() async {
    setState(() => _isDownloading = true);
    final service = TafseerService();
    final success = await service.downloadFullTafseer(
      edition: widget.edition.slug,
      onProgress: (completed, total) {
        if (mounted) setState(() => _downloadedCount = completed);
      },
    );
    if (mounted) {
      setState(() {
        _isDownloading = false;
        _isFullDownloaded = success;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? '${widget.edition.name} – Complete tafseer downloaded!'
              : 'Some surahs failed. Tap to retry.'),
          backgroundColor: success ? const Color(0xFFA67B5B) : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return GestureDetector(
      onTap: widget.onSelect,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: widget.isSelected ? c.green.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.isSelected ? c.green.withValues(alpha: 0.3) : c.border,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.edition.name,
                    style: TextStyle(
                      color: c.text.withValues(alpha: 0.8),
                      fontSize: 14,
                      fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${widget.edition.authorName} • ${widget.edition.language}',
                    style: TextStyle(
                      color: c.textSecondary.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            // Download button
            if (_isDownloading)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_downloadedCount/114',
                    style: TextStyle(color: c.accent, fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: c.accent),
                  ),
                ],
              )
            else if (_isFullDownloaded)
              Icon(Icons.cloud_done_rounded, color: c.green.withValues(alpha: 0.7), size: 18)
            else
              GestureDetector(
                onTap: _downloadFullTafseer,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_download_outlined, color: c.accent, size: 16),
                      if (_downloadedCount > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '$_downloadedCount/114',
                          style: TextStyle(color: c.accent, fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            if (widget.isSelected) ...[
              const SizedBox(width: 8),
              Icon(Icons.check_rounded, color: c.green, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}
