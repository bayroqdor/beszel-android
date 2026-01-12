import 'package:beszel_pro/services/pocketbase_service.dart';
import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:beszel_pro/services/pin_service.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:beszel_pro/screens/appearance_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final pb = PocketBaseService().pb;

      await pb
          .collection('users')
          .authWithPassword(
            _emailController.text.trim(),
            _passwordController.text,
          );

      if (mounted) {
        // Check if PIN is set
        final isPinSet = await PinService().isPinSet();

        if (!mounted) return;

        if (!isPinSet) {
          // New flow: Login -> Appearance -> PinDecision
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AppearanceScreen()));
        } else {
          // Even if PIN is set, verify/show appearance?
          // Assuming first login on device means setup needed?
          // Or just skip for existing?
          // User wants "initialization".
          // If checking isPinSet here, it implies it's checking the ACCOUNT's pin status or DEVICE's?
          // PinService uses SharedPreferences, so it is DEVICE specific.
          // If local pin is set, user has used app before on this device.
          // So skipping appearance is fine.
          // BUT if user WANTS to see it?
          // Let's force it for newly logged in users (since they land on this screen).
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AppearanceScreen()));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Login failed. Please check your credentials.';
          if (e is ClientException) {
            _error = e.response['message']?.toString() ?? e.toString();
          } else {
            _error = e.toString();
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('login'.tr())),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.security, size: 80, color: Colors.blueAccent),
                const SizedBox(height: 32),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'email_username'.tr(),
                    prefixIcon: const Icon(Icons.person),
                    border: const OutlineInputBorder(),
                  ),
                  autocorrect: false,
                  textCapitalization: TextCapitalization.none,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'password'.tr(),
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('login'.tr()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
