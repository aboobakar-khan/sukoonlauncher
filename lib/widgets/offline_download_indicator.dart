import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/offline_content_manager.dart';
import '../providers/theme_provider.dart';

/// Enhanced Offline Content Download Indicator
/// 
/// Shows detailed progress when downloading content
/// Can be tapped to see full download status
class OfflineDownloadIndicator extends ConsumerWidget {
  const OfflineDownloadIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(offlineContentProvider);
    final themeColor = ref.watch(themeColorProvider);
    
    // Don't show if core content complete and tafseer isn't actively downloading
    if (status.isComplete && !status.isDownloading) return const SizedBox.shrink();
    
    // Don't show if not downloading and no error
    if (!status.isDownloading && status.error == null) {
      return const SizedBox.shrink();
    }
    
    return GestureDetector(
      onTap: () => _showDownloadDetails(context, ref),
      child: AnimatedOpacity(
        opacity: status.isDownloading || status.error != null ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Progress indicator
              if (status.isDownloading) ...[
                Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        value: status.progress,
                        strokeWidth: 2,
                        color: themeColor.color.withValues(alpha: 0.7),
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            status.currentItem ?? 'Preparing offline content...',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: status.progress,
                              backgroundColor: Colors.white.withValues(alpha: 0.1),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                themeColor.color.withValues(alpha: 0.6),
                              ),
                              minHeight: 3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(status.progress * 100).toInt()}%',
                      style: TextStyle(
                        color: themeColor.color.withValues(alpha: 0.7),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
              
              // Error state with retry
              if (status.error != null && !status.isDownloading) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_off,
                      color: Colors.white.withValues(alpha: 0.3),
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Offline content pending',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        ref.read(offlineContentProvider.notifier).retryDownload();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: themeColor.color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Retry',
                          style: TextStyle(
                            color: themeColor.color,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showDownloadDetails(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const OfflineDownloadSheet(),
    );
  }
}

/// Full download status sheet
class OfflineDownloadSheet extends ConsumerWidget {
  const OfflineDownloadSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(offlineContentProvider);
    final themeColor = ref.watch(themeColorProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Title
          Row(
            children: [
              Icon(
                status.isComplete ? Icons.cloud_done : Icons.cloud_download,
                color: status.isComplete 
                    ? Colors.green 
                    : themeColor.color,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Offline Content',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Status items
          _buildStatusItem(
            'Duas',
            status.duaComplete,
            status.duaComplete ? 'Downloaded' : 'Pending',
            themeColor,
          ),
          _buildStatusItem(
            'Hadiths',
            status.hadithComplete,
            status.hadithComplete 
                ? '${status.hadithsDownloaded} hadiths' 
                : 'Downloading...',
            themeColor,
          ),
          _buildTafseerItem(
            status,
            themeColor,
            ref,
          ),

          const SizedBox(height: 20),

          // Progress bar (if downloading)
          if (status.isDownloading) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: status.progress,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation(themeColor.color),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              status.currentItem ?? 'Preparing...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ],

          // Last download time
          if (status.lastDownloadTime != null) ...[
            const SizedBox(height: 12),
            Text(
              'Last updated: ${_formatTime(status.lastDownloadTime!)}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 11,
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Actions
          Row(
            children: [
              if (status.isDownloading)
                Expanded(
                  child: _buildActionButton(
                    'Pause',
                    Icons.pause,
                    Colors.orange,
                    () => ref.read(offlineContentProvider.notifier).pauseDownload(),
                  ),
                )
              else if (!status.isComplete)
                Expanded(
                  child: _buildActionButton(
                    'Start Download',
                    Icons.download,
                    Colors.green,
                    () => ref.read(offlineContentProvider.notifier).forceStartDownload(),
                  ),
                ),
              if (!status.isDownloading) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    'Re-download All',
                    Icons.refresh,
                    Colors.blue,
                    () {
                      Navigator.pop(context);
                      ref.read(offlineContentProvider.notifier).redownloadAll();
                    },
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String title, bool isComplete, String subtitle, AppThemeColor themeColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isComplete 
                  ? Colors.green.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isComplete ? Icons.check : Icons.hourglass_empty,
              color: isComplete ? Colors.green : Colors.white.withValues(alpha: 0.3),
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${time.day}/${time.month}/${time.year}';
  }

  /// Tafseer row with download button (user-initiated only)
  Widget _buildTafseerItem(DownloadStatus status, AppThemeColor themeColor, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: status.tafseerComplete 
                  ? Colors.green.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              status.tafseerComplete ? Icons.check : Icons.menu_book_rounded,
              color: status.tafseerComplete ? Colors.green : Colors.white.withValues(alpha: 0.3),
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tafseer',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  status.tafseerComplete 
                      ? 'All 114 surahs' 
                      : status.tafseersDownloaded > 0 
                          ? '${status.tafseersDownloaded}/114 surahs'
                          : 'Not downloaded',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Download / Downloading button
          if (!status.tafseerComplete)
            GestureDetector(
              onTap: status.isDownloading ? null : () {
                ref.read(offlineContentProvider.notifier).downloadTafseerManually();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: status.isDownloading 
                      ? Colors.white.withValues(alpha: 0.05)
                      : themeColor.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: status.isDownloading 
                        ? Colors.white.withValues(alpha: 0.1)
                        : themeColor.color.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (status.isDownloading)
                      SizedBox(
                        width: 12, height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      )
                    else
                      Icon(Icons.download_rounded, color: themeColor.color, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      status.isDownloading ? 'Downloading...' : 'Download',
                      style: TextStyle(
                        color: status.isDownloading 
                            ? Colors.white.withValues(alpha: 0.5) 
                            : themeColor.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Compact status icon for settings or status bar
class OfflineStatusIcon extends ConsumerWidget {
  const OfflineStatusIcon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(offlineContentProvider);
    final themeColor = ref.watch(themeColorProvider);
    
    if (status.isComplete) {
      return Icon(
        Icons.cloud_done,
        color: Colors.green.withValues(alpha: 0.7),
        size: 18,
      );
    }
    
    if (status.isDownloading) {
      return SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          value: status.progress,
          strokeWidth: 2,
          color: themeColor.color.withValues(alpha: 0.6),
        ),
      );
    }
    
    return Icon(
      Icons.cloud_off,
      color: Colors.white.withValues(alpha: 0.3),
      size: 18,
    );
  }
}
