import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleConfigScreen extends StatefulWidget {
  const BleConfigScreen({super.key});

  @override
  State<BleConfigScreen> createState() => _BleConfigScreenState();
}

class _BleConfigScreenState extends State<BleConfigScreen> {
  static const Guid serviceUuid =
      Guid('12345678-1234-1234-1234-1234567890ab');
  static const Guid characteristicUuid =
      Guid('abcd1234-5678-90ab-cdef-1234567890ab');

  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _ipController = TextEditingController();

  final FlutterBluePlus _flutterBlue = FlutterBluePlus.instance;

  List<ScanResult> _foundDevices = [];
  BluetoothDevice? _selectedDevice;
  BluetoothCharacteristic? _configCharacteristic;

  bool _isScanning = false;
  bool _isConnecting = false;
  bool _isSending = false;
  String? _statusMessage;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passController.dispose();
    _ipController.dispose();
    _stopScan();
    super.dispose();
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _foundDevices.clear();
      _statusMessage = 'Buscando dispositivos ESP32_Config...';
      _errorMessage = null;
    });

    await _flutterBlue.stopScan();

    _flutterBlue.scanResults.listen((results) {
      final filtered = results
          .where((r) =>
              (r.device.platformName == 'ESP32_Config') ||
              (r.advertisementData.localName == 'ESP32_Config'))
          .toList();

      if (filtered.isNotEmpty) {
        setState(() {
          for (final r in filtered) {
            if (_foundDevices
                .where((e) => e.device.remoteId == r.device.remoteId)
                .isEmpty) {
              _foundDevices.add(r);
            }
          }
          _statusMessage =
              'Dispositivos encontrados: ${_foundDevices.length}';
        });
      }
    });

    await _flutterBlue.startScan(
      timeout: const Duration(seconds: 8),
    );

    setState(() {
      _isScanning = false;
      if (_foundDevices.isEmpty) {
        _statusMessage = 'No se encontró ningún ESP32_Config.';
      }
    });
  }

  Future<void> _stopScan() async {
    await _flutterBlue.stopScan();
    setState(() {
      _isScanning = false;
    });
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    setState(() {
      _isConnecting = true;
      _configCharacteristic = null;
      _statusMessage = 'Conectando a ${device.platformName}...';
      _errorMessage = null;
    });

    try {
      await device.connect(autoConnect: false);
    } catch (_) {}

    try {
      final services = await device.discoverServices();
      BluetoothCharacteristic? foundChar;

      for (final service in services) {
        if (service.uuid == serviceUuid) {
          for (final c in service.characteristics) {
            if (c.uuid == characteristicUuid) {
              foundChar = c;
              break;
            }
          }
        }
        if (foundChar != null) break;
      }

      if (foundChar == null) {
        throw Exception(
          'No se encontró la característica de configuración en el dispositivo.',
        );
      }

      setState(() {
        _selectedDevice = device;
        _configCharacteristic = foundChar;
        _statusMessage = 'Conectado a ${device.platformName}.';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al conectar: $e';
      });
      await device.disconnect();
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  Future<void> _sendConfig() async {
    if (_configCharacteristic == null || _selectedDevice == null) {
      setState(() {
        _errorMessage = 'No hay dispositivo conectado.';
      });
      return;
    }

    final ssid = _ssidController.text.trim();
    final pass = _passController.text.trim();
    final ip = _ipController.text.trim();

    if (ssid.isEmpty || ip.isEmpty) {
      setState(() {
        _errorMessage = 'SSID e IP son obligatorios.';
      });
      return;
    }

    final mqttUrl = 'tcp://$ip:1883';

    final Map<String, String> payload = {
      'ssid': ssid,
      'pass': pass,
      'mqtt_url': mqttUrl,
    };

    final jsonString = jsonEncode(payload);

    setState(() {
      _isSending = true;
      _statusMessage = 'Enviando configuración al ESP32...';
      _errorMessage = null;
    });

    try {
      await _configCharacteristic!.write(
        utf8.encode(jsonString),
        withoutResponse: true,
      );
      setState(() {
        _statusMessage =
            'Configuración enviada. El ESP32 debería reiniciarse y conectarse.';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al enviar configuración: $e';
      });
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  Widget _buildDeviceList() {
    if (_isScanning && _foundDevices.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_foundDevices.isEmpty) {
      return const Text('No hay dispositivos ESP32_Config encontrados.');
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _foundDevices.length,
      itemBuilder: (context, index) {
        final r = _foundDevices[index];
        final device = r.device;
        final isSelected =
            _selectedDevice?.remoteId == device.remoteId;

        return Card(
          child: ListTile(
            title: Text(
              device.platformName.isNotEmpty
                  ? device.platformName
                  : 'ESP32_Config',
            ),
            subtitle: Text(device.remoteId.str),
            trailing: isSelected
                ? const Icon(Icons.check, color: Colors.green)
                : const Icon(Icons.bluetooth),
            onTap: () => _connectToDevice(device),
          ),
        );
      },
    );
  }

  Widget _buildForm() {
    final isConnected = _configCharacteristic != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _ssidController,
          decoration: const InputDecoration(
            labelText: 'Nombre Wi‑Fi (SSID)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passController,
          decoration: const InputDecoration(
            labelText: 'Clave Wi‑Fi',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _ipController,
          decoration: const InputDecoration(
            labelText: 'IP del servidor Docker (MQTT)',
            hintText: 'Ej: 192.168.1.100',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: isConnected && !_isSending ? _sendConfig : null,
          icon: _isSending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.send),
          label: const Text('Enviar configuración al ESP32'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurar ESP32 por Bluetooth'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isScanning ? null : _startScan,
            tooltip: 'Reescanear',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '1. Buscar y seleccionar un dispositivo ESP32_Config',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _buildDeviceList(),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              '2. Introducir datos de configuración',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _buildForm(),
            const SizedBox(height: 16),
            if (_statusMessage != null)
              Text(
                _statusMessage!,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: Colors.blue),
              ),
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: Colors.red),
              ),
          ],
        ),
      ),
    );
  }
}

