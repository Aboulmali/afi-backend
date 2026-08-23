import 'package:flutter/material.dart';
import 'package:samapoche/models/models.dart';
import 'package:samapoche/screens/root_shell.dart';
import 'package:samapoche/state/app_state.dart';
import 'package:samapoche/theme.dart';
import 'package:samapoche/widgets/widgets.dart';

class NotificationsScreen extends StatefulWidget {
  final void Function(RouteName) go;
  const NotificationsScreen({super.key, required this.go});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _filter = 'Toutes';

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final muted = isDark ? AppDark.muted : AppColors.muted;
    final accent = isDark ? AppDark.accent : AppColors.accent;

    return SafeArea(
      child: ListenableBuilder(
        listenable: AppState.I,
        builder: (context, _) {
          final notifs = AppState.I.notifications;
          final filtered = _filter == 'Toutes'
              ? notifs
              : _filter == 'Non lues'
                  ? notifs.where((n) => !n.read).toList()
                  : notifs.where((n) => n.read).toList();

          final groups = <String, List<AppNotification>>{};
          for (final n in filtered) {
            groups.putIfAbsent(n.group, () => []).add(n);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => widget.go(RouteName.home),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isDark ? AppDark.surface : AppColors.surface,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Notifications',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, fontFamily: 'Inter'),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            AppState.I.markAllRead();
                            showToast(context, 'Toutes les notifications sont marquées comme lues', ToastType.success);
                          },
                          child: Text(
                            'Tout marquer comme lu',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: accent),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        for (final f in ['Toutes', 'Non lues', 'Lues'])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: AppChip(label: f, active: _filter == f, onTap: () => setState(() => _filter = f)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  children: [
                    for (final entry in groups.entries) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          entry.key.toUpperCase(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: muted,
                          ),
                        ),
                      ),
                      for (final n in entry.value)
                        _NotifItem(notification: n),
                    ],
                    if (groups.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: EmptyState(
                          title: 'Aucune notification',
                          subtitle: 'Vous êtes à jour !',
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NotifItem extends StatelessWidget {
  final AppNotification notification;
  const _NotifItem({required this.notification});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final muted = isDark ? AppDark.muted : AppColors.muted;
    final meta = isDark ? AppDark.meta : AppColors.meta;
    final borderSoft = isDark ? AppDark.borderSoft : AppColors.borderSoft;
    final fg = isDark ? AppDark.fg : AppColors.fg;
    final accent = isDark ? AppDark.accent : AppColors.accent;

    return InkWell(
      onTap: () {
        AppState.I.markRead(notification);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: borderSoft, width: 0.5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: notification.bg, borderRadius: BorderRadius.circular(12)),
              child: Icon(notification.icon, size: 18, color: notification.fg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: fg),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.desc,
                    style: TextStyle(fontSize: 14, color: muted, height: 1.4),
                  ),
                  const SizedBox(height: 4),
                  Text(notification.time, style: TextStyle(fontSize: 11, color: meta)),
                ],
              ),
            ),
            if (!notification.read)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 8),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
