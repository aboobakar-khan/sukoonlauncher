import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';

/// Play Store review URL — opens directly to the Write a Review dialog.
const _storeUrl =
    'https://play.google.com/store/apps/details?id=com.sukoon.launcher'
    '&showAllReviews=true';

/// Requests a review.
///
/// Strategy:
/// 1. Try the native in-app review dialog (works when Google's quota allows it).
/// 2. Always open the Play Store page as well so the user can definitely leave a review.
///    Google's quota silently suppresses the native dialog with no feedback —
///    opening the store page ensures the tap is never a dead end.
Future<void> requestSukoonReview() async {
  // Try native dialog first (bonus — may show for Play Store installs)
  try {
    final inAppReview = InAppReview.instance;
    final available = await inAppReview.isAvailable();
    if (available) {
      await inAppReview.requestReview();
    }
  } catch (_) {
    // Ignore — fall through to store page
  }
  // Always open the Play Store page so the tap is never a dead end
  await _openPlayStore();
}

Future<void> _openPlayStore() async {
  final uri = Uri.parse(_storeUrl);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
