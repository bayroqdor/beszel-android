import 'package:flutter/material.dart';
import 'package:beszel_pro/screens/pin_screen.dart';
import 'package:beszel_pro/screens/dashboard_screen.dart';
import 'package:easy_localization/easy_localization.dart';

class PinDecisionScreen extends StatelessWidget {
  const PinDecisionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('pin_security'.tr())),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 80,
                color: Colors.blueAccent,
              ),
              const SizedBox(height: 32),
              Text(
                'enable_pin'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'pin_description'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => PinScreen(
                        isSetup: true,
                        onSuccess: (ctx) {
                          Navigator.of(ctx).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const DashboardScreen(),
                            ),
                            (route) => false,
                          );
                        },
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: Text('setup_pin'.tr()),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const DashboardScreen()),
                    (route) => false,
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text('skip'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
