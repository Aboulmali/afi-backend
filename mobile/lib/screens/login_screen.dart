import 'package:flutter/material.dart';
import 'package:samapoche/screens/root_shell.dart';
import 'package:samapoche/theme.dart';
import 'package:samapoche/state/app_state.dart';
import 'package:samapoche/widgets/widgets.dart';

class LoginScreen extends StatefulWidget {
  final void Function(RouteName) go;
  const LoginScreen({super.key, required this.go});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _showPass = false;
  bool _remember = false;
  bool _loading = false;
  String? _emailError;
  String? _passError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _email.text.trim();
    final pass = _password.text;
    setState(() {
      _emailError = email.isEmpty ? 'Email requis' : null;
      _passError = pass.isEmpty ? 'Mot de passe requis' : null;
    });
    if (_emailError != null || _passError != null) return;

    setState(() => _loading = true);
    final err = await AppState.I.login(email, pass);
    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      showToast(context, err, ToastType.error);
    } else {
      showToast(context, 'Connecté avec succès', ToastType.success);
      widget.go(RouteName.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final borderSoft = isDark ? AppDark.borderSoft : AppColors.borderSoft;
    final meta = isDark ? AppDark.meta : AppColors.meta;
    final accent = isDark ? AppDark.accent : AppColors.accent;
    final muted = isDark ? AppDark.muted : AppColors.muted;

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
              'Bienvenue',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, fontFamily: 'Inter'),
            ),
            const SizedBox(height: 4),
            Text(
              'Connectez-vous pour continuer',
              style: TextStyle(fontSize: 16, color: muted),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: TextStyle(color: meta, fontSize: 14, fontWeight: FontWeight.w500),
                floatingLabelStyle: TextStyle(color: accent, fontWeight: FontWeight.w500),
                errorText: _emailError,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _password,
              obscureText: !_showPass,
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                labelStyle: TextStyle(color: meta, fontSize: 14, fontWeight: FontWeight.w500),
                floatingLabelStyle: TextStyle(color: accent, fontWeight: FontWeight.w500),
                errorText: _passError,
                suffixIcon: IconButton(
                  icon: Icon(_showPass ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20, color: meta),
                  onPressed: () => setState(() => _showPass = !_showPass),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _remember = !_remember),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: _remember ? accent : Colors.transparent,
                          border: Border.all(color: _remember ? accent : borderSoft, width: 2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: _remember ? const Icon(Icons.check, color: Colors.white, size: 12) : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Se souvenir de moi',
                        style: TextStyle(fontSize: 14, color: isDark ? AppDark.fg2 : AppColors.fg2),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => showToast(context, 'Un email de réinitialisation sera envoyé à votre adresse', ToastType.info),
                  child: Text(
                    'Mot de passe oublié ?',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: accent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            AppButton(label: 'Continuer', primary: true, loading: _loading, onPressed: _login),
            const SizedBox(height: 20),
            Center(
              child: Text(
                'Pas encore de compte ? ',
                style: TextStyle(fontSize: 14, color: muted),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: GestureDetector(
                onTap: () => widget.go(RouteName.signup),
                child: Text(
                  'Créer un compte',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: accent),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: Divider(color: borderSoft)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('Ou se connecter avec', style: TextStyle(fontSize: 12, color: meta)),
                ),
                Expanded(child: Divider(color: borderSoft)),
              ],
            ),
            const SizedBox(height: 14),
            AppButton(
              label: 'Apple',
              ghost: true,
              onPressed: () => showToast(context, 'Connexion Apple bientôt disponible', ToastType.info),
              icon: const Icon(Icons.apple_rounded, size: 18),
            ),
            const SizedBox(height: 8),
            AppButton(
              label: 'Google',
              ghost: true,
              onPressed: () => showToast(context, 'Connexion Google bientôt disponible', ToastType.info),
              icon: const Icon(Icons.g_mobiledata_rounded, size: 24, color: Color(0xFF4285F4)),
            ),
          ],
        ),
      ),
    );
  }
}
