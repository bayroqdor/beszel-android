import 'package:flutter/material.dart';
import 'package:beszel_pro/services/pocketbase_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:beszel_pro/screens/pin_screen.dart';
import 'package:beszel_pro/services/pin_service.dart';
import 'package:beszel_pro/services/biometric_service.dart';
import 'package:pocketbase/pocketbase.dart';

class UserInfoScreen extends StatefulWidget {
  const UserInfoScreen({super.key});

  @override
  State<UserInfoScreen> createState() => _UserInfoScreenState();
}

class _UserInfoScreenState extends State<UserInfoScreen> {
  String _email = '';
  bool _isPinSet = false;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;

  final BiometricService _biometricService = BiometricService();

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadSettings();
  }

  void _loadUser() {
    final model = PocketBaseService().pb.authStore.model;
    if (model is RecordModel) {
      _email = model.data['email'] ?? model.id;
    } else {
      try {
        _email = (model as dynamic)?.email ?? '';
      } catch (_) {}
    }
    setState(() {});
  }

  Future<void> _loadSettings() async {
    final isPinSet = await PinService().isPinSet();
    final biometricAvailable = await _biometricService.isBiometricAvailable();
    final biometricEnabled = await _biometricService.isBiometricEnabled();

    if (mounted) {
      setState(() {
        _isPinSet = isPinSet;
        _biometricAvailable = biometricAvailable;
        _biometricEnabled = biometricEnabled;
      });
    }
  }

  Future<void> _handlePinParams() async {
    final isSet = await PinService().isPinSet();
    if (!mounted) return;

    if (isSet) {
      final verified = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const PinScreen(isSetup: false)),
      );

      if (verified == true) {
        if (!mounted) return;

        final action = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(tr('manage_pin')),
            content: Text(tr('manage_pin_content')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'remove'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text(tr('remove')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'change'),
                child: Text(tr('change')),
              ),
            ],
          ),
        );

        if (!mounted) return;

        if (action == 'remove') {
          await PinService().removePin();
          // Also disable biometric when removing PIN
          await _biometricService.setBiometricEnabled(false);
          await _loadSettings();
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(tr('pin_removed'))));
          }
        } else if (action == 'change') {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PinScreen(isSetup: true)),
          );
          await _loadSettings();
        }
      }
    } else {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const PinScreen(isSetup: true)));
      await _loadSettings();
    }
  }

  Future<void> _handleBiometricToggle(bool value) async {
    if (value) {
      // Show loading state
      setState(() => _biometricEnabled = true);

      // Verify fingerprint before enabling
      final success = await _biometricService.authenticate(
        reason: tr('authenticate_fingerprint'),
      );

      if (success) {
        await _biometricService.setBiometricEnabled(true);
        // Already set to true above
      } else {
        // Auth failed or cancelled - revert toggle
        setState(() => _biometricEnabled = false);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(tr('biometric_auth_failed'))));
        }
      }
    } else {
      await _biometricService.setBiometricEnabled(false);
      setState(() => _biometricEnabled = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('user_info'))),
      body: ListView(
        children: [
          const SizedBox(height: 20),
          const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 40)),
          const SizedBox(height: 16),
          Center(
            child: Text(_email, style: Theme.of(context).textTheme.titleLarge),
          ),
          const SizedBox(height: 32),
          const Divider(),
          // PIN Code
          ListTile(
            leading: const Icon(Icons.lock),
            title: Text(tr('pin_code')),
            subtitle: Text(tr('pin_manage_subtitle')),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isPinSet)
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: _handlePinParams,
          ),
          // Biometric (only show if PIN is set and biometric is available)
          if (_isPinSet && _biometricAvailable)
            ListTile(
              leading: const Icon(Icons.fingerprint),
              title: Text(tr('biometric_auth')),
              subtitle: Text(tr('biometric_description')),
              trailing: Switch(
                value: _biometricEnabled,
                onChanged: _handleBiometricToggle,
              ),
            ),
        ],
      ),
    );
  }
}
