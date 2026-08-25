import 'package:flutter/material.dart';
import 'package:samapoche/models/models.dart';
import 'package:samapoche/screens/root_shell.dart';
import 'package:samapoche/theme.dart';
import 'package:samapoche/state/app_state.dart';
import 'package:samapoche/widgets/widgets.dart';

class SignupScreen extends StatefulWidget {
  final void Function(RouteName) go;
  const SignupScreen({super.key, required this.go});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  bool _showPass = false;
  bool _terms = false;
  bool _loading = false;

  String? _firstError, _lastError, _emailError, _phoneError, _passError, _confirmError;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _email.dispose();
    _phone.dispose();
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    setState(() {
      _firstError = _first.text.trim().isEmpty ? 'Prénom requis' : null;
      _lastError = _last.text.trim().isEmpty ? 'Nom requis' : null;
      _emailError = _email.text.trim().isEmpty ? 'Email requis' : null;
      _phoneError = _phone.text.trim().isEmpty ? 'Téléphone requis' : null;
      _passError = _pass.text.isEmpty
          ? 'Mot de passe requis'
          : _pass.text.length < 8
              ? '8 caractères minimum'
              : null;
      _confirmError = _confirm.text.isEmpty
          ? 'Confirmation requise'
          : _confirm.text != _pass.text
              ? 'Les mots de passe ne correspondent pas'
              : null;
    });
    if ([_firstError, _lastError, _emailError, _phoneError, _passError, _confirmError].any((e) => e != null)) return;
    if (!_terms) {
      showToast(context, 'Veuillez accepter les conditions d\'utilisation', ToastType.warning);
      return;
    }

    setState(() => _loading = true);
    final err = await AppState.I.signup(
      UserProfile(
        firstName: _first.text.trim(),
        lastName: _last.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
      ),
      _pass.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      showToast(context, err, ToastType.error);
    } else {
      showToast(context, 'Compte créé avec succès !', ToastType.success);
      widget.go(RouteName.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final muted = isDark ? AppDark.muted : AppColors.muted;
    final accent = isDark ? AppDark.accent : AppColors.accent;
    final meta = isDark ? AppDark.meta : AppColors.meta;
    final borderSoft = isDark ? AppDark.borderSoft : AppColors.borderSoft;
    final fg2 = isDark ? AppDark.fg2 : AppColors.fg2;

    InputDecoration dec(String label, String? error) => InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: meta, fontSize: 14, fontWeight: FontWeight.w500),
          floatingLabelStyle: TextStyle(color: accent, fontWeight: FontWeight.w500),
          errorText: error,
        );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => widget.go(RouteName.welcome),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                    const SizedBox(width: 8),
                    const Text('Retour', style: TextStyle(fontSize: 14, fontFamily: 'Inter')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Créer un compte',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, fontFamily: 'Inter'),
            ),
            const SizedBox(height: 4),
            Text(
              'Rejoignez SamaPoche en un instant',
              style: TextStyle(fontSize: 16, color: muted),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _first,
                    decoration: dec('Prénom', _firstError),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _last,
                    decoration: dec('Nom', _lastError),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: dec('Email', _emailError)),
            const SizedBox(height: 16),
            TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: dec('Téléphone', _phoneError)),
            const SizedBox(height: 16),
            TextField(
              controller: _pass,
              obscureText: !_showPass,
              decoration: dec('Mot de passe', _passError).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(_showPass ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20, color: meta),
                  onPressed: () => setState(() => _showPass = !_showPass),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(controller: _confirm, obscureText: !_showPass, decoration: dec('Confirmer le mot de passe', _confirmError)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => setState(() => _terms = !_terms),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: _terms ? accent : Colors.transparent,
                      border: Border.all(color: _terms ? accent : borderSoft, width: 2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: _terms ? const Icon(Icons.check, color: Colors.white, size: 12) : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: "J'accepte les ",
                        style: TextStyle(fontSize: 14, color: fg2, height: 1.4),
                        children: [
                          TextSpan(
                            text: 'conditions d\'utilisation',
                            style: TextStyle(color: accent, fontWeight: FontWeight.w600),
                          ),
                          TextSpan(text: ' et la '),
                          TextSpan(
                            text: 'politique de confidentialité',
                            style: TextStyle(color: accent, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            AppButton(label: "S'inscrire", primary: true, loading: _loading, onPressed: _signup),
            const SizedBox(height: 20),
            Center(
              child: Text(
                'Déjà un compte ? ',
                style: TextStyle(fontSize: 14, color: muted),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: GestureDetector(
                onTap: () => widget.go(RouteName.login),
                child: Text(
                  'Se connecter',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: accent),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
