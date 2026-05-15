import 'package:flutter/material.dart';

/// Small coloured dot for health / sync status. Matches `StatusDot` from
/// `primitives.jsx:45-51`.
class StatusDot extends StatelessWidget {
  const StatusDot({
    super.key,
    this.color = StatusDotColor.green,
    this.size = 7,
    this.tooltip,
  });

  final StatusDotColor color;
  final double size;

  /// Optional hover hint. Without it the dot is ambiguous — pass the
  /// underlying label ("on-track", "blocked", "green") so the user can
  /// read the meaning rather than guessing from the colour.
  final String? tooltip;

  static const _map = <StatusDotColor, Color>{
    StatusDotColor.green: Color(0xFF5A8F6E),
    StatusDotColor.yellow: Color(0xFFC4A548),
    StatusDotColor.red: Color(0xFFB66954),
    StatusDotColor.gray: Color(0xFF9E9C97),
    StatusDotColor.blue: Color(0xFF5A82B4),
    StatusDotColor.purple: Color(0xFF8278B5),
  };

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _map[color] ?? _map[StatusDotColor.gray]!,
        shape: BoxShape.circle,
      ),
    );
    if (tooltip == null) return dot;
    return Tooltip(
      message: tooltip!,
      waitDuration: const Duration(milliseconds: 400),
      child: dot,
    );
  }
}

enum StatusDotColor { green, yellow, red, gray, blue, purple }
