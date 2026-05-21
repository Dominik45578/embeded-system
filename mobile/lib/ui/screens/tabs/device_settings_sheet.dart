import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/model/device.dart';
import '../../../core/model/iot_device.dart';
import '../../../core/model/device_telemetry_point.dart';
import '../../../core/services/ble/ble_device_manger.dart';
import '../../../core/services/iot_device_service.dart';

class DeviceSettingsSheet extends StatefulWidget {
  final Device device;
  final ScrollController scrollController;

  const DeviceSettingsSheet({super.key, required this.device, required this.scrollController});

  static void show(BuildContext context, Device device) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (BuildContext context, ScrollController scrollController) {
          return DeviceSettingsSheet(device: device, scrollController: scrollController);
        },
      ),
    );
  }

  @override
  State<DeviceSettingsSheet> createState() => _DeviceSettingsSheetState();
}

class _DeviceSettingsSheetState extends State<DeviceSettingsSheet> {
  final _formKey = GlobalKey<FormState>();
  final _wifiSsidController = TextEditingController();
  final _wifiPasswordController = TextEditingController();
  final _mqttBrokerController = TextEditingController();
  final _mqttTopicController = TextEditingController();

  late final BleDeviceManager _bleManager;
  late final IotDeviceService _iotDeviceService;

  String _deviceIdFromFf30 = "Ładowanie...";
  String _macAddress = "Brak (offline)";
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditing = false;
  bool _isWifiPasswordVisible = false;
  String? _errorMessage;

  IotDevice? _iotDevice;
  bool _isCheckingStatus = false;
  bool _isDeviceAlive = false;
  bool _isActionLoading = false;
  List<DeviceTelemetryPoint> _telemetryData = [];
  String _selectedTelemetrySource = 'all';
  String _selectedTelemetryAction = 'all';

  String _initialMqttBroker = '';
  String _initialMqttTopic = '';

  @override
  void initState() {
    super.initState();
    _bleManager = Provider.of<BleDeviceManager>(context, listen: false);
    _iotDeviceService = Provider.of<IotDeviceService>(context, listen: false);
    _macAddress = widget.device.id; // Adres MAC dla celów diagnostycznych interfejsu
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await _checkBackendStatus();

    // Sprawdzanie stanu połączenia w menedżerze BLE wymaga fizycznego adresu MAC
    final isConnected = _bleManager.isConnected(widget.device.id);
    if (isConnected) {
      await _loadDeviceConfiguration();
    } else {
      setState(() {
        _deviceIdFromFf30 = "Rozłączono";
        _isLoading = false;
      });
    }
  }

  Future<void> _checkBackendStatus() async {
    setState(() => _isCheckingStatus = true);
    try {
      // Zapytania do API chmurowego wykorzystują unikalny identyfikator sprzętowy (hardwareId)
      final deviceDetails = await _iotDeviceService.getDeviceDetails(widget.device.hardwareId);
      if (mounted) {
        setState(() {
          _iotDevice = deviceDetails;
        });
      }

      if (deviceDetails == null) {
        if (mounted) {
          setState(() {
            _errorMessage = "Urządzenie nie jest przypisane do konta w backendzie. Dodaj je ponownie przez skaner.";
          });
        }
      } else {
        await _checkAliveStatus(showSnackBar: false);
        await _fetchTelemetry();
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Błąd komunikacji z serwerem: $e");
    } finally {
      if (mounted) setState(() => _isCheckingStatus = false);
    }
  }

  Future<void> _fetchTelemetry() async {
    try {
      // Pobieranie danych historycznych z InfluxDB wymaga hardwareId
      final data = await _iotDeviceService.getDeviceTelemetry(widget.device.hardwareId);
      if (mounted) {
        setState(() {
          _telemetryData = data;
        });
      }
    } catch (e) {
      debugPrint("Nie udało się pobrać telemetrii: $e");
    }
  }

  Future<void> _checkAliveStatus({bool showSnackBar = true}) async {
    setState(() => _isCheckingStatus = true);
    try {
      // Weryfikacja statusu Keep-Alive w module IoT wymaga hardwareId
      final isAlive = await _iotDeviceService.checkIsAlive(widget.device.hardwareId);
      if (mounted) {
        setState(() {
          _isDeviceAlive = isAlive;
        });
        if (showSnackBar) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isAlive ? 'Urządzenie jest online przez WiFi.' : 'Brak odpowiedzi od urządzenia.'),
              backgroundColor: isAlive ? Colors.green : Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDeviceAlive = false;
          _errorMessage = 'Błąd sprawdzania statusu: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _isCheckingStatus = false);
    }
  }

  Future<void> _toggleBlock() async {
    if (_iotDevice == null) return;
    setState(() => _isActionLoading = true);
    try {
      final newBlockState = !_iotDevice!.isBlocked;
      // Zmiana blokady systemowej na poziomie Spring Security wymaga hardwareId
      await _iotDeviceService.toggleDeviceBlock(widget.device.hardwareId, newBlockState);
      await _checkBackendStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(newBlockState ? 'Zamek zablokowany.' : 'Zamek odblokowany.')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Nie udało się zmienić blokady: $e");
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _sendWifiCommand(String command) async {
    setState(() => _isActionLoading = true);
    try {
      // Wysyłanie polecenia sterującego przez brokera MQTT wymaga hardwareId
      await _iotDeviceService.sendCommand(widget.device.hardwareId, command);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Wysłano komendę: $command')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Nie udało się wysłać komendy: $e");
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _registerDevice() async {
    try {
      // Rejestracja nowego urządzenia w bazie chmurowej wymaga hardwareId
      final newDevice = await _iotDeviceService.addDevice(deviceId: widget.device.hardwareId, deviceName: widget.device.name);
      if (mounted) {
        setState(() {
          _iotDevice = newDevice;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Nie udało się zarejestrować urządzenia: $e");
    }
  }

  Future<void> _loadDeviceConfiguration() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Pobieranie aktywnego połączenia radiowego BLE wymaga adresu MAC
      final connection = _bleManager.getConnection(widget.device.id);
      if (connection == null) {
        setState(() {
          _deviceIdFromFf30 = "Brak połączenia";
          _errorMessage = "Urządzenie nie jest połączone. Połącz się, aby odczytać/zapisać ustawienia.";
          _isLoading = false;
        });
        return;
      }

      try {
        final deviceId = await connection.readDeviceId();
        if (mounted) setState(() => _deviceIdFromFf30 = deviceId);
      } catch (e) {
        debugPrint("Błąd odczytu FF30: $e");
        if (mounted) setState(() => _deviceIdFromFf30 = "Błąd odczytu");
      }

      try {
        final config = await connection.readConfigJson();
        if (config.containsKey('wifi')) {
          _wifiSsidController.text = config['wifi']['ssid'] ?? '';
        }
        if (config.containsKey('mqtt')) {
          _initialMqttBroker = config['mqtt']['broker'] ?? '';
          _initialMqttTopic = config['mqtt']['topic'] ?? '';
          _mqttBrokerController.text = _initialMqttBroker;
          _mqttTopicController.text = _initialMqttTopic;
        }
      } catch (e) {
        debugPrint("Błąd odczytu konfiguracji JSON z FF46: $e");
        _errorMessage = "Nie udało się odczytać pełnej konfiguracji z urządzenia.";
      }

    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Błąd komunikasi: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfiguration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      // Pobieranie aktywnego kanału zapisu BLE wymaga adresu MAC
      final connection = _bleManager.getConnection(widget.device.id);
      if (connection == null) throw Exception("Urządzenie nie jest połączone.");

      if (_wifiSsidController.text.isNotEmpty) {
        await connection.writeWifiCredentials(_wifiSsidController.text, _wifiPasswordController.text);
        await Future.delayed(const Duration(milliseconds: 200));
      }

      final newBroker = _mqttBrokerController.text;
      final newTopic = _mqttTopicController.text;

      if (newBroker != _initialMqttBroker || newTopic != _initialMqttTopic) {
        final brokerToSend = newBroker.isNotEmpty ? newBroker : _initialMqttBroker;
        final topicToSend = newTopic.isNotEmpty ? newTopic : _initialMqttTopic;

        await connection.writeMqttConfig(brokerToSend, topicToSend);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Konfiguracja zapisana!'), backgroundColor: Colors.green),
        );
        setState(() {
          _isEditing = false;
          _wifiPasswordController.clear();
          _initialMqttBroker = newBroker;
          _initialMqttTopic = newTopic;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Błąd zapisu: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _rebootDevice() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Potwierdź restart', style: TextStyle(color: Colors.white)),
        content: const Text('Czy na pewno chcesz zrestartować urządzenie?', style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Anuluj', style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restartuj', style: TextStyle(color: Colors.orange))),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isActionLoading = true);
      try {
        // Restart over-the-air przez niskopoziomową charakterystykę BLE wymaga adresu MAC
        final connection = _bleManager.getConnection(widget.device.id);
        if (connection == null) throw Exception("Urządzenie nie jest połączone.");
        await connection.rebootDevice();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Wysłano polecenie restartu.'), backgroundColor: Colors.orange),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) setState(() => _errorMessage = "Błąd podczas wysyłania polecenia restartu: $e");
      } finally {
        if (mounted) setState(() => _isActionLoading = false);
      }
    }
  }

  Future<void> _deleteDevice() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Potwierdź usunięcie', style: TextStyle(color: Colors.white)),
        content: Text('Czy na pewno chcesz usunąć urządzenie ${widget.device.name}?', style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Anuluj', style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Usuń', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isActionLoading = true);
      try {
        if (_iotDevice != null) {
          // Wyrejestrowanie z chmury Spring Boot wymaga hardwareId
          await _iotDeviceService.deleteDevice(widget.device.hardwareId);
        }
        // Czyszczenie lokalnej bazy SQLite oraz rozłączenie stosu radiowego wymaga adresu MAC
        await _bleManager.forgetDevice(widget.device.id);
        Navigator.of(context).pop();
      } catch (e) {
        if (mounted) setState(() => _errorMessage = "Błąd podczas usuwania urządzenia: $e");
      } finally {
        if (mounted) setState(() => _isActionLoading = false);
      }
    }
  }

  Future<void> _checkAndConnect() async {
    setState(() {
      _isActionLoading = true;
      _errorMessage = null;
    });
    try {
      // Wywołanie fizycznego połączenia ze sprzętem BLE wymaga adresu MAC
      await _bleManager.connectToDevice(widget.device.id);
      await _loadInitialData();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Błąd podczas łączenia z Bluetooth: $e";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isActionLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _wifiSsidController.dispose();
    _wifiPasswordController.dispose();
    _mqttBrokerController.dispose();
    _mqttTopicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Nasłuchiwanie zmian stanu menedżera BLE na podstawie adresu MAC
    final isBleConnected = _bleManager.isConnected(widget.device.id);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: CustomScrollView(
        controller: widget.scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  if (_errorMessage != null) _buildErrorMessage(),
                  if (_isLoading)
                    const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator(color: Color(0xFF00ADB5))))
                  else
                    _buildContent(isBleConnected),
                  if (_isCheckingStatus)
                    const Padding(
                      padding: EdgeInsets.only(top: 16.0),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.amber,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Sprawdzanie statusu urządzenia...',
                            style: TextStyle(color: Colors.amber, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Center(
          child: Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Icon(Icons.lock, color: Color(0xFF00ADB5), size: 48),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.device.name.isNotEmpty ? widget.device.name : 'Zamek', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('MAC: $_macAddress', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            _buildStatusBadge(
              'Bluetooth',
              _bleManager.isConnected(widget.device.id) ? 'Połączono' : 'Rozłączono',
              _bleManager.isConnected(widget.device.id) ? Colors.blue : Colors.grey,
            ),
            const SizedBox(width: 10),
            if (_isDeviceAlive) ...[
              _buildStatusBadge(
                'Wi-Fi',
                'Online',
                Colors.green,
              ),
              const SizedBox(width: 10),
            ],
            if (_iotDevice != null)
              _buildStatusBadge(
                'System',
                _iotDevice!.isBlocked ? 'ZABLOKOWANY' : 'Aktywny',
                _iotDevice!.isBlocked ? Colors.red : Colors.purple,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildContent(bool isBleConnected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_iotDevice != null) ...[
          _buildWifiControls(),
          const SizedBox(height: 32),
        ],

        if (!isBleConnected) _buildOfflineContent() else _buildOnlineContent(),
        const SizedBox(height: 32),

        _buildTelemetrySection(),
      ],
    );
  }

  Widget _buildWifiControls() {
    if (_iotDevice == null) return const SizedBox.shrink();

    if (!_isDeviceAlive) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Zdalne sterowanie (Wi-Fi)", style: TextStyle(color: Color(0xFF00ADB5), fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _isCheckingStatus ? null : _checkAliveStatus,
            icon: _isCheckingStatus ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.wifi_find),
            label: const Text('Połącz WiFi'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sterowanie przez backend pojawi się po potwierdzeniu statusu online.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Zdalne sterowanie (Wi-Fi)", style: TextStyle(color: Color(0xFF00ADB5), fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isActionLoading || _iotDevice!.isBlocked ? null : () => _sendWifiCommand("UNLOCK"),
                icon: const Icon(Icons.lock_open),
                label: const Text('Otwórz'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isActionLoading || _iotDevice!.isBlocked ? null : () => _sendWifiCommand("LOCK"),
                icon: const Icon(Icons.lock),
                label: const Text('Zamknij'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isCheckingStatus ? null : _checkAliveStatus,
                icon: _isCheckingStatus ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.wifi_tethering),
                label: const Text('Sprawdź status MQTT'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isActionLoading ? null : _toggleBlock,
                icon: Icon(_iotDevice!.isBlocked ? Icons.check_circle : Icons.block, color: _iotDevice!.isBlocked ? Colors.green : Colors.red),
                label: Text(_iotDevice!.isBlocked ? 'Odblokuj' : 'Zablokuj', style: TextStyle(color: _iotDevice!.isBlocked ? Colors.green : Colors.red)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTelemetrySection() {
    if (_iotDevice == null) return const SizedBox.shrink();

    if (_telemetryData.length < 2) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Brak wystarczających danych do wykresu.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTelemetryFilters(),
        const SizedBox(height: 16),
        _buildFilteredTelemetryChart(),
      ],
    );
  }

  Widget _buildTelemetryFilters() {
    final sources = _telemetryData.map((point) => point.normalizedSource).where((source) => source.isNotEmpty).toSet().toList()..sort();
    final actions = _telemetryData.map((point) => point.action).toSet().toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Filtry telemetrii", style: TextStyle(color: Color(0xFF00ADB5), fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTelemetryDropdown(
                label: 'Źródło',
                value: _selectedTelemetrySource,
                values: ['all', ...sources],
                onChanged: (value) => setState(() => _selectedTelemetrySource = value),
                labelBuilder: _sourceLabel,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTelemetryDropdown(
                label: 'Akcja',
                value: _selectedTelemetryAction,
                values: ['all', ...actions],
                onChanged: (value) => setState(() => _selectedTelemetryAction = value),
                labelBuilder: _actionLabel,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTelemetryDropdown({
    required String label,
    required String value,
    required List<String> values,
    required ValueChanged<String> onChanged,
    required String Function(String) labelBuilder,
  }) {
    return DropdownButtonFormField<String>(
      value: values.contains(value) ? value : 'all',
      dropdownColor: const Color(0xFF1E1E1E),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      items: values
          .map((item) => DropdownMenuItem(
        value: item,
        child: Text(labelBuilder(item), style: const TextStyle(color: Colors.white)),
      ))
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }

  Widget _buildFilteredTelemetryChart() {
    final filteredTelemetry = _filteredTelemetryData();
    if (filteredTelemetry.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text('Brak telemetrii dla wybranych filtrów.', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    final spots = filteredTelemetry.map((point) {
      return FlSpot(point.timestamp.millisecondsSinceEpoch.toDouble() / 60000, point.lockState.toDouble());
    }).toList();

    final minX = spots.map((s) => s.x).reduce((a, b) => a < b ? a : b);
    final maxX = spots.map((s) => s.x).reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Aktywność zamka", style: TextStyle(color: Color(0xFF00ADB5), fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) return const Text('Zam', style: TextStyle(fontSize: 10, color: Colors.grey));
                      if (value == 1) return const Text('Otw', style: TextStyle(fontSize: 10, color: Colors.grey));
                      return const Text('');
                    },
                    reservedSize: 30,
                  ),
                ),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: true, border: Border.all(color: Colors.white10)),
              minX: minX,
              maxX: minX == maxX ? maxX + 1 : maxX,
              minY: -0.5,
              maxY: 1.5,
              lineBarsData: _buildTelemetryBars(filteredTelemetry),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: const [
            _TelemetryLegendDot(color: Colors.green, label: 'Otwórz'),
            _TelemetryLegendDot(color: Colors.redAccent, label: 'Zamknij'),
            _TelemetryLegendDot(color: Colors.orangeAccent, label: 'PIN'),
            _TelemetryLegendDot(color: Colors.purpleAccent, label: 'Blokada'),
            _TelemetryLegendDot(color: Colors.grey, label: 'Inne'),
          ],
        ),
      ],
    );
  }

  List<DeviceTelemetryPoint> _filteredTelemetryData() {
    final filtered = _telemetryData.where((point) {
      final sourceMatches = _selectedTelemetrySource == 'all' || point.normalizedSource == _selectedTelemetrySource;
      final actionMatches = _selectedTelemetryAction == 'all' || point.action == _selectedTelemetryAction;
      return sourceMatches && actionMatches;
    }).toList();

    filtered.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return filtered;
  }

  List<LineChartBarData> _buildTelemetryBars(List<DeviceTelemetryPoint> points) {
    final Map<String, List<DeviceTelemetryPoint>> grouped = {};
    for (final point in points) {
      grouped.putIfAbsent(point.action, () => []).add(point);
    }

    return grouped.entries.map((entry) {
      final spots = entry.value
          .map((point) => FlSpot(point.timestamp.millisecondsSinceEpoch.toDouble() / 60000, point.lockState.toDouble()))
          .toList();

      return LineChartBarData(
        spots: spots,
        isCurved: false,
        color: _actionColor(entry.key),
        barWidth: 2,
        isStrokeCapRound: true,
        dotData: FlDotData(show: true),
        belowBarData: BarAreaData(show: false),
      );
    }).toList();
  }

  String _sourceLabel(String source) {
    if (source == 'all') return 'Wszystkie';
    if (source == 'bluetooth') return 'Bluetooth';
    if (source == 'wifi') return 'Wi-Fi';
    return source;
  }

  String _actionLabel(String action) {
    switch (action) {
      case 'all':
        return 'Wszystkie';
      case 'unlock':
        return 'Otwórz';
      case 'lock':
        return 'Zamknij';
      case 'pin':
        return 'PIN';
      case 'block':
        return 'Blokada';
      default:
        return 'Inne';
    }
  }

  Color _actionColor(String action) {
    switch (action) {
      case 'unlock':
        return Colors.green;
      case 'lock':
        return Colors.redAccent;
      case 'pin':
        return Colors.orangeAccent;
      case 'block':
        return Colors.purpleAccent;
      default:
        return Colors.grey;
    }
  }

  Widget _buildOfflineContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Opcje konfiguracji dostępne po połączeniu Bluetooth.", style: TextStyle(color: Colors.orange, fontSize: 14)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _isActionLoading ? null : _checkAndConnect,
          icon: _isActionLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.bluetooth_searching),
          label: const Text('Sprawdź status i połącz z Bluetooth'),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00ADB5)),
        ),
      ],
    );
  }

  Widget _buildOnlineContent() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Konfiguracja Wi-Fi', _isEditing, () => setState(() => _isEditing = !_isEditing)),
          _buildTextFormField(_wifiSsidController, 'SSID', enabled: _isEditing),
          const SizedBox(height: 16),
          _buildTextFormField(
            _wifiPasswordController,
            'Hasło (pozostaw puste, by nie zmieniać)',
            obscureText: !_isWifiPasswordVisible,
            enabled: _isEditing,
            suffixIcon: IconButton(
              icon: Icon(_isWifiPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
              onPressed: () => setState(() => _isWifiPasswordVisible = !_isWifiPasswordVisible),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Konfiguracja MQTT', _isEditing, () {}),
          _buildTextFormField(_mqttBrokerController, 'Adres brokera', enabled: _isEditing, validator: (v) => (v != null && v.length > 64) ? 'Maks. 64 znaki' : null),
          const SizedBox(height: 16),
          _buildTextFormField(_mqttTopicController, 'Temat (topic)', enabled: _isEditing, validator: (v) => (v != null && v.length > 64) ? 'Maks. 64 znaki' : null),
          const SizedBox(height: 32),
          if (_isEditing)
            ElevatedButton(
              onPressed: _isSaving ? null : _saveConfiguration,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00ADB5), minimumSize: const Size(double.infinity, 50)),
              child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Zapisz konfigurację'),
            ),
          const SizedBox(height: 40),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildTextFormField(TextEditingController controller, String label, {bool obscureText = false, bool enabled = true, Widget? suffixIcon, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      readOnly: !enabled,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: TextStyle(color: enabled ? Colors.white : Colors.grey),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: enabled ? Colors.white10 : Colors.black26,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00ADB5))),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent, width: 2)),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        TextButton.icon(
          onPressed: _isActionLoading ? null : _deleteDevice,
          icon: _isActionLoading && _iotDevice == null ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.delete_forever, color: Colors.redAccent),
          label: const Text('Usuń urządzenie', style: TextStyle(color: Colors.redAccent)),
        ),
        TextButton.icon(
          onPressed: _isActionLoading ? null : _rebootDevice,
          icon: _isActionLoading && _iotDevice != null ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.power_settings_new, color: Colors.orange),
          label: const Text('Restartuj', style: TextStyle(color: Colors.orange)),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String title, String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        children: [
          Text('$title: ', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          Text(status, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.redAccent.withOpacity(0.5))),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent),
          const SizedBox(width: 12),
          Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isEditing, VoidCallback onEditPressed) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(color: Color(0xFF00ADB5), fontSize: 18, fontWeight: FontWeight.bold)),
        IconButton(
          icon: Icon(isEditing ? Icons.done : Icons.edit, color: isEditing ? Colors.green : Colors.grey),
          onPressed: onEditPressed,
        ),
      ],
    );
  }
}

class _TelemetryLegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _TelemetryLegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}