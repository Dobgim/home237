import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../locale_notifier.dart';

class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final localeNotifier = Provider.of<LocaleNotifier>(context);
    final isEn = localeNotifier.locale.languageCode == 'en';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () {
        localeNotifier.setLocale(isEn ? const Locale('fr') : const Locale('en'));
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF3B82F6).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language_rounded, size: 14, color: Color(0xFF3B82F6)),
            const SizedBox(width: 4),
            Text(
              isEn ? 'EN' : 'FR', 
              style: const TextStyle(
                fontSize: 11, 
                fontWeight: FontWeight.bold, 
                color: Color(0xFF3B82F6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
