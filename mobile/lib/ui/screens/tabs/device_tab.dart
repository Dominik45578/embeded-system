import 'package:flutter/material.dart';

import '../../../core/services/iot_device_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_card.dart';


class DevicesTab extends StatelessWidget {
  const DevicesTab({super.key});

  Future<void> _handleRefresh() async {
    await IotDeviceService.instance.fetchMyDevices();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: const Color(0xFF00ADB5),
      backgroundColor: const Color(0xFF1E1E1E),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        children: [
          const Text(
            'Panel Główny',
            style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          CustomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Lockly Smart Lock',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Icon(Icons.lock_outline, color: Color(0xFF00ADB5)),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        text: 'Otwórz',
                        icon: Icons.lock_open_rounded,
                        onPressed: () {},
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomButton(
                        text: 'Zamknij',
                        icon: Icons.lock_rounded,
                        type: CustomButtonType.secondary,
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                CustomButton(
                  text: 'Zmień PIN urządzenia',
                  icon: Icons.password_rounded,
                  type: CustomButtonType.secondary,
                  isFullWidth: true,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}