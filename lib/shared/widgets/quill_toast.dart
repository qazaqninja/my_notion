import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../theme/quill_tokens.dart';
import '../theme/tag_colors.dart';
import 'quill_icon.dart';

const Duration _kToastDuration = Duration(seconds: 4);

enum QuillToastKind { info, success, warn, error }

/// Visual card for a single toast. Ports `Toast` from `feedback.jsx:4-40`.
class QuillToastCard extends StatelessWidget {
  const QuillToastCard({
    super.key,
    required this.kind,
    required this.title,
    this.sub,
    this.subMono = false,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
  });

  final QuillToastKind kind;
  final String title;
  final String? sub;
  final bool subMono;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;

  Color _dot(QuillTokens tokens) {
    switch (kind) {
      case QuillToastKind.info:
        return tokens.accent;
      case QuillToastKind.success:
        return tokens.success;
      case QuillToastKind.warn:
        return kToastWarn;
      case QuillToastKind.error:
        return tokens.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final dark = tokens.isDark;
    final bg = dark
        ? const Color(0xFF1E1C18).withValues(alpha: 0.95)
        : const Color(0xFFFCFBF7).withValues(alpha: 0.96);
    final blurOk = _supportsBackdropBlur();
    final card = Container(
      width: 340,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
      decoration: BoxDecoration(
        color: blurOk ? bg : (dark ? const Color(0xFF1E1C18) : const Color(0xFFFCFBF7)),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        border: Border.all(color: tokens.divider2, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.55 : 0.10),
            offset: const Offset(0, 10),
            blurRadius: 30,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(
              color: _dot(tokens),
              borderRadius: const BorderRadius.all(Radius.circular(4)),
            ),
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
                    color: tokens.text,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (sub != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    sub!,
                    style: TextStyle(
                      fontFamily: subMono ? 'JetBrainsMono' : null,
                      fontSize: 11.5,
                      color: tokens.text3,
                      height: 1.45,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 10),
            _ToastAction(label: actionLabel!, onTap: onAction!),
          ],
          const SizedBox(width: 6),
          _ToastClose(onTap: onDismiss),
        ],
      ),
    );
    if (!blurOk) return card;
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(8)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: card,
      ),
    );
  }
}

bool _supportsBackdropBlur() {
  if (kIsWeb) return false;
  try {
    return Platform.isMacOS || Platform.isIOS || Platform.isWindows;
  } catch (_) {
    return false;
  }
}

class _ToastAction extends StatelessWidget {
  const _ToastAction({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(4)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          label,
          style: TextStyle(
            color: tokens.accent,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ToastClose extends StatelessWidget {
  const _ToastClose({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    // No Material Tooltip: QuillToastHost is inside MaterialApp.builder,
    // outside the router's Navigator/Overlay, so Tooltip can't mount here.
    return Semantics(
      label: 'Dismiss',
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(4)),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child:
              QuillIcon('x', size: 12, strokeWidth: 1.7, color: tokens.text3),
        ),
      ),
    );
  }
}

class _ToastEntry {
  _ToastEntry({
    required this.id,
    required this.kind,
    required this.title,
    this.sub,
    this.subMono = false,
    this.actionLabel,
    this.onAction,
  });
  final int id;
  final QuillToastKind kind;
  final String title;
  final String? sub;
  final bool subMono;
  final String? actionLabel;
  final VoidCallback? onAction;
  Timer? timer;
}

/// Owns the active toast stack. One instance per app, mounted by
/// [QuillToastHost]. Use the [BuildContext.quillToast] extension to address it.
class QuillToastController extends ChangeNotifier {
  final List<_ToastEntry> _entries = <_ToastEntry>[];
  int _seq = 0;
  bool _disposed = false;

  List<_ToastEntry> get _viewEntries => List.unmodifiable(_entries);

  void show({
    required QuillToastKind kind,
    required String title,
    String? sub,
    bool subMono = false,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = _kToastDuration,
  }) {
    if (_disposed) return;
    final entry = _ToastEntry(
      id: ++_seq,
      kind: kind,
      title: title,
      sub: sub,
      subMono: subMono,
      actionLabel: actionLabel,
      onAction: onAction,
    );
    entry.timer = Timer(duration, () => dismiss(entry.id));
    _entries.add(entry);
    notifyListeners();
  }

  void dismiss(int id) {
    if (_disposed) return;
    final i = _entries.indexWhere((e) => e.id == id);
    if (i < 0) return;
    _entries[i].timer?.cancel();
    _entries.removeAt(i);
    notifyListeners();
  }

  void dismissAll() {
    if (_disposed) return;
    for (final e in _entries) {
      e.timer?.cancel();
    }
    _entries.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final e in _entries) {
      e.timer?.cancel();
    }
    _entries.clear();
    super.dispose();
  }
}

/// Provides a [QuillToastController] to descendants via [InheritedWidget].
/// Mount under `MaterialApp.builder` so toasts persist across route changes.
class QuillToastHost extends StatefulWidget {
  const QuillToastHost({super.key, required this.child});
  final Widget child;

  @override
  State<QuillToastHost> createState() => _QuillToastHostState();
}

class _QuillToastHostState extends State<QuillToastHost> {
  final QuillToastController _controller = QuillToastController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _QuillToastScope(
      controller: _controller,
      child: Stack(
        children: [
          widget.child,
          Positioned(
            right: 24,
            bottom: 24,
            // Material ancestor for InkWells inside the toast card.
            // QuillToastHost sits in MaterialApp.builder, above the router's
            // Scaffold, so we provide one here. Transparent → no background.
            child: Material(
              type: MaterialType.transparency,
              child: _ToastStack(controller: _controller),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuillToastScope extends InheritedWidget {
  const _QuillToastScope({required this.controller, required super.child});
  final QuillToastController controller;

  @override
  bool updateShouldNotify(_QuillToastScope oldWidget) =>
      controller != oldWidget.controller;

  static QuillToastController? maybeOf(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_QuillToastScope>();
    return scope?.controller;
  }
}

class _ToastStack extends StatelessWidget {
  const _ToastStack({required this.controller});
  final QuillToastController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final entries = controller._viewEntries;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final e in entries)
              Padding(
                key: ValueKey(e.id),
                padding: const EdgeInsets.only(top: 8),
                child: _AnimatedToast(
                  entry: e,
                  onDismiss: () => controller.dismiss(e.id),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AnimatedToast extends StatefulWidget {
  const _AnimatedToast({required this.entry, required this.onDismiss});
  final _ToastEntry entry;
  final VoidCallback onDismiss;

  @override
  State<_AnimatedToast> createState() => _AnimatedToastState();
}

class _AnimatedToastState extends State<_AnimatedToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  )..forward();
  late final Animation<double> _opacity = CurvedAnimation(
    parent: _ac,
    curve: Curves.easeOut,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0.1, 0),
    end: Offset.zero,
  ).animate(_opacity);

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _opacity,
        child: QuillToastCard(
          kind: widget.entry.kind,
          title: widget.entry.title,
          sub: widget.entry.sub,
          subMono: widget.entry.subMono,
          actionLabel: widget.entry.actionLabel,
          onAction: widget.entry.onAction == null
              ? null
              : () {
                  widget.entry.onAction!.call();
                  widget.onDismiss();
                },
          onDismiss: widget.onDismiss,
        ),
      ),
    );
  }
}

extension QuillToastContext on BuildContext {
  /// Show a Quill-styled toast. Use the convenience helpers below where
  /// the kind is fixed.
  void quillToast(
    QuillToastKind kind,
    String title, {
    String? sub,
    bool subMono = false,
    String? action,
    VoidCallback? onAction,
    Duration duration = _kToastDuration,
  }) {
    final controller = _QuillToastScope.maybeOf(this);
    if (controller == null) {
      assert(false,
          'No QuillToastHost ancestor found. Wrap MaterialApp.builder with QuillToastHost.');
      return;
    }
    controller.show(
      kind: kind,
      title: title,
      sub: sub,
      subMono: subMono,
      actionLabel: action,
      onAction: onAction,
      duration: duration,
    );
  }

  void toastSuccess(String title, {String? sub, bool subMono = false}) =>
      quillToast(QuillToastKind.success, title, sub: sub, subMono: subMono);

  void toastError(String title, {String? sub, bool subMono = false}) =>
      quillToast(QuillToastKind.error, title, sub: sub, subMono: subMono);

  void toastInfo(String title, {String? sub, bool subMono = false}) =>
      quillToast(QuillToastKind.info, title, sub: sub, subMono: subMono);

  void toastWarn(String title, {String? sub, bool subMono = false}) =>
      quillToast(QuillToastKind.warn, title, sub: sub, subMono: subMono);
}
