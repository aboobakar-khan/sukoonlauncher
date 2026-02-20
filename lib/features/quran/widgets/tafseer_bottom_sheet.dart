import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/quran_provider.dart';
import '../../../providers/tafseer_edition_provider.dart';

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

  // Warm reading palette
  static const _creamBg = Color(0xFFFDF6EC);
  static const _warmSand = Color(0xFFF5E6C8);
  static const _richBrown = Color(0xFF2C1810);
  static const _warmBrown = Color(0xFF5C4033);
  static const _gold = Color(0xFFC2A366);
  static const _islamicGreen = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tafseerAsync = ref.watch(tafseerProvider((surahId: surahId, ayahId: ayahId)));
    final selectedEdition = ref.watch(selectedTafseerEditionProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: _creamBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: _warmSand, width: 1),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _warmBrown.withOpacity(0.2),
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
                        color: _islamicGreen.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.menu_book_rounded,
                        color: _islamicGreen.withOpacity(0.6),
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
                                      color: _richBrown.withOpacity(0.85),
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
                                  color: _gold.withOpacity(0.6),
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '$surahName • Ayah $ayahId',
                            style: TextStyle(
                              color: _warmBrown.withOpacity(0.45),
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
                              backgroundColor: _gold,
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
                        color: _warmBrown.withOpacity(0.6),
                        size: 20,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close,
                        color: _warmBrown.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              
              Divider(color: _warmSand, height: 1),
              
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
                              color: _warmBrown.withOpacity(0.4),
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Tafseer not available',
                              style: TextStyle(
                                color: _warmBrown,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try selecting a different edition in Settings',
                              style: TextStyle(
                                color: _warmBrown.withOpacity(0.5),
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
                          color: _richBrown.withOpacity(0.85),
                          fontSize: 17,
                          height: 1.9,
                          letterSpacing: 0.2,
                        ),
                      ),
                    );
                  },
                  loading: () => Center(
                    child: CircularProgressIndicator(
                      color: _islamicGreen.withOpacity(0.5),
                    ),
                  ),
                  error: (error, _) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cloud_off,
                          color: _warmBrown.withOpacity(0.4),
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Could not load tafseer',
                          style: TextStyle(
                            color: _warmBrown,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Check your internet connection',
                          style: TextStyle(
                            color: _warmBrown.withOpacity(0.5),
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
        backgroundColor: _creamBg,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => Consumer(
          builder: (ctx, innerRef, _) {
            final selected = innerRef.watch(selectedTafseerEditionProvider);
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: _warmBrown.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Choose Tafseer',
                    style: TextStyle(
                      color: _richBrown.withOpacity(0.85),
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
                        return GestureDetector(
                          onTap: () {
                            innerRef.read(selectedTafseerEditionProvider.notifier).setEdition(edition);
                            Navigator.pop(ctx);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? _islamicGreen.withOpacity(0.08) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? _islamicGreen.withOpacity(0.3) : _warmSand,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        edition.name,
                                        style: TextStyle(
                                          color: _richBrown.withOpacity(0.8),
                                          fontSize: 14,
                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${edition.authorName} • ${edition.language}',
                                        style: TextStyle(
                                          color: _warmBrown.withOpacity(0.5),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Icon(Icons.check_rounded, color: _islamicGreen, size: 20),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    });
  }
}
