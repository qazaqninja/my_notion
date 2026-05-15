import 'package:flutter/material.dart';

import '../theme/quill_tokens.dart';
import 'quill_icon.dart';

/// Floating popover surface — 8px radius, 0.5px border, soft drop shadow.
/// Ports `Surface` from `menus.jsx:8-23`.
class QuillSurface extends StatelessWidget {
  const QuillSurface({
    super.key,
    this.width,
    this.padding = const EdgeInsets.all(4),
    required this.child,
  });

  final double? width;
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final dark = tokens.isDark;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        padding: padding,
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          border: Border.all(color: tokens.divider2, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context)
                  .colorScheme
                  .shadow
                  .withValues(alpha: dark ? 0.55 : 0.12),
              offset: const Offset(0, 16),
              blurRadius: 48,
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

/// Tap-able menu row with icon/label/hint/active/danger states. Ports
/// `MenuRow` from `menus.jsx:25-42`.
class QuillMenuRow extends StatefulWidget {
  const QuillMenuRow({
    super.key,
    this.icon,
    required this.label,
    this.hint,
    this.active = false,
    this.danger = false,
    this.hasSubmenu = false,
    this.disabled = false,
    this.indent = false,
    this.onTap,
  });

  final String? icon;
  final String label;
  final String? hint;
  final bool active;
  final bool danger;
  final bool hasSubmenu;
  final bool disabled;
  final bool indent;
  final VoidCallback? onTap;

  @override
  State<QuillMenuRow> createState() => _QuillMenuRowState();
}

class _QuillMenuRowState extends State<QuillMenuRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final highlight = widget.active || (_hover && !widget.disabled);
    final fg = widget.disabled
        ? tokens.text3
        : (widget.danger ? tokens.danger : tokens.text);
    final iconColor = widget.disabled
        ? tokens.text3
        : (widget.danger ? tokens.danger : tokens.text2);
    final body = Container(
      padding: EdgeInsets.fromLTRB(
        widget.indent ? 28 : 10,
        7,
        widget.indent ? 22 : 10,
        7,
      ),
      decoration: BoxDecoration(
        color: highlight ? tokens.hover : Colors.transparent,
        borderRadius: const BorderRadius.all(Radius.circular(5)),
      ),
      child: Row(
        children: [
          if (widget.icon != null) ...[
            QuillIcon(widget.icon!, size: 13, strokeWidth: 1.7, color: iconColor),
            const SizedBox(width: 9),
          ],
          Expanded(
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 13,
                color: fg,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (widget.hasSubmenu) ...[
            const SizedBox(width: 6),
            QuillIcon('caret', size: 11, strokeWidth: 1.8, color: tokens.text3),
          ],
          if (widget.hint != null) ...[
            const SizedBox(width: 8),
            Text(
              widget.hint!,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 11,
                color: tokens.text3,
              ),
            ),
          ],
        ],
      ),
    );
    if (widget.disabled || widget.onTap == null) {
      return Opacity(opacity: widget.disabled ? 0.5 : 1, child: body);
    }
    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: body,
      ),
    );
  }
}

/// Uppercase section header above a group of rows. Ports `MenuHead`.
class QuillMenuHeader extends StatelessWidget {
  const QuillMenuHeader({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.84, // 0.08em on 10.5
          color: tokens.text3,
        ),
      ),
    );
  }
}

/// Hairline separator inside a menu. Ports `MenuSep`.
class QuillMenuSeparator extends StatelessWidget {
  const QuillMenuSeparator({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: tokens.divider,
    );
  }
}

/// One entry in a [showQuillMenu] call. Leaf rows have a [value] that the
/// menu pops with on tap; separators and headers use named constructors.
class QuillMenuItem<T> {
  const QuillMenuItem({
    this.icon,
    required this.label,
    this.hint,
    this.danger = false,
    this.disabled = false,
    this.value,
    this.onTap,
  })  : isSeparator = false,
        headerLabel = null;

  const QuillMenuItem._separator()
      : icon = null,
        label = '',
        hint = null,
        danger = false,
        disabled = false,
        value = null,
        onTap = null,
        isSeparator = true,
        headerLabel = null;

  const QuillMenuItem._header(String label)
      : icon = null,
        label = '',
        hint = null,
        danger = false,
        disabled = false,
        value = null,
        onTap = null,
        isSeparator = false,
        headerLabel = label;

  static QuillMenuItem<T> separator<T>() => const QuillMenuItem._separator();

  static QuillMenuItem<T> header<T>(String label) =>
      QuillMenuItem._header(label);

  final String? icon;
  final String label;
  final String? hint;
  final bool danger;
  final bool disabled;
  final T? value;
  final VoidCallback? onTap;
  final bool isSeparator;
  final String? headerLabel;
}

/// Show a popover menu anchored at [position] (top-left of menu, in overlay
/// coordinates). Drop-in for `showMenu` with our `QuillSurface` chrome.
Future<T?> showQuillMenu<T>({
  required BuildContext context,
  required RelativeRect position,
  required List<QuillMenuItem<T>> items,
  double width = 240,
  String? sectionHeader,
}) {
  return Navigator.of(context).push<T>(
    _QuillMenuRoute<T>(
      position: position,
      items: items,
      width: width,
      sectionHeader: sectionHeader,
      barrierLabel:
          MaterialLocalizations.of(context).modalBarrierDismissLabel,
      themeContext: context,
    ),
  );
}

class _QuillMenuRoute<T> extends PopupRoute<T> {
  _QuillMenuRoute({
    required this.position,
    required this.items,
    required this.width,
    required this.sectionHeader,
    required this.barrierLabel,
    required this.themeContext,
  });

  final RelativeRect position;
  final List<QuillMenuItem<T>> items;
  final double width;
  final String? sectionHeader;
  final BuildContext themeContext;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 80);

  @override
  bool get barrierDismissible => true;

  @override
  Color? get barrierColor => null;

  @override
  final String barrierLabel;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    final mq = MediaQuery.of(context);
    return CustomSingleChildLayout(
      delegate: _QuillMenuLayoutDelegate(
        position: position,
        textDirection: Directionality.of(context),
        safe: mq.padding,
      ),
      child: FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: _MenuContent<T>(
          items: items,
          width: width,
          sectionHeader: sectionHeader,
          themeContext: themeContext,
        ),
      ),
    );
  }
}

class _MenuContent<T> extends StatelessWidget {
  const _MenuContent({
    required this.items,
    required this.width,
    required this.sectionHeader,
    required this.themeContext,
  });

  final List<QuillMenuItem<T>> items;
  final double width;
  final String? sectionHeader;
  final BuildContext themeContext;

  @override
  Widget build(BuildContext context) {
    // Inherit the theme from the originating context so the popup picks up
    // our QuillTokens even when pushed onto the root navigator.
    final inheritedTheme = InheritedTheme.capture(
      from: themeContext,
      to: Navigator.maybeOf(themeContext)?.context,
    );
    return inheritedTheme.wrap(
      ConstrainedBox(
        constraints: BoxConstraints(maxHeight: 480, maxWidth: width),
        child: QuillSurface(
          width: width,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (sectionHeader != null)
                  QuillMenuHeader(label: sectionHeader!),
                for (final item in items)
                  if (item.isSeparator)
                    const QuillMenuSeparator()
                  else if (item.headerLabel != null)
                    QuillMenuHeader(label: item.headerLabel!)
                  else
                    QuillMenuRow(
                      icon: item.icon,
                      label: item.label,
                      hint: item.hint,
                      danger: item.danger,
                      disabled: item.disabled,
                      onTap: () {
                        Navigator.of(context).pop<T>(item.value);
                        item.onTap?.call();
                      },
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuillMenuLayoutDelegate extends SingleChildLayoutDelegate {
  _QuillMenuLayoutDelegate({
    required this.position,
    required this.textDirection,
    required this.safe,
  });

  final RelativeRect position;
  final TextDirection textDirection;
  final EdgeInsets safe;

  static const double _kMargin = 8;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints.loose(constraints.biggest).deflate(
      EdgeInsets.only(
        left: _kMargin + safe.left,
        right: _kMargin + safe.right,
        top: _kMargin + safe.top,
        bottom: _kMargin + safe.bottom,
      ),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    double x = position.left;
    double y = position.top;
    if (textDirection == TextDirection.rtl) {
      x = size.width - position.right - childSize.width;
    }
    final maxX = size.width - childSize.width - _kMargin - safe.right;
    final maxY = size.height - childSize.height - _kMargin - safe.bottom;
    if (x > maxX) x = maxX;
    if (x < _kMargin + safe.left) x = _kMargin + safe.left;
    if (y > maxY) y = maxY;
    if (y < _kMargin + safe.top) y = _kMargin + safe.top;
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_QuillMenuLayoutDelegate oldDelegate) =>
      position != oldDelegate.position ||
      textDirection != oldDelegate.textDirection ||
      safe != oldDelegate.safe;
}

/// Compute a [RelativeRect] for showing a menu just below an anchor [context]
/// (typically a button or icon's BuildContext).
RelativeRect quillMenuAnchor(BuildContext context, {Offset offset = const Offset(0, 4)}) {
  final box = context.findRenderObject()! as RenderBox;
  final overlay =
      Overlay.of(context).context.findRenderObject()! as RenderBox;
  final topLeft = box.localToGlobal(
    Offset(0, box.size.height) + offset,
    ancestor: overlay,
  );
  final bottomRight = box.localToGlobal(
    box.size.bottomRight(Offset.zero) + offset,
    ancestor: overlay,
  );
  return RelativeRect.fromRect(
    Rect.fromPoints(topLeft, bottomRight),
    Offset.zero & overlay.size,
  );
}

/// Compute a [RelativeRect] for a popup anchored at a global [position] —
/// typical caller is `onSecondaryTapDown: (d) => showQuillMenu(..., position: quillMenuPosition(context, d.globalPosition))`.
RelativeRect quillMenuPosition(BuildContext context, Offset globalPosition) {
  final overlay =
      Overlay.of(context).context.findRenderObject()! as RenderBox;
  return RelativeRect.fromRect(
    Rect.fromPoints(globalPosition, globalPosition),
    Offset.zero & overlay.size,
  );
}
