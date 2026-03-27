import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverIpController = TextEditingController();
  final _mqttBrokerIpController = TextEditingController();
  final _mqttPortController = TextEditingController(text: '1883');
  final _mqttCaController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _mqttUsernameController = TextEditingController();
  final _mqttPasswordController = TextEditingController();
  bool _mqttSecure = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final auth = context.read<AuthProvider>();
    if (auth.serverIp != null && _serverIpController.text.isEmpty) {
      _serverIpController.text = auth.serverIp!;
    }
  }

  @override
  void dispose() {
    _serverIpController.dispose();
    _mqttBrokerIpController.dispose();
    _mqttPortController.dispose();
    _mqttCaController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _mqttUsernameController.dispose();
    _mqttPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final isFirstSetup = auth.isFirstSetup;
        final error = auth.consumeError();
        if (error != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error)),
            );
          });
        }

        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isFirstSetup ? 'Primer inicio' : 'Login',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isFirstSetup
                                  ? 'Configura el sistema y crea el usuario inicial.'
                                  : 'Conéctate al backend existente.',
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _serverIpController,
                              decoration: const InputDecoration(
                                labelText: 'IP del backend',
                                hintText: '192.168.0.22',
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Introduce la IP del backend';
                                }
                                return null;
                              },
                            ),
                            if (isFirstSetup) ...[
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _mqttBrokerIpController,
                                decoration: const InputDecoration(
                                  labelText: 'IP del broker MQTT',
                                  hintText: '192.168.0.30',
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Introduce la IP del broker MQTT';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('MQTT seguro (TLS)'),
                                value: _mqttSecure,
                                onChanged: (value) {
                                  setState(() {
                                    _mqttSecure = value;
                                    _mqttPortController.text = value ? '8883' : '1883';
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _mqttPortController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Puerto MQTT',
                                ),
                                validator: (value) {
                                  if (!isFirstSetup) {
                                    return null;
                                  }
                                  final parsed = int.tryParse(value ?? '');
                                  if (parsed == null || parsed <= 0 || parsed > 65535) {
                                    return 'Introduce un puerto MQTT válido';
                                  }
                                  return null;
                                },
                              ),
                            ],
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _usernameController,
                              decoration: const InputDecoration(
                                labelText: 'Username',
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Introduce el username';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Password',
                              ),
                              validator: (value) {
                                if (value == null || value.length < 6) {
                                  return 'La contraseña debe tener al menos 6 caracteres';
                                }
                                return null;
                              },
                            ),
                            if (isFirstSetup) ...[
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _mqttUsernameController,
                                decoration: const InputDecoration(
                                  labelText: 'Usuario MQTT',
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _mqttPasswordController,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  labelText: 'Password MQTT',
                                ),
                              ),
                              if (_mqttSecure) ...[
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _mqttCaController,
                                  minLines: 5,
                                  maxLines: 8,
                                  decoration: const InputDecoration(
                                    labelText: 'CA del broker MQTT',
                                    hintText: '-----BEGIN CERTIFICATE-----',
                                  ),
                                ),
                              ],
                            ],
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: auth.isLoading ? null : _submit,
                                child: auth.isLoading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : Text(isFirstSetup ? 'Configurar y entrar' : 'Entrar'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      await context.read<AuthProvider>().submitCredentials(
            serverIp: _serverIpController.text.trim(),
            username: _usernameController.text.trim(),
            password: _passwordController.text,
            mqttBrokerIp: _mqttBrokerIpController.text.trim(),
            mqttPort: int.tryParse(_mqttPortController.text.trim()) ?? (_mqttSecure ? 8883 : 1883),
            mqttSecure: _mqttSecure,
            mqttCa: _mqttCaController.text.trim(),
            mqttUsername: _mqttUsernameController.text.trim(),
            mqttPassword: _mqttPasswordController.text,
          );
    } catch (_) {}
  }
}
