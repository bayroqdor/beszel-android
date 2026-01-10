import 'package:flutter/material.dart';
import 'package:beszel_pro/services/pocketbase_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:beszel_pro/screens/pin_screen.dart';
import 'package:beszel_pro/services/pin_service.dart';
import 'package:pocketbase/pocketbase.dart';

class UserInfoScreen extends StatefulWidget {
  const UserInfoScreen({super.key});

  @override
  State<UserInfoScreen> createState() => _UserInfoScreenState();
}

class _UserInfoScreenState extends State<UserInfoScreen> {
  String _email = '';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  void _loadUser() {
    final model = PocketBaseService().pb.authStore.model;
    if (model is RecordModel) {
      _email = model.data['email'] ?? model.id;
    } else {
      // Fallback for AdminModel or other types
      try {
        _email = (model as dynamic)?.email ?? '';
      } catch (_) {}
    }
    setState(() {});
  }

  Future<void> _handlePinParams() async {
    final isSet = await PinService().isPinSet();
    if (!mounted) return;

    if (isSet) {
      // Verify old PIN first
      final verified = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const PinScreen(isSetup: false)),
      );

      if (verified == true) {
        if (!mounted) return;

        // Ask to Remove or Change
        final action = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('manage_pin'.tr()),
            content: Text('manage_pin_content'.tr()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'remove'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text('remove'.tr()),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'change'),
                child: Text('change'.tr()),
              ),
            ],
          ),
        );

        if (!mounted) return;

        if (action == 'remove') {
          await PinService().removePin();
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('pin_removed'.tr())));
          }
        } else if (action == 'change') {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PinScreen(isSetup: true)),
          );
        }
      }
    } else {
      // Set new PIN directly
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const PinScreen(isSetup: true)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('user_info'.tr())),
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
          ListTile(
            leading: const Icon(Icons.lock),
            title: Text('pin_code'.tr()),
            subtitle: Text('pin_manage_subtitle'.tr()),
            trailing: const Icon(Icons.chevron_right),
            onTap: _handlePinParams,
          ),
        ],
      ),
    );
  }
}
