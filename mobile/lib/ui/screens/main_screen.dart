import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockly_app/core/services/auth.dart';
import 'package:lockly_app/ui/screens/login_screen.dart';
import 'package:lockly_app/ui/screens/root_layout.dart';

class MainScreen extends StatelessWidget {
  final AuthRepository _authRepository = AuthRepository();

  MainScreen({super.key});

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

        if (snapshot.hasData) {
          return const RootLayout();
        }

        return const LoginScreen();
      },
    );
  }
}