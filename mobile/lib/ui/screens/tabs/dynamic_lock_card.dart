import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/model/device.dart';
import '../../../core/model/device_telemetry_point.dart';
import '../../../core/model/iot_device.dart';
import '../../../core/model/lock_command.dart';
import '../../../core/services/ble/ble_device_manger.dart';
import '../../../core/services/ble/ble_lock_connection.dart';
import '../../../core/services/iot_device_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_card.dart';
import 'device_settings_sheet.dart';

class DynamicLockCard extends StatefulWidget {
  final Device device;
  final IotDevice? registeredDevice;

  const DynamicLockCard({
    super.key,
    required this.device,
    this.registeredDevice,
  });

  @override
  State<DynamicLockCard> createState() => _DynamicLockCardState();
}

class _DynamicLockCardState extends State<DynamicLockCard> {
  final BleDeviceManager _bleManager = BleDeviceManager();
  late final IotDeviceService _iotDeviceService;

  bool _isConnectingBt = false;
  bool _isCheckingWifi = false;
  bool _isWifiOnline = false;
  bool _isWifiCommandLoading = false;
  bool _isTelemetryLoading = false;
  List<DeviceTelemetryPoint> _telemetryData = const [];

  bool get _isRegistered => widget.registeredDevice != null;
  bool get _isBlocked => widget.registeredDevice?.isBlocked ?? widget.device.isBlocked;

  @override
  void initState() {
    super.initState();
    _iotDeviceService = Provider.of<IotDeviceService>(context, listen: false);
    if (_isRegistered) {
      _checkWifiStatus(silent: true);
      _loadTelemetry();
    }
  }

  @override
  void didUpdateWidget(covariant DynamicLockCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.registeredDevice?.deviceId != widget.registeredDevice?.deviceId &&
        _isRegistered) {
      _checkWifiStatus(silent: true);
      _loadTelemetry();
    }
  }

  Future<void> _connectToDevice() async {
    if (_isConnectingBt) return;
    setState(() => _isConnectingBt = true);

    try {
      // Łączenie przez Bluetooth wymaga fizycznego adresu MAC
      await _bleManager.connectToDevice(widget.device.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Blad polaczenia BT: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isConnectingBt = false);
    }
  }

  Future<void> _handleUnlock(BuildContext context, BleLockConnection connection) async {
    final pin = await _showInputDialog(context, 'Wprowadz PIN', 'PIN');
    if (pin != null && pin.isNotEmpty) {
      await connection.sendCommand(LockCommand(LockCommandType.unlock, [pin]));
    }
  }

  Future<void> _handleChangePin(BuildContext context, BleLockConnection connection) async {
    final oldPin = await _showInputDialog(context, 'Podaj obecny PIN', 'Stary PIN');
    if (oldPin == null || oldPin.isEmpty) return;

    final newPin = await _showInputDialog(context, 'Podaj nowy PIN', 'Nowy PIN');
    if (newPin != null && newPin.isNotEmpty) {
      await connection.sendCommand(LockCommand(LockCommandType.changePin, [oldPin, newPin]));
    }
  }

  Future<void> _checkWifiStatus({bool silent = false}) async {
    if (!_isRegistered || _isCheckingWifi) return;

    setState(() => _isCheckingWifi = true);
    try {
      // Zapytanie do serwera wymaga identyfikatora sprzętowego (hardwareId)
      final isAlive = await _iotDeviceService.checkIsAlive(widget.device.hardwareId);
      if (mounted) setState(() => _isWifiOnline = isAlive);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isWifiOnline = false);
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nie udalo sie sprawdzic WiFi: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingWifi = false);
    }
  }

  Future<void> _sendWifiCommand(String command) async {
    if (!_isWifiOnline || _isWifiCommandLoading || _isBlocked) return;

    setState(() => _isWifiCommandLoading = true);
    try {
      // Wysłanie komendy przez serwer wymaga identyfikatora sprzętowego (hardwareId)
      await _iotDeviceService.sendCommand(widget.device.hardwareId, command);
      await Future.delayed(const Duration(milliseconds: 350));
      await _loadTelemetry();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nie udalo sie wyslac komendy WiFi: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isWifiCommandLoading = false);
    }
  }

  Future<void> _loadTelemetry() async {
    if (!_isRegistered || _isTelemetryLoading) return;

    setState(() => _isTelemetryLoading = true);
    try {
      // Pobranie punktów wykresu z InfluxDB wymaga identyfikatora sprzętowego (hardwareId)
      final telemetry = await _iotDeviceService.getDeviceTelemetry(widget.device.hardwareId);
      telemetry.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      if (mounted) setState(() => _telemetryData = telemetry);
    } catch (_) {
      if (mounted) setState(() => _telemetryData = const []);
    } finally {
      if (mounted) setState(() => _isTelemetryLoading = false);
    }
  }

  Future<String?> _showInputDialog(BuildContext context, String title, String hint) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anuluj', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Zatwierdz', style: TextStyle(color: Color(0xFF00ADB5))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _bleManager,
      builder: (context, child) {
        // Logika wyszukiwania połączenia w menedżerze BLE opiera się na adresie MAC
        final connection = _bleManager.getConnection(widget.device.id);
        final isBtConnected = _bleManager.isConnected(widget.device.id);

        return CustomCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isBtConnected),
              const SizedBox(height: 8),
              _buildBluetoothSection(isBtConnected, connection),
              const SizedBox(height: 12),
              _buildWifiSection(),
              const SizedBox(height: 16),
              _buildTelemetryPreview(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isBtConnected) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            widget.registeredDevice?.deviceName.isNotEmpty == true
                ? widget.registeredDevice!.deviceName
                : (widget.device.name.isNotEmpty ? widget.device.name : 'Zamek bez nazwy'),
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Row(
          children: [
            _buildBadge(Icons.bluetooth, 'BT', isBtConnected ? const Color(0xFF00ADB5) : Colors.grey),
            const SizedBox(width: 6),
            if (_isWifiOnline || _isCheckingWifi)
              _buildBadge(
                _isCheckingWifi ? Icons.wifi_find : Icons.wifi,
                'WiFi',
                _isWifiOnline ? Colors.green : Colors.amber,
              ),
            if (_isRegistered) ...[
              const SizedBox(width: 6),
              _buildBadge(
                Icons.verified_user,
                'Konto',
                _isBlocked ? Colors.redAccent : Colors.purpleAccent,
              ),
            ],
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.grey),
              onPressed: () => DeviceSettingsSheet.show(context, widget.device),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBluetoothSection(bool isBtConnected, BleLockConnection? connection) {
    if (!isBtConnected) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Bluetooth: rozlaczony', style: TextStyle(color: Colors.white.withOpacity(0.6))),
          if (_isConnectingBt)
            const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00ADB5)),
            )
          else
            TextButton(
              onPressed: _connectToDevice,
              child: const Text(
                'Polacz BT',
                style: TextStyle(color: Color(0xFF00ADB5), fontWeight: FontWeight.bold),
              ),
            ),
        ],
      );
    }

    if (connection == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Text('Status BT: inicjalizacja...', style: TextStyle(color: Colors.amber)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatusStream(connection),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: CustomButton(
                text: 'Otworz BT',
                icon: Icons.lock_open_rounded,
                onPressed: _isBlocked ? null : () => _handleUnlock(context, connection),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CustomButton(
                text: 'Zamknij BT',
                icon: Icons.lock_rounded,
                type: CustomButtonType.secondary,
                onPressed: _isBlocked
                    ? null
                    : () => connection.sendCommand(LockCommand(LockCommandType.lock)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        CustomButton(
          text: 'Zmien PIN',
          icon: Icons.password_rounded,
          type: CustomButtonType.secondary,
          isFullWidth: true,
          onPressed: _isBlocked ? null : () => _handleChangePin(context, connection),
        ),
      ],
    );
  }

  Widget _buildWifiSection() {
    if (!_isRegistered) return const SizedBox.shrink();

    if (!_isWifiOnline) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('WiFi: offline', style: TextStyle(color: Colors.white.withOpacity(0.6))),
          if (_isCheckingWifi)
            const Row(
              children: [
                Icon(Icons.wifi_find, color: Colors.amber, size: 20),
                SizedBox(width: 8),
                SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber),
                ),
              ],
            )
          else
            TextButton.icon(
              onPressed: () => _checkWifiStatus(),
              icon: const Icon(Icons.wifi_find, color: Color(0xFF00ADB5)),
              label: const Text(
                'Polacz WiFi',
                style: TextStyle(color: Color(0xFF00ADB5), fontWeight: FontWeight.bold),
              ),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sterowanie WiFi', style: TextStyle(color: Colors.white.withOpacity(0.7))),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: CustomButton(
                text: 'Otworz WiFi',
                icon: Icons.wifi,
                onPressed: _isBlocked || _isWifiCommandLoading
                    ? null
                    : () => _sendWifiCommand('UNLOCK'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CustomButton(
                text: 'Zamknij WiFi',
                icon: Icons.wifi_lock,
                type: CustomButtonType.secondary,
                onPressed: _isBlocked || _isWifiCommandLoading
                    ? null
                    : () => _sendWifiCommand('LOCK'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusStream(BleLockConnection connection) {
    return StreamBuilder<String>(
      stream: connection.lockStateStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text('Status BT: polaczono, oczekiwanie na dane...', style: TextStyle(color: Colors.amber)),
          );
        }

        String displayStatus = snapshot.data ?? 'Brak danych';
        Color statusColor = Colors.grey;

        if (snapshot.hasData) {
          if (displayStatus.contains('UNLOCKED')) {
            displayStatus = 'Zamek otwarty';
            statusColor = Colors.green;
          } else if (displayStatus.contains('LOCKED')) {
            displayStatus = 'Zamek zamkniety';
            statusColor = Colors.red;
          } else if (displayStatus.contains('PIN_CHANGED')) {
            displayStatus = 'Zmieniono PIN';
            statusColor = Colors.orange;
          } else {
            statusColor = Colors.amber;
          }
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text('Status BT: $displayStatus', style: TextStyle(color: statusColor)),
        );
      },
    );
  }

  Widget _buildTelemetryPreview() {
    if (!_isRegistered) return const SizedBox.shrink();

    if (_isTelemetryLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00ADB5)),
        ),
      );
    }

    if (_telemetryData.length < 2) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Brak wystarczajacych danych do wykresu.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
      );
    }

    final points = _telemetryData.length > 20
        ? _telemetryData.sublist(_telemetryData.length - 20)
        : _telemetryData;
    final spots = points
        .map((point) => FlSpot(
      point.timestamp.millisecondsSinceEpoch.toDouble(),
      point.lockState.toDouble(),
    ))
        .toList();
    final minX = spots.first.x;
    final maxX = spots.last.x == minX ? minX + 1 : spots.last.x;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Aktywnosc zamka', style: TextStyle(color: Colors.white.withOpacity(0.7))),
        const SizedBox(height: 10),
        SizedBox(
          height: 120,
          child: LineChart(
            LineChartData(
              minX: minX,
              maxX: maxX,
              minY: -0.2,
              maxY: 1.2,
              gridData: FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) {
                        return const Text('Zam', style: TextStyle(color: Colors.grey, fontSize: 10));
                      }
                      if (value == 1) {
                        return const Text('Otw', style: TextStyle(color: Colors.grey, fontSize: 10));
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  color: const Color(0xFF00ADB5),
                  barWidth: 2,
                  dotData: FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: const Color(0xFF00ADB5).withOpacity(0.12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}