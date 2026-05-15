import 'package:flutter/material.dart';

import '../theme/quill_tokens.dart';
import '../theme/tag_colors.dart';
import 'quill_icon.dart';
import 'quill_toast.dart' show QuillToastKind;

class _BannerColors {
  const _BannerColors({required this.fg, required this.bg, required this.border});
  final Color fg;
  final Color bg;
  final Color border;
}

_BannerColors _colorsFor(QuillToastKind kind, QuillTokens tokens) {
  // Background tints are the base hue at low alpha; explicit alpha
  // bytes (0x29 / 0x24 / 0x1A) keep the values pure-token and avoid
  // creating a runtime-only Color via withOpacity.
  if (tokens.isDark) {
    switch (kind) {
      case QuillToastKind.info:
        return _BannerColors(
          fg: tokens.accent,
          bg: tokens.accentTint,
          border: tokens.accent,
        );
      case QuillToastKind.success:
        return const _BannerColors(
          fg: kBannerSuccessFgDark,
          bg: Color(0x295A8F6E), // kStatusDotGreen @ 16%
          border: kStatusDotGreen,
        );
      case QuillToastKind.warn:
        return const _BannerColors(
          fg: kBannerWarnFgDark,
          bg: Color(0x29C4A548), // kStatusDotYellow @ 16%
          border: kStatusDotYellow,
        );
      case QuillToastKind.error:
        return const _BannerColors(
          fg: kBannerErrorFgDark,
          bg: Color(0x29A8584C), // kBannerErrorBase @ 16%
          border: kBannerErrorBase,
        );
    }
  }
  switch (kind) {
    case QuillToastKind.info:
      return _BannerColors(
        fg: tokens.accent,
        bg: tokens.accentTint,
        border: tokens.accent,
      );
    case QuillToastKind.success:
      return const _BannerColors(
        fg: kBannerSuccessFgLight,
        bg: Color(0x1A5A8F6E), // kStatusDotGreen @ 10%
        border: kStatusDotGreen,
      );
    case QuillToastKind.warn:
      return const _BannerColors(
        fg: kBannerWarnFgLight,
        bg: Color(0x24C4A548), // kStatusDotYellow @ 14%
        border: kStatusDotYellow,
      );
    case QuillToastKind.error:
      return const _BannerColors(
        fg: kBannerErrorFgLight,
        bg: Color(0x1AA8584C), // kBannerErrorBase @ 10%
        border: kBannerErrorBase,
      );
  }
}

/// In-page status banner (top of editor / database). Ports `Banner` from
/// `feedback.jsx:60-96`. For transient floating notifications, use
/// `context.quillToast(...)` instead.
class QuillBanner extends StatelessWidget {
  const QuillBanner({
    super.key,
    this.kind = QuillToastKind.info,
    required this.icon,
    required this.title,
    this.sub,
    this.actionLabel,
    this.onAction,
  });

  final QuillToastKind kind;
  final String icon;
  final String title;
  final String? sub;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final c = _colorsFor(kind, tokens);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(
          left: BorderSide(color: c.border, width: 2),
          top: BorderSide(color: tokens.divider, width: 0.5),
          bottom: BorderSide(color: tokens.divider, width: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: QuillIcon(icon, size: 14, strokeWidth: 1.7, color: c.fg),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: c.fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (sub != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    sub!,
                    style: TextStyle(
                      fontSize: 12,
                      color: tokens.text2,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 10),
            InkWell(
              onTap: onAction,
              borderRadius: const BorderRadius.all(Radius.circular(5)),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: c.border, width: 0.5),
                  borderRadius: const BorderRadius.all(Radius.circular(5)),
                ),
                child: Text(
                  actionLabel!,
                  style: TextStyle(
                    color: c.fg,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
