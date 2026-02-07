import 'package:flutter/material.dart';

/// Privacy Policy Screen - Full privacy policy for Play Store compliance
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _buildPrivacyPolicyContent(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Privacy Policy',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w300,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyPolicyContent(BuildContext context) {
    final today = DateTime.now();
    final formattedDate = '${today.day}/${today.month}/${today.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection(
          title: 'Last updated: $formattedDate',
          content:
              'Camel Launcher ("we", "our", or "the app") is a minimalist launcher application. Your privacy is very important to us. This Privacy Policy explains how we handle information when you use our application.\n\nBy using this app, you agree to the practices described in this policy.',
        ),
        const SizedBox(height: 24),
        _buildSection(
          title: '1. Information We Collect',
          content:
              '• We do not collect, store, or sell any personal data.\n\n'
              '• All user preferences such as wallpaper selection, favorites, and settings are stored locally on your device only.\n\n'
              '• We do not require you to create an account.',
        ),
        const SizedBox(height: 24),
        _buildSection(
          title: '2. Microphone & Voice Recognition',
          content:
              '• The app uses the device microphone only when you manually activate the voice unlock feature.\n\n'
              '• The microphone is used temporarily to recognize spoken app names.\n\n'
              '• Audio data is not recorded, stored, transmitted, or shared.\n\n'
              '• Voice processing is handled by the device or operating system\'s speech recognition service.\n\n'
              '• The microphone is never accessed in the background.',
        ),
        const SizedBox(height: 24),
        _buildSection(
          title: '3. App Usage Access Permission',
          content:
              '• If you enable smart features such as automatic hiding of unused apps, the app may request Usage Access permission.\n\n'
              '• Usage data is processed only on your device.\n\n'
              '• We do not collect, store, or transmit app usage information.\n\n'
              '• This data is used only to improve launcher functionality (e.g., hiding unused apps).\n\n'
              '• Granting this permission is optional.',
        ),
        const SizedBox(height: 24),
        _buildSection(
          title: '4. Installed Apps Information',
          content:
              '• The app accesses the list of installed applications on your device in order to display and launch apps as part of the launcher functionality.\n\n'
              '• This information remains on your device and is not transmitted or shared.',
        ),
        const SizedBox(height: 24),
        _buildSection(
          title: '5. Qur\'an Content',
          content:
              '• The app displays Qur\'an verses for inspiration and reading purposes.\n\n'
              '• Qur\'an text is stored locally for offline use.\n\n'
              '• Translation sources are credited in the app\'s Credits section.\n\n'
              '• We do not track or collect reading activity.',
        ),
        const SizedBox(height: 24),
        _buildSection(
          title: '6. In-App Purchases',
          content:
              '• The app may offer optional in-app purchases to unlock premium features.\n\n'
              '• Payments are processed securely by Google Play.\n\n'
              '• We do not store or process payment information.',
        ),
        const SizedBox(height: 24),
        _buildSection(
          title: '7. Third-Party Services',
          content:
              'The app may use trusted third-party services such as:\n\n'
              '• Google Play Services (for purchases and system integration)\n\n'
              '• Android speech recognition services\n\n'
              'These services operate under their own privacy policies.',
        ),
        const SizedBox(height: 24),
        _buildSection(
          title: '8. Children\'s Privacy',
          content:
              'This app does not knowingly collect any personal information from children under the age of 13.',
        ),
        const SizedBox(height: 24),
        _buildSection(
          title: '9. Data Security',
          content:
              'All user data and settings are stored locally on the device. We take reasonable steps to protect the app from unauthorized access.',
        ),
        const SizedBox(height: 24),
        _buildSection(
          title: '10. Changes to This Policy',
          content:
              'We may update this Privacy Policy from time to time. Any changes will be reflected on this page.',
        ),
        const SizedBox(height: 24),
        _buildSection(
          title: '11. Contact Us',
          content:
              'If you have any questions about this Privacy Policy, you may contact us at:\n\n'
              '📧 [camellauncher@gmail.com]',
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildSection({required String title, required String content}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          content,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
            height: 1.6,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}
