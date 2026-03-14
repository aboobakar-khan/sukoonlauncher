import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Apple-style page route with smooth iOS slide transitions.
///
/// Forward: new page slides in from the right while the old page slides left.
/// Back:    reversed slide — feels identical to iOS native swipe-back.
///
/// Uses [CupertinoPageRoute] under the hood so the interactive
/// edge-swipe-back gesture works automatically on both iOS and Android.
///
/// All navigation in the app should use this instead of [MaterialPageRoute]
/// or raw [PageRouteBuilder] so every transition is consistent and smooth.
class SmoothForwardRoute<T> extends CupertinoPageRoute<T> {
  SmoothForwardRoute({required Widget child, super.settings})
      : super(builder: (_) => child);

  // Slightly faster than default Cupertino (400ms) for a snappier feel
  @override
  Duration get transitionDuration => const Duration(milliseconds: 350);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 300);
}
