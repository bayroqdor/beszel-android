import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beszel_pro/screens/setup_screen.dart';

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  Future<void> _selectLanguage(BuildContext context, Locale locale) async {
    await context.setLocale(locale);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_first_run', false);

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SetupScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('select_language'.tr())),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.language, size: 80, color: Colors.blueAccent),
              const SizedBox(height: 48),
              _LanguageOption(
                label: '🇺🇸 English',
                onPressed: () => _selectLanguage(context, const Locale('en')),
              ),
              const SizedBox(height: 16),
              _LanguageOption(
                label: '🇨🇳 简体中文',
                onPressed: () =>
                    _selectLanguage(context, const Locale('zh', 'CN')),
              ),
              const SizedBox(height: 16),
              _LanguageOption(
                label: '🇷🇺 Русский',
                onPressed: () => _selectLanguage(context, const Locale('ru')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _LanguageOption({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 20),
        textStyle: const TextStyle(fontSize: 18),
      ),
      child: Text(label),
    );
  }
}
