import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:samapoche/screens/root_shell.dart';
import 'package:samapoche/state/app_state.dart';
import 'package:samapoche/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SamaPocheApp());
}

class SamaPocheApp extends StatelessWidget {
  const SamaPocheApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.I,
      builder: (context, _) {
        return MaterialApp(
          title: 'SamaPoche',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: AppState.I.darkMode ? ThemeMode.dark : ThemeMode.light,
          locale: const Locale('fr'),
          supportedLocales: const [Locale('fr')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: AppState.I.loaded ? const RootShell() : const _Boot(),
        );
      },
    );
  }
}

class _Boot extends StatefulWidget {
  const _Boot();

  @override
  State<_Boot> createState() => _BootState();
}

class _BootState extends State<_Boot> {
  @override
  void initState() {
    super.initState();
    AppState.I.init().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.accent),
        ),
      ),
    );
  }
}
