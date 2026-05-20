import 'package:flutter/material.dart';

import '../../../core/model/device.dart';
import '../../../core/services/ble/ble_device_manger.dart';
import 'device_scanner_modal.dart';
import 'dynamic_lock_card.dart';

class DevicesTab extends StatelessWidget {
  const DevicesTab({super.key});

  Future<void> _handleRefresh() async {
    final manager = BleDeviceManager();
    await manager.init();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: const Color(0xFF00ADB5),
      backgroundColor: const Color(0xFF1E1E1E),
      child: ListenableBuilder(
        listenable: BleDeviceManager(),
        builder: (context, child) {
          final savedDevices = BleDeviceManager().savedDevices;

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Panel Główny',
                    style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: Color(0xFF00ADB5), size: 32),
                    onPressed: () => DeviceScannerModal.show(context),
                  )
                ],
              ),
              const SizedBox(height: 24),

              if (savedDevices.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 50.0),
                    child: Text(
                      'Brak dodanych urządzeń.\nKliknij + aby wyszukać.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ),
                )
              else
                ...savedDevices.map((device) => Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: DynamicLockCard(device: device),
                )),
            ],
          );
        },
      ),
    );
  }
}