import 'package:flutter/material.dart';
import '../../core/config/connection_config.dart';
import '../../core/services/connection_config_service.dart';
import '../widgets/custom_button.dart';

class ConnectionConfigScreen extends StatefulWidget {
  const ConnectionConfigScreen({super.key});

  @override
  State<ConnectionConfigScreen> createState() => _ConnectionConfigScreenState();
}

class _ConnectionConfigScreenState extends State<ConnectionConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _configService = ConnectionConfigService.instance;

  late HttpProtocol _selectedProtocol;
  late TextEditingController _hostController;
  late TextEditingController _identityPortController;
  late TextEditingController _iotPortController;

  @override
  void initState() {
    super.initState();
    final currentConfig = _configService.config;
    _selectedProtocol = currentConfig.protocol;
    _hostController = TextEditingController(text: currentConfig.host);
    _identityPortController = TextEditingController(text: currentConfig.identityPort.toString());
    _iotPortController = TextEditingController(text: currentConfig.iotPort.toString());
  }

  @override
  void dispose() {
    _hostController.dispose();
    _identityPortController.dispose();
    _iotPortController.dispose();
    super.dispose();
  }

  void _saveConfiguration() {
    if (_formKey.currentState!.validate()) {
      final newConfig = ConnectionConfig(
        protocol: _selectedProtocol,
        host: _hostController.text.trim(),
        identityPort: int.parse(_identityPortController.text.trim()),
        iotPort: int.parse(_iotPortController.text.trim()),
      );

      _configService.updateConfig(newConfig);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Konfiguracja sieciowa została pomyślnie zaktualizowana!'),
          backgroundColor: Color(0xFF00ADB5),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161616),
        title: const Text(
          'Konfiguracja API',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(color: Color(0xFF2C2C2E), height: 1),
        ),
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Parametry Połączenia',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Skonfiguruj adresy sieciowe dla modułu Identity (Firebase) oraz IoT (MQTT Scanner).',
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
                  ),
                  const SizedBox(height: 32),

                  Theme(
                    data: Theme.of(context).copyWith(canvasColor: const Color(0xFF1E1E1E)),
                    child: DropdownButtonFormField<HttpProtocol>(
                      value: _selectedProtocol,
                      dropdownColor: const Color(0xFF1E1E1E),
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: _buildInputDecoration('Protokół sieciowy'),
                      items: HttpProtocol.values.map((protocol) {
                        return DropdownMenuItem(
                          value: protocol,
                          child: Text(protocol.name.toUpperCase(), style: const TextStyle(color: Colors.white)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedProtocol = value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _hostController,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: _buildInputDecoration('Host (IP lub domena)').copyWith(
                      hintText: 'np. 192.168.1.50 lub localhost',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Pole host nie może być puste';
                      }
                      if (value.contains('://')) {
                        return 'Wpisz sam host, bez http:// lub https://';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _identityPortController,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    keyboardType: TextInputType.number,
                    decoration: _buildInputDecoration('Port modułu Identity').copyWith(
                      hintText: 'np. 12100',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    ),
                    validator: (value) => _validatePort(value, 'Identity'),
                  ),
                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _iotPortController,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    keyboardType: TextInputType.number,
                    decoration: _buildInputDecoration('Port modułu IoT').copyWith(
                      hintText: 'np. 12200',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    ),
                    validator: (value) => _validatePort(value, 'IoT'),
                  ),
                  const SizedBox(height: 40),

                  CustomButton(
                    text: 'Zapisz Konfigurację',
                    icon: Icons.save_rounded,
                    isFullWidth: true,
                    onPressed: _saveConfiguration,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
      floatingLabelStyle: const TextStyle(color: Color(0xFF00ADB5)),
      filled: true,
      fillColor: const Color(0xFF1E1E1E),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      errorStyle: const TextStyle(color: Color(0xFFFF453A)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2C2C2E)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF00ADB5), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF453A)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF453A), width: 1.5),
      ),
    );
  }

  String? _validatePort(String? value, String moduleName) {
    if (value == null || value.trim().isEmpty) {
      return 'Port dla modułu $moduleName nie może być pusty';
    }
    final port = int.tryParse(value.trim());
    if (port == null || port < 1 || port > 65535) {
      return 'Wprowadź poprawny port (1 - 65535)';
    }
    return null;
  }
}