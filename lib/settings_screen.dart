import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';
import 'home_page.dart';
import 'theme_notifier.dart';
import 'locale_notifier.dart';
import 'package:home237/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'terms_of_service_screen.dart';
import 'privacy_policy_screen.dart';
import 'widgets/language_toggle.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushNotifications = true;
  bool _emailMarketing = false;
  DateTime? _passwordLastChanged;

  @override
  void initState() {
    super.initState();
    _loadPasswordDate();
    _loadNotificationSettings();
  }

  Future<void> _loadNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pushNotifications = prefs.getBool('push_notifications') ?? true;
      _emailMarketing = prefs.getBool('email_marketing') ?? false;
    });
  }

  Future<void> _updateNotificationSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    setState(() {
      if (key == 'push_notifications') {
        _pushNotifications = value;
      } else if (key == 'email_marketing') {
        _emailMarketing = value;
      }
    });
  }

  Future<void> _loadPasswordDate() async {
    final userId = authService.userId;
    if (userId == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (doc.exists) {
        final ts = doc.data()?['passwordLastChanged'];
        if (ts is Timestamp) {
          setState(() => _passwordLastChanged = ts.toDate());
        }
      }
    } catch (_) {}
  }

  String _formatPasswordDate(DateTime date) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  void _showChangePasswordDialog() {
    final t = AppLocalizations.of(context);
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool isLoading = false;
    bool obscureCurrent = true;
    bool obscureNew = true;
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E2937) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.lock_outline, color: Color(0xFF3B82F6)),
              const SizedBox(width: 10),
              Text(t.get('change_password_title')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (errorMessage != null) ...[   
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13))),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: currentPassCtrl,
                obscureText: obscureCurrent,
                decoration: InputDecoration(
                  labelText: t.get('current_password'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newPassCtrl,
                obscureText: obscureNew,
                decoration: InputDecoration(
                  labelText: t.get('new_password'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.lock_reset),
                  suffixIcon: IconButton(
                    icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPassCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: t.get('confirm_new_password'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.lock_reset),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: Text(t.get('cancel')),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                if (currentPassCtrl.text.isEmpty) {
                  setDialogState(() => errorMessage = t.get('err_password_empty'));
                  return;
                }
                if (newPassCtrl.text.length < 6) {
                  setDialogState(() => errorMessage = t.get('password_too_short'));
                  return;
                }
                if (newPassCtrl.text != confirmPassCtrl.text) {
                  setDialogState(() => errorMessage = t.get('passwords_dont_match'));
                  return;
                }
                setDialogState(() { isLoading = true; errorMessage = null; });
                try {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null || user.email == null) throw Exception('Not signed in');
                  final credential = EmailAuthProvider.credential(
                    email: user.email!,
                    password: currentPassCtrl.text,
                  );
                  await user.reauthenticateWithCredential(credential);
                  await user.updatePassword(newPassCtrl.text);
                  final now = DateTime.now();
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(authService.userId)
                      .update({'passwordLastChanged': Timestamp.fromDate(now)});
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    setState(() => _passwordLastChanged = now);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('✅ ${t.get('password_updated')}'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } on FirebaseAuthException catch (e) {
                  String msg;
                  if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
                    msg = t.get('err_password_invalid') ?? 'Current password is incorrect.';
                  } else if (e.code == 'weak-password') {
                    msg = 'New password is too weak.';
                  } else {
                    msg = 'Error: ${e.message}';
                  }
                  setDialogState(() { errorMessage = msg; isLoading = false; });
                } catch (_) {
                  setDialogState(() { errorMessage = t.get('error'); isLoading = false; });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(t.get('confirm'), style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.get('settings')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: const [
          LanguageToggle(),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(t.get('account_settings')),
            _buildSettingsCard(children: [
              _buildSettingsTile(
                icon: Icons.person_outline,
                title: t.get('user_role'),
                subtitle: authService.userRole == UserRole.tenant
                    ? t.get('tenant')
                    : authService.userRole == UserRole.landlord
                    ? t.get('landlord')
                    : t.get('not_set') ?? 'Not Set',
                onTap: () {},
              ),
              _buildSettingsTile(
                icon: Icons.email_outlined,
                title: t.get('email'),
                subtitle: authService.userEmail ?? 'example@email.com',
                onTap: () {},
              ),
              _buildSettingsTile(
                icon: Icons.lock_outline,
                title: t.get('change_password'),
                subtitle: _passwordLastChanged != null
                    ? '${t.get('last_changed') ?? 'Last changed'}: ${_formatPasswordDate(_passwordLastChanged!)}'
                    : t.get('update_password_desc') ?? 'Update your account password',
                onTap: _showChangePasswordDialog,
              ),
            ]),

            _buildSectionHeader(t.get('admin_overview').toUpperCase()), // Placeholder for "APPEARANCE" if not in t
            _buildSettingsCard(children: [
              _buildSwitchTile(
                icon: Icons.dark_mode_outlined,
                title: t.get('dark_mode'),
                value: context.watch<ThemeNotifier>().isDarkMode,
                onChanged: (value) {
                  context.read<ThemeNotifier>().toggleTheme(value);
                },
              ),
            ]),

            _buildSectionHeader(t.get('language').toUpperCase()),
            _buildSettingsCard(children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: DropdownButton<Locale>(
                  isExpanded: true,
                  underline: const SizedBox(),
                  value: context.watch<LocaleNotifier>().locale,
                  items: const [
                    DropdownMenuItem(
                      value: Locale('en'),
                      child: Text('English'),
                    ),
                    DropdownMenuItem(
                      value: Locale('fr'),
                      child: Text('Français'),
                    ),
                  ],
                  onChanged: (locale) {
                    if (locale != null) {
                      context.read<LocaleNotifier>().setLocale(locale);
                    }
                  },
                ),
              ),
            ]),

            _buildSectionHeader(t.get('notifications')),
            _buildSettingsCard(children: [
              _buildSwitchTile(
                icon: Icons.notifications_outlined,
                title: t.get('push_notifications'),
                value: _pushNotifications,
                onChanged: (v) => _updateNotificationSetting('push_notifications', v),
              ),
              _buildDivider(),
              _buildSwitchTile(
                icon: Icons.alternate_email,
                title: t.get('email_marketing'),
                value: _emailMarketing,
                onChanged: (v) => _updateNotificationSetting('email_marketing', v),
              ),
            ]),

            _buildSectionHeader(t.get('legal')),
            _buildSettingsCard(children: [
              _buildSimpleTile(
                title: t.get('tos'), 
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const TermsOfServiceScreen()),
                  );
                }
              ),
              _buildDivider(),
              _buildSimpleTile(
                title: t.get('privacy_policy'), 
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()),
                  );
                }
              ),
            ]),

            Padding(
              padding: const EdgeInsets.all(16),
              child: InkWell(
                onTap: _showLogoutDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      t.get('logout'),
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Text('${t.get('version')} 1.0.0', style: const TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSettingsCard({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).cardColor,
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(title),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildSimpleTile({required String title, required VoidCallback onTap}) {
    return ListTile(
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1);
  }

  void _showLogoutDialog() {
    final t = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.get('logout')),
        content: Text(t.get('logout_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.get('cancel')),
          ),
          TextButton(
            onPressed: () async {
              // Sign out (clears Firebase session and SharedPreferences)
              await authService.signOut();

              if (!mounted) return;

              // Close dialog
              Navigator.pop(context);

              // Navigate to HOME PAGE (welcome screen) and clear all routes
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const HomePage()),
                    (_) => false,
              );
            },
            child: Text(t.get('logout'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}