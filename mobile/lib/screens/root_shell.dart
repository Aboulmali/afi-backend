import 'package:flutter/material.dart';
import 'package:samapoche/screens/add_transaction_screen.dart';
import 'package:samapoche/screens/assistant_screen.dart';
import 'package:samapoche/screens/home_screen.dart';
import 'package:samapoche/screens/login_screen.dart';
import 'package:samapoche/screens/notifications_screen.dart';
import 'package:samapoche/screens/profile_screen.dart';
import 'package:samapoche/screens/signup_screen.dart';
import 'package:samapoche/screens/transactions_screen.dart';
import 'package:samapoche/screens/welcome_screen.dart';
import 'package:samapoche/state/app_state.dart';
import 'package:samapoche/theme.dart';
import 'package:samapoche/widgets/widgets.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

enum RouteName { welcome, login, signup, home, transactions, assistant, profile, notifications, addTransaction }

class _RootShellState extends State<RootShell> {
  RouteName route = RouteName.welcome;
  int tab = 0;

  void go(RouteName r) => setState(() => route = r);

  void openNotifications() => setState(() => route = RouteName.notifications);

  void switchTab(int i) {
    setState(() {
      tab = i;
      route = [RouteName.home, RouteName.transactions, RouteName.assistant, RouteName.profile][i];
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = AppState.I.user;

    final Widget screen = switch (route) {
      RouteName.welcome => WelcomeScreen(go: go),
      RouteName.login => LoginScreen(go: go),
      RouteName.signup => SignupScreen(go: go),
      RouteName.home => HomeScreen(onOpenNotifications: openNotifications, onGo: go),
      RouteName.transactions => const TransactionsScreen(),
      RouteName.assistant => const AssistantScreen(),
      RouteName.profile => ProfileScreen(go: go),
      RouteName.notifications => NotificationsScreen(go: go),
      RouteName.addTransaction => AddTransactionScreen(onClose: () => go(RouteName.home)),
    };

    final showTabs = user != null &&
        (route == RouteName.home || route == RouteName.transactions || route == RouteName.assistant || route == RouteName.profile);

    final showFab = user != null && route == RouteName.home;

    return Scaffold(
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: KeyedSubtree(
              key: ValueKey(route),
              child: screen,
            ),
          ),
          if (showFab)
            Positioned(
              right: 20,
              bottom: 96,
              child: FloatingActionButton(
                onPressed: () => go(RouteName.addTransaction),
                backgroundColor: AppState.I.darkMode ? AppDark.accent : AppColors.accent,
                foregroundColor: Colors.white,
                elevation: 4,
                shape: const CircleBorder(),
                child: const Icon(Icons.add_rounded, size: 28),
              ),
            ),
        ],
      ),
      bottomNavigationBar: showTabs ? AppTabBar(current: tab, onTap: switchTab) : null,
    );
  }
}
