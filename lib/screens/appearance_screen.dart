import 'package:beszel_pro/providers/app_provider.dart';
import 'package:beszel_pro/screens/dashboard_screen.dart';
import 'package:beszel_pro/screens/pin_decision_screen.dart';
import 'package:beszel_pro/services/pin_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  Future<void> _next(BuildContext context) async {
    final isPinSet = await PinService().isPinSet();
    if (!context.mounted) return;

    if (!isPinSet) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const PinDecisionScreen()),
        (route) => false,
      );
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('appearance'.tr())),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'choose_view_mode'.tr(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Expanded(
              child: Consumer<AppProvider>(
                builder: (context, provider, _) {
                  return Column(
                    children: [
                      _buildOption(
                        context,
                        title: 'view_simple'.tr(),
                        icon: Icons.view_agenda_outlined,
                        isSelected: !provider.isDetailed,
                        onTap: () => provider.setDetailedMode(false),
                      ),
                      const SizedBox(height: 16),
                      _buildOption(
                        context,
                        title: 'view_detailed'.tr(),
                        icon: Icons.view_list, // detailed icon
                        isSelected: provider.isDetailed,
                        onTap: () => provider.setDetailedMode(true),
                      ),
                    ],
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: () => _next(context),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text('continue'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primaryContainer : null,
          border: Border.all(
            color: isSelected ? colorScheme.primary : Colors.grey,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? colorScheme.primary : Colors.grey,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? colorScheme.onPrimaryContainer : null,
              ),
            ),
            const Spacer(),
            if (isSelected)
              Icon(Icons.check_circle, color: colorScheme.primary),
          ],
        ),
      ),
    );
  }
}
