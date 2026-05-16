import 'package:flutter/material.dart';
import 'package:my_notion/shared/theme/accent.dart';
import 'package:my_notion/shared/theme/tokens.dart';

/// Wraps [child] in a MaterialApp themed with Quill's light theme so
/// widget tests can resolve `Theme.of(context).extension<QuillTokens>()`.
Widget testApp(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: makeTheme(brightness, AccentKey.sage),
    home: Scaffold(body: Center(child: child)),
  );
}
