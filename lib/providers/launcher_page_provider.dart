import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared PageController provider so any screen can navigate
/// to a specific page in the launcher's PageView.
final launcherPageControllerProvider = StateProvider<PageController?>((ref) => null);
