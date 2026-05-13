import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/services/identity_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_card.dart';
import '../connection_config_screen.dart';


class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final IdentityService _identityService = IdentityService.instance;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      final String? idToken = await _firebaseAuth.currentUser?.getIdToken();

      if (idToken == null) {
        debugPrint("Użytkownik nie jest zalogowany w Firebase Auth.");
        return;
      }

      final authToken = await _identityService.verifyToken(idToken);

      if (authToken != null && authToken.uid.isNotEmpty) {
        await _identityService.fetchIdentity(authToken.uid);
      }
    } catch (e) {
      debugPrint("Wystąpił błąd podczas ładowania danych profilu: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _identityService,
      builder: (context, child) {
        return RefreshIndicator(
          onRefresh: _loadProfileData,
          color: const Color(0xFF00ADB5),
          backgroundColor: const Color(0xFF1E1E1E),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Mój Profil',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_suggest_rounded, color: Color(0xFF00ADB5), size: 28),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ConnectionConfigScreen()),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (_identityService.isLoading && _identityService.currentUserRecord == null)
                const SizedBox(
                  height: 200,
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF00ADB5)),
                  ),
                )
              else if (_identityService.errorMessage != null)
                CustomCard(
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFFF453A), size: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Wystąpił błąd pobierania',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Sprawdź połączenie z siecią i spróbuj ponownie.',
                              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                  CustomCard(
                    title: 'DANE UŻYTKOWNIKA',
                    child: Column(
                      children: [
                        _buildProfileRow(Icons.person_rounded, 'Imię i nazwisko', _identityService.currentUserRecord?.fullName ?? 'Brak danych'),
                        _buildProfileRow(Icons.alternate_email_rounded, 'Adres Email', _identityService.currentUserRecord?.email ?? 'Brak danych'),
                        _buildProfileRow(
                          Icons.check_circle_outline_rounded,
                          'Status konta',
                          (_identityService.currentUserRecord?.active ?? false) ? 'Aktywne' : 'Nieaktywne',
                          valueColor: (_identityService.currentUserRecord?.active ?? false) ? const Color(0xFF00ADB5) : const Color(0xFFFF453A),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  CustomCard(
                    title: 'DANE Z TOKENU SESJI',
                    child: Column(
                      children: [
                        _buildProfileRow(Icons.fingerprint_rounded, 'UID użytkownika', _identityService.currentAuthToken?.uid ?? 'Brak tokenu', isMonospace: true),
                        _buildProfileRow(Icons.verified_user_rounded, 'Wystawca (Issuer)', _identityService.currentAuthToken?.issuer ?? 'Brak tokenu'),
                        _buildProfileRow(Icons.admin_panel_settings_rounded, 'Przypisane role', _identityService.currentAuthToken?.roles?.join(', ') ?? 'Brak ról'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  CustomCard(
                    title: 'POWIADOMIENIA PUSH',
                    child: _buildProfileRow(
                      Icons.notifications_active_rounded,
                      'Token FCM',
                      'Placeholder - oczekiwanie na rejestrację urządzenia',
                      valueColor: Colors.white.withOpacity(0.4),
                    ),
                  ),
                ],

              const SizedBox(height: 32),
              CustomButton(
                text: 'Konfiguracja połączenia API',
                icon: Icons.settings_ethernet_rounded,
                type: CustomButtonType.secondary,
                isFullWidth: true,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ConnectionConfigScreen()),
                  );
                },
              ),
              const SizedBox(height: 12),
              CustomButton(
                text: 'Wyloguj się',
                icon: Icons.logout_rounded,
                type: CustomButtonType.danger,
                isFullWidth: true,
                onPressed: () {
                  // Implementacja wylogowania z Firebase Auth
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileRow(IconData icon, String label, String value, {Color? valueColor, bool isMonospace = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF8E8E93), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor ?? Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: isMonospace ? 'monospace' : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}