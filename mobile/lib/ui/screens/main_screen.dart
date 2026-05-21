import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockly_app/core/services/auth.dart';
import 'package:lockly_app/core/services/user_bootstrap_service.dart';
import 'package:lockly_app/ui/screens/login_screen.dart';
import 'package:lockly_app/ui/screens/root_layout.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final AuthRepository _authRepository = AuthRepository();
  final UserBootstrapService _userBootstrapService =
      UserBootstrapService.instance;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authRepository.userStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF121212),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF00ADB5),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          _userBootstrapService.reset();
          return const LoginScreen();
        }

        return FutureBuilder<void>(
          future: _userBootstrapService.ensureCurrentUserReady(),
          builder: (context, bootstrapSnapshot) {
            // Blokujemy interfejs tylko podczas trwania pierwszej, aktywnej próby połączenia,
            // pod warunkiem, że nie wystąpił jeszcze żaden błąd ani nie mamy sukcesu.
            if (bootstrapSnapshot.connectionState == ConnectionState.waiting &&
                !_userBootstrapService.isReady &&
                _userBootstrapService.errorMessage == null) {
              return const Scaffold(
                backgroundColor: Color(0xFF121212),
                body: Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF00ADB5),
                  ),
                ),
              );
            }
            return const RootLayout();
          },
        );
      },
    );
  }
}
