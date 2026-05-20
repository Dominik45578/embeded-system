import 'package:flutter/material.dart';
import '../../../core/model/device.dart';
import '../../../core/services/ble/ble_device_manger.dart';

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

  final BleDeviceManager _bleManager = BleDeviceManager();

  String _deviceIdFromFf30 = "Ładowanie...";
  String _macAddress = "Brak (offline)";
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _macAddress = widget.device.id;
    _loadDeviceConfiguration();
  }

  Future<void> _loadDeviceConfiguration() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (!_bleManager.isConnected(widget.device.id)) {
        setState(() {
          _deviceIdFromFf30 = "Brak połączenia";
          _errorMessage = "Urządzenie nie jest połączone. Połącz się, aby odczytać/zapisać ustawienia.";
          _isLoading = false;
        });
        return;
      }

      final connection = _bleManager.getConnection(widget.device.id);
      if (connection == null) throw Exception("Nie można uzyskać instancji połączenia.");

      try {
        final deviceId = await connection.readDeviceId();
        if (mounted) setState(() => _deviceIdFromFf30 = deviceId);
      } catch (e) {
        debugPrint("Błąd odczytu FF30: $e");
        if (mounted) setState(() => _deviceIdFromFf30 = "Błąd odczytu");
      }

      try {
        final wifiSsid = await connection.readWifiSsid();
        _wifiSsidController.text = wifiSsid;
      } catch (e) {
        debugPrint("Błąd odczytu WiFi SSID: $e");
      }

      try {
        final mqttConfig = await connection.readMqttConfig();
        _mqttBrokerController.text = mqttConfig['broker'] ?? '';
        _mqttTopicController.text = mqttConfig['topic'] ?? '';
      } catch (e) {
        debugPrint("Błąd odczytu konfiguracji MQTT: $e");
      }

    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Błąd komunikacji: $e");
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
      final connection = _bleManager.getConnection(widget.device.id);
      if (connection == null) throw Exception("Urządzenie nie jest połączone.");

      if (_wifiSsidController.text.isNotEmpty) {
        await connection.writeWifiCredentials(_wifiSsidController.text, _wifiPasswordController.text);
      }

      if (_mqttBrokerController.text.isNotEmpty && _mqttTopicController.text.isNotEmpty) {
        await connection.writeMqttConfig(_mqttBrokerController.text, _mqttTopicController.text);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Konfiguracja zapisana!'), backgroundColor: Colors.green),
        );
        setState(() => _isEditing = false);
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Błąd zapisu: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
      await _bleManager.forgetDevice(widget.device.id);
      Navigator.of(context).pop(); // Close the sheet
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
                            Text(widget.device.name.isNotEmpty ? widget.device.name : 'Zamek BLE', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('ID z FF30: $_deviceIdFromFf30', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                            Text('MAC: $_macAddress', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (_errorMessage != null)
                    Container(
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
                    ),
                  if (_isLoading)
                    const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator(color: Color(0xFF00ADB5))))
                  else
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle('Konfiguracja Wi-Fi', _isEditing, () => setState(() => _isEditing = !_isEditing)),
                          _buildTextFormField(_wifiSsidController, 'SSID', enabled: _isEditing),
                          const SizedBox(height: 16),
                          _buildTextFormField(_wifiPasswordController, 'Hasło', obscureText: true, enabled: _isEditing),
                          const SizedBox(height: 24),
                          _buildSectionTitle('Konfiguracja MQTT', _isEditing, () => setState(() => _isEditing = !_isEditing)),
                          _buildTextFormField(_mqttBrokerController, 'Adres brokera', enabled: _isEditing),
                          const SizedBox(height: 16),
                          _buildTextFormField(_mqttTopicController, 'Temat (topic)', enabled: _isEditing),
                          const SizedBox(height: 32),
                          if (_isEditing)
                            ElevatedButton(
                              onPressed: _isSaving || !_bleManager.isConnected(widget.device.id) ? null : _saveConfiguration,
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00ADB5), disabledBackgroundColor: Colors.grey[800], minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              child: _isSaving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Zapisz konfigurację', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          const SizedBox(height: 40),
                          Center(
                            child: TextButton.icon(
                              onPressed: _deleteDevice,
                              icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                              label: const Text('Usuń urządzenie', style: TextStyle(color: Colors.redAccent, fontSize: 15)),
                            ),
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

  Widget _buildTextFormField(TextEditingController controller, String label, {bool obscureText = false, bool enabled = true}) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      readOnly: !enabled,
      style: TextStyle(color: enabled ? Colors.white : Colors.grey),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: enabled ? Colors.white10 : Colors.black26,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00ADB5))),
      ),
    );
  }
}