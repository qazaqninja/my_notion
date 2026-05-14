import 'package:flutter/material.dart';

enum AccentKey {
  sage(Color(0xFF6B8E7F), 'Sage'),
  terracotta(Color(0xFFC97B5C), 'Terracotta');

  const AccentKey(this.color, this.label);

  final Color color;
  final String label;

  Color get tint => color.withValues(alpha: 0.10);
}
