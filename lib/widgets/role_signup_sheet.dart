import 'package:flutter/material.dart';
import '../auth_service.dart';
import '../signin_screen.dart';

/// Bottom sheet shown when a guest (viewer) tries a gated action — saving a
/// property, contacting an agent, or booking a tour. Instead of a generic
/// sign-in wall, it asks which kind of account they want, mirroring the
/// welcome dialog, and routes them to sign-in/sign-up with that role primed.
///
/// [action] finishes the sentence "…to <action>", e.g. 'save this property'.
void showRoleSignupSheet(BuildContext context, {String action = 'continue'}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

      void goTo(UserRole role) {
        Navigator.pop(ctx);
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => SignInScreen(preselectedRole: role)),
        );
      }

      Widget option({
        required IconData icon,
        required Color accent,
        required String title,
        required String subtitle,
        required VoidCallback onTap,
      }) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: accent, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(subtitle,
                            style: TextStyle(fontSize: 12, color: subColor)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: isDark
                          ? const Color(0xFF475569)
                          : const Color(0xFFCBD5E1)),
                ],
              ),
            ),
          ),
        );
      }

      return Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text('Create an account to $action',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B))),
            const SizedBox(height: 8),
            Text('It takes less than a minute. How would you like to join?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: subColor, height: 1.5)),
            const SizedBox(height: 22),
            option(
              icon: Icons.house_rounded,
              accent: const Color(0xFF10B981),
              title: 'I\'m looking for a home',
              subtitle: 'Save favourites, chat with agents and book visits',
              onTap: () => goTo(UserRole.tenant),
            ),
            const SizedBox(height: 12),
            option(
              icon: Icons.badge_rounded,
              accent: const Color(0xFF8B5CF6),
              title: 'I\'m a property agent',
              subtitle: 'List and manage properties, reach serious clients',
              onTap: () => goTo(UserRole.landlord),
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SignInScreen()));
              },
              child: const Text('Already have an account? Sign in'),
            ),
          ],
        ),
      );
    },
  );
}
