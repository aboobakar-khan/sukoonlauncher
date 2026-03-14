import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dua_category_screen.dart';

/// Main entry point for Dua & Adhkar section
/// Redirects to the new category-based navigation
class MinimalistDuaScreen extends ConsumerWidget {
  const MinimalistDuaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const DuaCategoryScreen();
  }
}
