import 'package:flutter/material.dart';
import 'package:samapoche/theme.dart';

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final bool outline;
  final bool ghost;
  final bool block;
  final bool large;
  final bool small;
  final Widget? icon;
  final bool loading;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.primary = false,
    this.outline = false,
    this.ghost = false,
    this.block = true,
    this.large = false,
    this.small = false,
    this.icon,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final accent = isDark ? AppDark.accent : AppColors.accent;
    final muted = isDark ? AppDark.muted : AppColors.muted;
    final surface = isDark ? AppDark.surface : AppColors.surface;
    final fg2 = isDark ? AppDark.fg2 : AppColors.fg2;
    final borderSoft = isDark ? AppDark.borderSoft : AppColors.borderSoft;

    Color bgColor = Colors.transparent;
    Color fgColor = fg2;
    BorderSide side = BorderSide.none;
    if (primary) {
      bgColor = accent;
      fgColor = Colors.white;
    } else if (outline) {
      bgColor = Colors.transparent;
      fgColor = accent;
      side = BorderSide(color: accent, width: 1.5);
    } else if (ghost) {
      bgColor = Colors.transparent;
      fgColor = muted;
    } else {
      bgColor = surface;
      fgColor = fg2;
      side = BorderSide(color: borderSoft);
    }

    final pad = large
        ? const EdgeInsets.symmetric(horizontal: 28, vertical: 16)
        : small
            ? const EdgeInsets.symmetric(horizontal: 18, vertical: 10)
            : const EdgeInsets.symmetric(horizontal: 24, vertical: 14);

    final size = large ? 17.0 : small ? 14.0 : 16.0;

    return GestureDetector(
      onTap: onPressed == null ? null : () => onPressed!(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        width: block ? double.infinity : null,
        padding: pad,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: side.width > 0
              ? Border.all(color: side.color, width: side.width)
              : Border.all(color: Colors.transparent, width: 0),
        ),
        child: loading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: primary ? Colors.white : accent,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    icon!,
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: size,
                      fontWeight: FontWeight.w600,
                      color: fgColor,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? color;
  final VoidCallback? onTap;
  final double radius;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin = EdgeInsets.zero,
    this.color,
    this.onTap,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final borderSoft = isDark ? AppDark.borderSoft : AppColors.borderSoft;
    final bg = isDark ? AppDark.bg : AppColors.bg;
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? bg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderSoft),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class AppChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const AppChip({super.key, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final accent = isDark ? AppDark.accent : AppColors.accent;
    final surface = isDark ? AppDark.surface : AppColors.surface;
    final borderSoft = isDark ? AppDark.borderSoft : AppColors.borderSoft;
    final fg2 = isDark ? AppDark.fg2 : AppColors.fg2;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? accent : surface,
          borderRadius: BorderRadius.circular(999),
          border: active ? null : Border.all(color: borderSoft),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: active ? Colors.white : fg2,
          ),
        ),
      ),
    );
  }
}

class FieldLabel extends StatelessWidget {
  final String text;
  const FieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final fg2 = isDark ? AppDark.fg2 : AppColors.fg2;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: fg2)),
    );
  }
}

class UppercaseLabel extends StatelessWidget {
  final String text;
  const UppercaseLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final muted = isDark ? AppDark.muted : AppColors.muted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: muted,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class ToastType {
  static const success = 'success';
  static const error = 'error';
  static const warning = 'warning';
  static const info = 'info';
}

void showToast(BuildContext context, String message, [String type = ToastType.info]) {
  final isDark = context.isDark;
  Color bg;
  Color fg;
  IconData icon;
  switch (type) {
    case ToastType.success:
      bg = isDark ? AppDark.toastSuccessBg : AppColors.toastSuccessBg;
      fg = isDark ? AppDark.toastSuccessFg : AppColors.toastSuccessFg;
      icon = Icons.check_circle;
      break;
    case ToastType.error:
      bg = isDark ? AppDark.toastErrorBg : AppColors.toastErrorBg;
      fg = isDark ? AppDark.toastErrorFg : AppColors.toastErrorFg;
      icon = Icons.cancel;
      break;
    case ToastType.warning:
      bg = isDark ? AppDark.toastWarnBg : AppColors.toastWarnBg;
      fg = isDark ? AppDark.toastWarnFg : AppColors.toastWarnFg;
      icon = Icons.warning_amber_rounded;
      break;
    default:
      bg = isDark ? AppDark.toastInfoBg : AppColors.toastInfoBg;
      fg = isDark ? AppDark.toastInfoFg : AppColors.toastInfoFg;
      icon = Icons.info;
  }

  final overlay = Overlay.of(context);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => Positioned(
      top: 60,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: -1, end: 0),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          builder: (_, v, child) => Transform.translate(offset: Offset(0, 20 * v), child: child),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border(left: BorderSide(color: fg == AppColors.toastSuccessFg || fg == AppDark.toastSuccessFg ? AppColors.accent : fg == AppColors.toastErrorFg || fg == AppDark.toastErrorFg ? AppColors.danger : fg == AppColors.toastWarnFg || fg == AppDark.toastWarnFg ? AppColors.warn : AppColors.info, width: 4)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 20)],
            ),
            child: Row(
              children: [
                Icon(icon, color: fg, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(color: fg, fontSize: 14, fontWeight: FontWeight.w500, height: 1.4),
                  ),
                ),
                GestureDetector(
                  onTap: () => entry.remove(),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.close, color: fg.withValues(alpha: 0.7), size: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Future.delayed(const Duration(seconds: 4), () {
    if (entry.mounted) entry.remove();
  });
}

void showModal(BuildContext context, Widget body, {String? title}) {
  showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: 340,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 32, offset: const Offset(0, 8))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.close, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), child: body),
          ],
        ),
      ),
    ),
  );
}

class ModalFooter extends StatelessWidget {
  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final bool confirmPrimary;

  const ModalFooter({
    super.key,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
    this.confirmPrimary = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: AppButton(label: cancelLabel, onPressed: onCancel, ghost: true, small: true),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: AppButton(label: confirmLabel, onPressed: onConfirm, primary: confirmPrimary, small: true),
        ),
      ],
    );
  }
}

class AppTabBar extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;

  const AppTabBar({super.key, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final borderSoft = isDark ? AppDark.borderSoft : AppColors.borderSoft;
    final meta = isDark ? AppDark.meta : AppColors.meta;
    final accent = isDark ? AppDark.accent : AppColors.accent;
    final bg = Theme.of(context).scaffoldBackgroundColor;

    final tabs = [
      (Icons.home_rounded, 'Accueil'),
      (Icons.currency_exchange_rounded, 'Transactions'),
      (Icons.smart_toy_rounded, 'Assistant'),
      (Icons.person_rounded, 'Profil'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.92),
        border: Border(top: BorderSide(color: borderSoft)),
      ),
      padding: EdgeInsets.only(top: 4, bottom: MediaQuery.of(context).padding.bottom + 4),
      child: Row(
        children: [
          for (int i = 0; i < tabs.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(tabs[i].$1,
                        size: 24, color: current == i ? accent : meta),
                    const SizedBox(height: 2),
                    Text(tabs[i].$2,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: current == i ? accent : meta,
                        )),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      width: current == i ? 20 : 0,
                      height: 3,
                      decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final String? link;
  final VoidCallback? onLink;
  const SectionTitle(this.text, {super.key, this.link, this.onLink});

  @override
  Widget build(BuildContext context) {
    final accent = context.isDark ? AppDark.accent : AppColors.accent;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
        if (link != null)
          GestureDetector(
            onTap: onLink,
            child: Text(link!, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: accent)),
          ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  const EmptyState({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final border = context.isDark ? AppDark.border : AppColors.border;
    final fg = context.isDark ? AppDark.fg : AppColors.fg;
    final muted = context.isDark ? AppDark.muted : AppColors.muted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      child: Column(
        children: [
          Icon(Icons.receipt_long, size: 48, color: border),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: fg)),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class ProfileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool divider;

  const ProfileRow({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.onTap,
    this.trailing,
    this.divider = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final fg2 = isDark ? AppDark.fg2 : AppColors.fg2;
    final muted = isDark ? AppDark.muted : AppColors.muted;
    final border = isDark ? AppDark.border : AppColors.border;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: -16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, size: 22, color: fg2),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: fg2)),
                ),
                if (value != null) Text(value!, style: TextStyle(fontSize: 14, color: muted)),
                if (value != null) const SizedBox(width: 8),
                trailing ?? Icon(Icons.chevron_right, size: 18, color: border),
              ],
            ),
            if (divider) const Divider(height: 20),
          ],
        ),
      ),
    );
  }
}

class FormError extends StatelessWidget {
  final String? message;
  const FormError(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(message!, style: const TextStyle(fontSize: 12, color: AppColors.danger, height: 1.3)),
    );
  }
}

class SectionGroupLabel extends StatelessWidget {
  final String text;
  const SectionGroupLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final muted = context.isDark ? AppDark.muted : AppColors.muted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: muted, letterSpacing: 0.5),
      ),
    );
  }
}
