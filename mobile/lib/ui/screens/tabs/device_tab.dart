import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/model/iot_device.dart';
import '../../../core/services/ble/ble_device_manger.dart';
import '../../../core/services/iot_device_service.dart';
import 'device_scanner_modal.dart';
import 'dynamic_lock_card.dart';

class DevicesTab extends StatefulWidget {
  const DevicesTab({super.key});

  @override
  State<DevicesTab> createState() => _DevicesTabState();
}

class _DevicesTabState extends State<DevicesTab> {
  List<IotDevice> _backendDevices = const [];
  bool _isLoadingBackendDevices = false;
  String? _backendError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshBackendDevices();
    });
  }

  Future<void> _handleRefresh() async {
    final manager = BleDeviceManager();
    await manager.init();
    await _refreshBackendDevices();
  }

  Future<void> _refreshBackendDevices() async {
    if (_isLoadingBackendDevices) return;

    setState(() {
      _isLoadingBackendDevices = true;
      _backendError = null;
    });

    try {
      final service = Provider.of<IotDeviceService>(context, listen: false);
      final devices = await service.getDevicesForCurrentUser();
      if (!mounted) return;
      setState(() => _backendDevices = devices);
    } catch (e) {
      if (!mounted) return;
      setState(() => _backendError = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoadingBackendDevices = false);
      }
    }
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
          final backendById = {
            for (final device in _backendDevices) device.deviceId: device,
          };
          final visibleDevices = savedDevices
              .where((device) => backendById.containsKey(device.hardwareId))
              .toList();

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
                    onPressed: () async {
                      final added = await DeviceScannerModal.show(context);
                      if (added == true) {
                        await _handleRefresh();
                      }
                    },
                  )
                ],
              ),
              const SizedBox(height: 24),
              if (_isLoadingBackendDevices)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16.0),
                  child: LinearProgressIndicator(
                    color: Color(0xFF00ADB5),
                    backgroundColor: Colors.white10,
                  ),
                ),
              if (_backendError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    'Nie udało się pobrać urządzeń z konta.',
                    style: TextStyle(color: Colors.redAccent.withOpacity(0.9)),
                  ),
                ),

              if (visibleDevices.isEmpty)
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
                ...visibleDevices.map((device) => Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: DynamicLockCard(
                    device: device,
                    registeredDevice: backendById[device.id],
                  ),
                )),
            ],
          );
        },
      ),
    );
  }
}
