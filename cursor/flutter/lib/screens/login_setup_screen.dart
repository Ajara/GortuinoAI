import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'login_page.dart';

class LoginSetupScreen extends StatefulWidget {
  const LoginSetupScreen({super.key});

  @override
  State<LoginSetupScreen> createState() => _LoginSetupScreenState();
}

class _LoginSetupScreenState extends State<LoginSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  final _ipController = TextEditingController();

  bool _isLoading = false;
  bool _isFirstSetup = false;

  @override
  void initState() {
    super.initState();
    _detectFirstSetup();
  }

  Future<void> _detectFirstSetup() async {
    final auth = context.read<AuthProvider>();
    setState(() {
      // Si nunca se ha marcado setupDone, mostramos pantalla de setup
      _isFirstSetup = !auth.setupDone;
    });
  }

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final username = _userController.text.trim();
    final password = _passController.text.trim();
    final ip = _ipController.text.trim();

    setState(() => _isLoading = true);

    try {
      // Esta pantalla se dedica al SETUP inicial
      await auth.setup(
        username: username,
        password: password,
        serverIp: ip,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Setup completado. Ahora inicia sesión.'),
        ),
      );

      // Ir directamente a la pantalla de login
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Tamavans IoT',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isFirstSetup
                        ? 'Configuración inicial del sistema'
                        : 'Setup ya realizado',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _ipController,
                          decoration: const InputDecoration(
                            labelText: 'IP del servidor',
                            hintText: 'Ej: 192.168.1.100:8080 o solo IP',
                          ),
                          keyboardType: TextInputType.url,
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Requerido' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _userController,
                          decoration: const InputDecoration(
                            labelText: 'Usuario',
                          ),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Requerido' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passController,
                          decoration: const InputDecoration(
                            labelText: 'Contraseña',
                          ),
                          obscureText: true,
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Requerido' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: isDark
                          ? Theme.of(context).colorScheme.primary
                          : Colors.blueGrey,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Configurar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

