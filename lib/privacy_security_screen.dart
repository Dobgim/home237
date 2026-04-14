import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';
import 'email_service.dart';
import 'home_page.dart';
import 'package:home237/app_localizations.dart';

class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({super.key});

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  bool _profileVisible = true;
  bool _showContactInfo = false;
  bool _twoFactorEnabled = false;
  bool _isSaving = false;
  DateTime? _passwordLastChanged;

  @override
  void initState() {
    super.initState();
    _loadPrivacySettings();
  }

  Future<void> _loadPrivacySettings() async {
    final userId = authService.userId;
    if (userId == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _profileVisible = data['profileVisible'] ?? true;
          _showContactInfo = data['showContactInfo'] ?? false;
          _twoFactorEnabled = data['twoFactorEnabled'] ?? false;
          final ts = data['passwordLastChanged'];
          if (ts is Timestamp) {
            _passwordLastChanged = ts.toDate();
          }
        });
      }
    } catch (_) {}
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _saveSettings() async {
    final userId = authService.userId;
    if (userId == null) return;
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'profileVisible': _profileVisible,
        'showContactInfo': _showContactInfo,
        'twoFactorEnabled': _twoFactorEnabled,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Privacy settings saved!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: $e')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showChangePasswordDialog() {
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool isLoading = false;
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    String? errorMessage;

    final t = AppLocalizations.of(context);
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: currentPassCtrl,
                obscureText: obscureCurrent,
                decoration: InputDecoration(
                  labelText: 'Current Password',
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
                  labelText: 'New Password',
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
                obscureText: obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.lock_reset),
                  suffixIcon: IconButton(
                    icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      // Validate inputs
                      if (currentPassCtrl.text.isEmpty) {
                        setDialogState(() => errorMessage = 'Please enter your current password.');
                        return;
                      }
                      if (newPassCtrl.text.length < 6) {
                        setDialogState(() => errorMessage = 'New password must be at least 6 characters.');
                        return;
                      }
                      if (newPassCtrl.text != confirmPassCtrl.text) {
                        setDialogState(() => errorMessage = 'New passwords do not match.');
                        return;
                      }

                      setDialogState(() {
                        isLoading = true;
                        errorMessage = null;
                      });

                      try {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user == null || user.email == null) throw Exception('Not signed in');

                        // Re-authenticate with current password first
                        final credential = EmailAuthProvider.credential(
                          email: user.email!,
                          password: currentPassCtrl.text,
                        );
                        await user.reauthenticateWithCredential(credential);

                        // Update password
                        await user.updatePassword(newPassCtrl.text);

                        // Save timestamp to Firestore
                        final now = DateTime.now();
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(authService.userId)
                            .update({'passwordLastChanged': Timestamp.fromDate(now)});

                        if (ctx.mounted) Navigator.pop(ctx);

                        if (mounted) {
                          setState(() => _passwordLastChanged = now);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ Password changed successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } on FirebaseAuthException catch (e) {
                        String msg;
                        if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
                          msg = 'Current password is incorrect. Please try again.';
                        } else if (e.code == 'weak-password') {
                          msg = 'New password is too weak. Use at least 6 characters.';
                        } else if (e.code == 'too-many-requests') {
                          msg = 'Too many attempts. Please try again later.';
                        } else {
                          msg = 'Error: ${e.message}';
                        }
                        setDialogState(() {
                          errorMessage = msg;
                          isLoading = false;
                        });
                      } catch (e) {
                        setDialogState(() {
                          errorMessage = 'Something went wrong. Please try again.';
                          isLoading = false;
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Update', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  /// 2FA: generates a 6-digit code, displays dialog for user to enter it
  void _handle2FAToggle(bool enable) {
    if (enable) {
      _show2FASetupDialog();
    } else {
      _show2FADisableDialog();
    }
  }

  void _show2FASetupDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Generate a random 6-digit code
    final code = (100000 + Random().nextInt(900000)).toString();
    final codeCtrl = TextEditingController();
    bool isVerifying = false;
    bool codeSent = false;
    String? errorMsg;
    final userEmail = authService.userEmail ?? 'your email';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E2937) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.security, color: Color(0xFF3B82F6)),
              SizedBox(width: 10),
              Text('Enable 2FA'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!codeSent) ...[
                Text(
                  'A 6-digit verification code will be sent to:\n$userEmail',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Two-Factor Authentication adds an extra layer of security to protect your account.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                    height: 1.5,
                  ),
                ),
              ] else ...[
                if (errorMsg != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorMsg!,
                            style: const TextStyle(color: Colors.red, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  '📧 Code sent to $userEmail\nEnter the 6-digit code below:',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: codeCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
                  decoration: InputDecoration(
                    hintText: '000000',
                    counterText: '',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: isVerifying ? null : () async {
                      setDialogState(() { isVerifying = true; errorMsg = null; });
                      
                      final success = await EmailService.send2FACode(userEmail, code);
                      
                      if (!success) {
                        setDialogState(() {
                          errorMsg = "Failed to resend. Please check your EmailService credentials in the code.";
                        });
                      }
                      setDialogState(() => isVerifying = false);
                    },
                    child: const Text('Resend Code', style: TextStyle(color: Color(0xFF3B82F6))),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isVerifying
                  ? null
                  : () async {
                      if (!codeSent) {
                        // Send Code phase
                        setDialogState(() { isVerifying = true; errorMsg = null; });
                        
                        final success = await EmailService.send2FACode(userEmail, code);
                        
                        if (success) {
                          setDialogState(() { codeSent = true; isVerifying = false; });
                        } else {
                          setDialogState(() { 
                            errorMsg = "Setup incomplete. You need to open lib/email_service.dart and enter your Gmail address.";
                            isVerifying = false; 
                          });
                        }
                      } else {
                        // Verify phase
                        if (codeCtrl.text.length != 6) {
                          setDialogState(() => errorMsg = 'Please enter the 6-digit code.');
                          return;
                        }
                        if (codeCtrl.text != code) {
                          setDialogState(() => errorMsg = 'Incorrect code. Please check and try again.');
                          return;
                        }
                        // Code matches — enable 2FA
                        setDialogState(() => isVerifying = true);
                        try {
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(authService.userId)
                              .update({'twoFactorEnabled': true});
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            setState(() => _twoFactorEnabled = true);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('✅ Two-Factor Authentication enabled!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (_) {
                          setDialogState(() {
                            errorMsg = 'Could not save settings. Please try again.';
                            isVerifying = false;
                          });
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isVerifying
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      codeSent ? 'Verify' : 'Send Code',
                      style: const TextStyle(color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog() {
    final passwordCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool isLoading = false;
    bool obscurePassword = true;
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
              const Icon(Icons.warning_amber_rounded, color: Colors.red),
              const SizedBox(width: 10),
              Text(AppLocalizations.of(context).get('delete_account')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This action is permanent and will delete all your data, including properties and favorites.',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 20),
              if (errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const Text(
                'Enter your password to confirm:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: passwordCtrl,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  hintText: 'Password',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (passwordCtrl.text.isEmpty) {
                        setDialogState(() => errorMessage = 'Please enter your password.');
                        return;
                      }

                      setDialogState(() {
                        isLoading = true;
                        errorMessage = null;
                      });

                      try {
                        await authService.deleteAccount(passwordCtrl.text);
                        
                        if (ctx.mounted) Navigator.pop(ctx);
                        
                        if (mounted) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const HomePage()),
                            (route) => false,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Account permanently deleted.'),
                              backgroundColor: Colors.black87,
                            ),
                          );
                        }
                      } catch (e) {
                        String msg = 'Failed to delete account. Please try again.';
                        if (e.toString().contains('wrong-password') || e.toString().contains('invalid-credential')) {
                          msg = 'Incorrect password. Please try again.';
                        }
                        setDialogState(() {
                          errorMessage = msg;
                          isLoading = false;
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Delete Permanently', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _show2FADisableDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E2937) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Disable 2FA'),
        content: const Text(
          'Are you sure you want to disable Two-Factor Authentication? This will make your account less secure.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Enabled'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(authService.userId)
                    .update({'twoFactorEnabled': false});
                if (mounted) {
                  setState(() => _twoFactorEnabled = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Two-Factor Authentication disabled.'),
                    ),
                  );
                }
              } catch (_) {}
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Disable', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Privacy & Security'),
        elevation: 0,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _saveSettings,
              child: const Text('Save', style: TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // PRIVACY SECTION
            _sectionHeader('PRIVACY', isDark),
            _card(isDark, children: [
              SwitchListTile(
                secondary: Icon(Icons.person_outline, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                title: const Text('Public Profile', style: TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text(
                  'Allow other users to see your profile',
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey[600]),
                ),
                value: _profileVisible,
                activeColor: const Color(0xFF3B82F6),
                onChanged: (v) => setState(() => _profileVisible = v),
              ),
              Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey[200]),
              SwitchListTile(
                secondary: Icon(Icons.contact_phone_outlined, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                title: const Text('Show Contact Info', style: TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text(
                  'Let landlords see your phone number',
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey[600]),
                ),
                value: _showContactInfo,
                activeColor: const Color(0xFF3B82F6),
                onChanged: (v) => setState(() => _showContactInfo = v),
              ),
            ]),

            const SizedBox(height: 24),

            // SECURITY SECTION
            _sectionHeader('SECURITY', isDark),
            _card(isDark, children: [
              ListTile(
                leading: Icon(Icons.lock_outline, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text(
                  _passwordLastChanged != null
                      ? 'Last changed: ${_formatDate(_passwordLastChanged!)}'
                      : 'Update your account password',
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey[600]),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showChangePasswordDialog,
              ),
              Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey[200]),
              SwitchListTile(
                secondary: Icon(
                  Icons.security_outlined,
                  color: _twoFactorEnabled
                      ? const Color(0xFF10B981)
                      : (isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                ),
                title: const Text('Two-Factor Authentication', style: TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text(
                  _twoFactorEnabled
                      ? '✅ Enabled — your account is extra secure'
                      : 'Add a verification step when signing in',
                  style: TextStyle(
                    fontSize: 12,
                    color: _twoFactorEnabled
                        ? const Color(0xFF10B981)
                        : (isDark ? Colors.grey[500] : Colors.grey[600]),
                  ),
                ),
                value: _twoFactorEnabled,
                activeColor: const Color(0xFF10B981),
                onChanged: _handle2FAToggle,
              ),
            ]),

            const SizedBox(height: 24),

            // ACCOUNT DATA SECTION
            _sectionHeader('ACCOUNT DATA', isDark),
            _card(isDark, children: [
              ListTile(
                leading: const Icon(Icons.download_outlined, color: Color(0xFF3B82F6)),
                title: const Text('Download My Data', style: TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text(
                  'Request a copy of your data',
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey[600]),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Data export request submitted. You will receive an email shortly.')),
                  );
                },
              ),
              Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey[200]),
              ListTile(
                leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
                title: Text(
                  AppLocalizations.of(context).get('delete_account'),
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  AppLocalizations.of(context).get('delete_account_desc'),
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey[600]),
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.red),
                onTap: _showDeleteAccountDialog,
              ),
            ]),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _card(bool isDark, {required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}
