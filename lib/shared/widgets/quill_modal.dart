import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/quill_tokens.dart';
import '../theme/tokens.dart';
import 'quill_icon.dart';
import 'quill_menu.dart';

const Color _kDangerColor = Color(0xFFA8584C);

/// Center-screen modal surface. Ports `ModalShell` from `modals.jsx:4-30`.
class QuillModal extends StatelessWidget {
  const QuillModal({
    super.key,
    this.header,
    required this.child,
    this.footer,
    this.width = 480,
  });

  final Widget? header;
  final Widget child;
  final Widget? footer;
  final double width;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final dark = tokens.isDark;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          border: Border.all(color: tokens.divider2, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.55 : 0.18),
              offset: const Offset(0, 32),
              blurRadius: 80,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (header != null) header!,
            Flexible(child: child),
            if (footer != null)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  color: dark
                      ? Colors.white.withValues(alpha: 0.015)
                      : Colors.black.withValues(alpha: 0.01),
                  border: Border(
                    top: BorderSide(color: tokens.divider, width: 0.5),
                  ),
                ),
                child: footer!,
              ),
          ],
        ),
      ),
    );
  }
}

/// Modal header — icon tile + title + sub + close. Ports `ModalHead`
/// from `modals.jsx:32-62`.
class QuillModalHeader extends StatelessWidget {
  const QuillModalHeader({
    super.key,
    required this.title,
    this.sub,
    this.icon,
    this.danger = false,
    this.onClose,
  });

  final String title;
  final String? sub;
  final String? icon;
  final bool danger;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: tokens.divider, width: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                color: danger
                    ? _kDangerColor.withValues(alpha: 0.12)
                    : tokens.accentTint,
                borderRadius: const BorderRadius.all(Radius.circular(6)),
              ),
              alignment: Alignment.center,
              child: QuillIcon(
                icon!,
                size: 16,
                strokeWidth: 1.7,
                color: danger ? _kDangerColor : tokens.accent,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: tokens.text,
                    letterSpacing: -0.1,
                    height: 1.2,
                  ),
                ),
                if (sub != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    sub!,
                    style: TextStyle(
                      fontSize: 13,
                      color: tokens.text3,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onClose != null) ...[
            const SizedBox(width: 8),
            _CloseButton(onTap: onClose!),
          ],
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(4)),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: QuillIcon('x', size: 14, strokeWidth: 1.7, color: tokens.text3),
      ),
    );
  }
}

/// Solid primary action button. Ports `PrimaryBtn` from `modals.jsx:64-80`.
class QuillPrimaryButton extends StatelessWidget {
  const QuillPrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.danger = false,
    this.onPressed,
  });

  final String label;
  final String? icon;
  final bool danger;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final bg = danger ? _kDangerColor : tokens.text;
    final fg = danger ? Colors.white : tokens.bg;
    return InkWell(
      onTap: onPressed,
      borderRadius: const BorderRadius.all(Radius.circular(6)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.all(Radius.circular(6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              QuillIcon(icon!, size: 12, strokeWidth: 1.8, color: fg),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Outline secondary action button. Ports `SecondaryBtn` from `modals.jsx:82-94`.
class QuillSecondaryButton extends StatelessWidget {
  const QuillSecondaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
  });

  final String label;
  final String? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return InkWell(
      onTap: onPressed,
      borderRadius: const BorderRadius.all(Radius.circular(6)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: const BorderRadius.all(Radius.circular(6)),
          border: Border.all(color: tokens.divider2, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              QuillIcon(icon!, size: 12, strokeWidth: 1.8, color: tokens.text),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: tokens.text,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Two-line label + hint for form rows. Ports `FormLabel` from `modals.jsx:96-103`.
class QuillFormLabel extends StatelessWidget {
  const QuillFormLabel({super.key, required this.label, this.hint});

  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              color: tokens.text,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                hint!,
                style: TextStyle(fontSize: 11.5, color: tokens.text3),
              ),
            ),
        ],
      ),
    );
  }
}

/// Single-line text input styled per `Input` from `modals.jsx:105-122`.
class QuillInputField extends StatelessWidget {
  const QuillInputField({
    super.key,
    required this.controller,
    this.placeholder,
    this.mono = false,
    this.prefix,
    this.suffix,
    this.autofocus = false,
    this.onSubmitted,
    this.obscure = false,
  });

  final TextEditingController controller;
  final String? placeholder;
  final bool mono;
  final String? prefix;
  final Widget? suffix;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final style = TextStyle(
      fontFamily: mono ? 'JetBrainsMono' : null,
      fontSize: 13.5,
      color: tokens.text,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: tokens.inputBg,
        border: Border.all(color: tokens.divider2, width: 0.5),
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      child: Row(
        children: [
          if (prefix != null) ...[
            Text(
              prefix!,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12.5,
                color: tokens.text3,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              obscureText: obscure,
              cursorColor: tokens.text,
              cursorWidth: 1.5,
              style: style.copyWith(color: tokens.text),
              decoration: InputDecoration.collapsed(
                hintText: placeholder,
                hintStyle: style.copyWith(color: tokens.text3),
              ),
              onSubmitted: onSubmitted,
            ),
          ),
          if (suffix != null) ...[
            const SizedBox(width: 6),
            suffix!,
          ],
        ],
      ),
    );
  }
}

// ── helpers ────────────────────────────────────────────────────────────────

/// Show a [QuillModal]-styled dialog. Wraps `showDialog` with the right
/// barrier colour for our design and an Esc-to-pop binding.
Future<T?> showQuillModal<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  final tokens = QuillTokens.of(context);
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: Colors.black.withValues(alpha: tokens.isDark ? 0.55 : 0.32),
    builder: (ctx) {
      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              Navigator.of(ctx).pop(null),
        },
        child: Focus(
          autofocus: true,
          child: Center(child: builder(ctx)),
        ),
      );
    },
  );
}

/// Yes/no confirm dialog. Returns true on confirm, false otherwise.
Future<bool> showQuillConfirm(
  BuildContext context, {
  required String title,
  String? sub,
  String? icon,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool danger = false,
  double width = 460,
}) async {
  final result = await showQuillModal<bool>(
    context,
    builder: (ctx) {
      return QuillModal(
        width: width,
        header: QuillModalHeader(
          title: title,
          sub: sub,
          icon: icon,
          danger: danger,
          onClose: () => Navigator.of(ctx).pop(false),
        ),
        footer: Row(
          children: [
            const Spacer(),
            QuillSecondaryButton(
              label: cancelLabel,
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
            const SizedBox(width: 8),
            QuillPrimaryButton(
              label: confirmLabel,
              icon: danger ? 'trash' : null,
              danger: danger,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        ),
        child: const SizedBox(height: 4),
      );
    },
  );
  return result ?? false;
}

/// Single-input prompt dialog. Returns the trimmed string or null on cancel.
Future<String?> showQuillPrompt(
  BuildContext context, {
  required String title,
  String? sub,
  String? icon,
  String? label,
  String? hint,
  String placeholder = '',
  String initial = '',
  String confirmLabel = 'Save',
  bool mono = false,
  String? prefix,
  double width = 460,
}) async {
  final controller = TextEditingController(text: initial);
  controller.selection = TextSelection(
    baseOffset: 0,
    extentOffset: initial.length,
  );
  final result = await showQuillModal<String>(
    context,
    builder: (ctx) {
      void submit() {
        final v = controller.text.trim();
        Navigator.of(ctx).pop(v.isEmpty ? null : v);
      }

      return QuillModal(
        width: width,
        header: QuillModalHeader(
          title: title,
          sub: sub,
          icon: icon,
          onClose: () => Navigator.of(ctx).pop(),
        ),
        footer: Row(
          children: [
            const Spacer(),
            QuillSecondaryButton(
              label: 'Cancel',
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            const SizedBox(width: 8),
            QuillPrimaryButton(
              label: confirmLabel,
              icon: 'check',
              onPressed: submit,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (label != null) QuillFormLabel(label: label, hint: hint),
              QuillInputField(
                controller: controller,
                placeholder: placeholder,
                mono: mono,
                prefix: prefix,
                autofocus: true,
                onSubmitted: (_) => submit(),
              ),
            ],
          ),
        ),
      );
    },
  );
  controller.dispose();
  return result;
}

/// Vertical list of choices in a modal. Returns the picked value or null on cancel.
Future<T?> showQuillChoice<T>(
  BuildContext context, {
  required String title,
  String? sub,
  String? icon,
  required List<QuillChoiceOption<T>> options,
  double width = 420,
}) {
  return showQuillModal<T>(
    context,
    builder: (ctx) {
      return QuillModal(
        width: width,
        header: QuillModalHeader(
          title: title,
          sub: sub,
          icon: icon,
          onClose: () => Navigator.of(ctx).pop(),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final o in options)
                QuillMenuRow(
                  icon: o.icon,
                  label: o.label,
                  hint: o.hint,
                  danger: o.danger,
                  onTap: () => Navigator.of(ctx).pop(o.value),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class QuillChoiceOption<T> {
  const QuillChoiceOption({
    required this.value,
    required this.label,
    this.icon,
    this.hint,
    this.danger = false,
  });

  final T value;
  final String label;
  final String? icon;
  final String? hint;
  final bool danger;
}

/// Shared mono helper re-export so call sites need only one import.
TextStyle quillMono({double? fontSize, FontWeight? fontWeight, Color? color}) =>
    mono(fontSize: fontSize, fontWeight: fontWeight, color: color);
