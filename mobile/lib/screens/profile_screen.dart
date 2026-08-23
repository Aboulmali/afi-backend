import 'package:flutter/material.dart';
import 'package:samapoche/models/models.dart';
import 'package:samapoche/screens/root_shell.dart';
import 'package:samapoche/state/app_state.dart';
import 'package:samapoche/theme.dart';
import 'package:samapoche/utils/format.dart';
import 'package:samapoche/widgets/widgets.dart';

class ProfileScreen extends StatefulWidget {
  final void Function(RouteName) go;
  const ProfileScreen({super.key, required this.go});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  void _toastInfo(String msg) => showToast(context, msg, ToastType.info);

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final user = s.user!;
    final isDark = context.isDark;
    final muted = isDark ? AppDark.muted : AppColors.muted;
    final borderSoft = isDark ? AppDark.borderSoft : AppColors.borderSoft;
    final fg = isDark ? AppDark.fg : AppColors.fg;
    final accent = isDark ? AppDark.accent : AppColors.accent;
    final danger = AppColors.danger;

    return SafeArea(
      child: ListenableBuilder(
        listenable: AppState.I,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            children: [
              // Header
              Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(color: isDark ? AppDark.accentSoft : AppColors.accentSoft, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(
                      user.initials,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: accent,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(user.firstName,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, fontFamily: 'Inter')),
                  const SizedBox(height: 2),
                  Text(user.email, style: TextStyle(fontSize: 14, color: muted)),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => _editProfile(user),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: borderSoft),
                      ),
                      child: Text('Modifier le profil',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: fg)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              ProfileRow(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Budget mensuel',
                value: formatFCFA(s.budget),
                onTap: () => _editBudget(),
              ),
              ProfileRow(
                icon: Icons.person_outline_rounded,
                label: 'Modifier le profil',
                onTap: () => _editProfile(user),
              ),
              ProfileRow(
                icon: Icons.lock_outline_rounded,
                label: 'Changer le mot de passe',
                onTap: () => _toastInfo('Un email de réinitialisation sera envoyé à ${user.email}'),
              ),
              ProfileRow(
                icon: Icons.tune_rounded,
                label: 'Préférences',
                onTap: () => _openPreferences(),
              ),
              ProfileRow(
                icon: Icons.info_outline_rounded,
                label: 'À propos',
                value: 'v1.0.0',
                onTap: () => _toastInfo('SamaPoche v1.0.0 — Gestion financière intelligente © 2026'),
                divider: false,
              ),
              const Divider(),
              ProfileRow(
                icon: Icons.dark_mode_outlined,
                label: 'Mode sombre',
                trailing: Switch(
                  value: s.darkMode,
                  onChanged: (v) => AppState.I.setDarkMode(v),
                ),
              ),
              ProfileRow(
                icon: Icons.health_and_safety_outlined,
                label: 'Sécurité',
                onTap: () => _toastInfo('🔐 2FA désactivée · Email vérifié · Dernière connexion : aujourd\'hui'),
              ),
              ProfileRow(
                icon: Icons.support_agent_rounded,
                label: 'Aide & Support',
                onTap: () => _toastInfo('Email: support@samapoche.com | WhatsApp: +221 77 123 45 67'),
              ),
              ProfileRow(
                icon: Icons.description_outlined,
                label: 'Conditions & Politique',
                onTap: () => _toastInfo('Conditions d\'utilisation & Politique de confidentialité — SamaPoche © 2026'),
                divider: false,
              ),
              const Divider(),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  await AppState.I.logout();
                  if (!mounted) return;
                  widget.go(RouteName.welcome);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark ? AppDark.dangerSoft : AppColors.dangerSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout_rounded, size: 20, color: danger),
                      const SizedBox(width: 8),
                      Text(
                        'Déconnexion',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: danger),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _editBudget() {
    final controller = TextEditingController(text: formatMontant(AppState.I.budget));
    showModal(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Budget mensuel',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: context.isDark ? AppDark.fg : AppColors.fg)),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: '150 000',
              hintStyle: TextStyle(color: context.isDark ? AppDark.meta : AppColors.meta),
            ),
          ),
          const SizedBox(height: 20),
          ModalFooter(
            cancelLabel: 'Annuler',
            confirmLabel: 'Enregistrer',
            onCancel: () => Navigator.pop(context),
            onConfirm: () async {
              final v = int.tryParse(controller.text.replaceAll(' ', '')) ?? 0;
              if (v <= 0) {
                showToast(context, 'Montant invalide', ToastType.error);
                return;
              }
              await AppState.I.setBudget(v);
              // ignore: use_build_context_synchronously
              if (!context.mounted) return;
              // ignore: use_build_context_synchronously
              Navigator.pop(context);
              // ignore: use_build_context_synchronously
              showToast(context, 'Budget mis à jour', ToastType.success);
            },
          ),
        ],
      ),
    );
  }

  void _openPreferences() {
    showModal(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (label, key) in [
            ('Notifications push', 'push'),
            ('Rappels de factures', 'factures'),
            ('Conseils IA personnalisés', 'conseils'),
            ('Mode économie de données', 'eco'),
            ('Budget automatique', 'auto'),
          ])
            StatefulBuilder(
              builder: (context, setModal) {
                final state = AppState.I;
                bool value;
                switch (key) {
                  case 'push':
                    value = state.notifPush;
                    break;
                  case 'factures':
                    value = state.notifFactures;
                    break;
                  case 'conseils':
                    value = state.notifConseils;
                    break;
                  case 'eco':
                    value = state.ecoData;
                    break;
                  default:
                    value = state.budgetAuto;
                }
                return CheckboxListTile(
                  value: value,
                  onChanged: (v) {
                    AppState.I.setPref(key, v ?? false);
                    setModal(() {});
                  },
                  title: Text(label,
                      style: TextStyle(fontSize: 16, color: context.isDark ? AppDark.fg : AppColors.fg)),
                  controlAffinity: ListTileControlAffinity.trailing,
                  activeColor: AppState.I.darkMode ? AppDark.accent : AppColors.accent,
                  contentPadding: EdgeInsets.zero,
                );
              },
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: AppButton(label: 'Fermer', small: true, onPressed: () => Navigator.pop(context)),
          ),
        ],
      ),
    );
  }

  void _editProfile(UserProfile user) {
    final first = TextEditingController(text: user.firstName);
    final last = TextEditingController(text: user.lastName);
    final email = TextEditingController(text: user.email);
    final phone = TextEditingController(text: user.phone);
    String? firstError;
    String? emailError;

    showModal(
      context,
      StatefulBuilder(
        builder: (context, setModal) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Modifier le profil',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: context.isDark ? AppDark.fg : AppColors.fg)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: first,
                    decoration: InputDecoration(labelText: 'Prénom', errorText: firstError),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(controller: last, decoration: const InputDecoration(labelText: 'Nom')),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: email,
              decoration: InputDecoration(labelText: 'Email', errorText: emailError),
            ),
            const SizedBox(height: 16),
            TextField(controller: phone, decoration: const InputDecoration(labelText: 'Téléphone')),
            const SizedBox(height: 20),
            ModalFooter(
              cancelLabel: 'Annuler',
              confirmLabel: 'Enregistrer',
              onCancel: () => Navigator.pop(context),
              onConfirm: () async {
                setModal(() {
                  firstError = first.text.trim().isEmpty ? 'Nom complet requis' : null;
                  emailError = email.text.trim().isEmpty ? 'Email requis' : null;
                });
                if (firstError != null || emailError != null) return;
                await AppState.I.saveProfile(UserProfile(
                  firstName: first.text.trim(),
                  lastName: last.text.trim(),
                  email: email.text.trim(),
                  phone: phone.text.trim(),
                ));
                if (!context.mounted) return;
                Navigator.pop(context);
                showToast(context, 'Profil mis à jour', ToastType.success);
              },
            ),
          ],
        ),
      ),
    );
  }
}
