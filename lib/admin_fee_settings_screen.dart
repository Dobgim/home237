import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminFeeSettingsScreen extends StatefulWidget {
  const AdminFeeSettingsScreen({super.key});

  @override
  State<AdminFeeSettingsScreen> createState() => _AdminFeeSettingsScreenState();
}

class _AdminFeeSettingsScreenState extends State<AdminFeeSettingsScreen> {
  final _phoneController = TextEditingController();
  final _apiUserController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _commissionController = TextEditingController();
  String _selectedMode = 'live'; // 'live' or 'sandbox'
  bool _isLoading = false;
  bool _obscureApiKey = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      // Load payout number
      final payoutDoc = await FirebaseFirestore.instance
          .collection('admin_settings')
          .doc('payout')
          .get();
      
      if (payoutDoc.exists) {
        _phoneController.text = payoutDoc.data()?['payoutNumber'] ?? '';
      }

      // Load Fapshi credentials
      final fapshiDoc = await FirebaseFirestore.instance
          .collection('admin_settings')
          .doc('fapshi')
          .get();
      
      if (fapshiDoc.exists) {
        final data = fapshiDoc.data();
        if (data != null) {
          _apiUserController.text = data['apiUser'] ?? '';
          _apiKeyController.text = data['apiKey'] ?? '';
          _selectedMode = data['mode'] ?? 'live';
        }
      }

      // Load platform fees
      final feesDoc = await FirebaseFirestore.instance
          .collection('admin_settings')
          .doc('fees')
          .get();

      final commission = feesDoc.data()?['rentCommissionPercent'];
      _commissionController.text =
          commission is num ? commission.toInt().toString() : '5';
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load settings: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    final phone = _phoneController.text.trim();
    final apiUser = _apiUserController.text.trim();
    final apiKey = _apiKeyController.text.trim();

    if (phone.isEmpty || phone.length < 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid phone number')),
      );
      return;
    }

    final commission =
        int.tryParse(_commissionController.text.trim()) ?? 5;
    if (commission < 0 || commission > 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Commission must be between 0 and 20 percent')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Save payout number
      await FirebaseFirestore.instance
          .collection('admin_settings')
          .doc('payout')
          .set({
        'payoutNumber': phone,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Save Fapshi credentials
      await FirebaseFirestore.instance
          .collection('admin_settings')
          .doc('fapshi')
          .set({
        'apiUser': apiUser,
        'apiKey': apiKey,
        'mode': _selectedMode,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Save platform fees
      await FirebaseFirestore.instance
          .collection('admin_settings')
          .doc('fees')
          .set({
        'rentCommissionPercent': commission,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _apiUserController.dispose();
    _apiKeyController.dispose();
    _commissionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Payment & Payout Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.account_balance_wallet_rounded, size: 48, color: Colors.white),
                          const SizedBox(height: 12),
                          Text(
                            'Admin Payout Settings',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white.withOpacity(0.9)),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Set the Mobile Money number where landlord subscriptions, posting fees, and administrative payouts are managed.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    
                    // Payout Number Section
                    Text(
                      'Admin Payout Mobile Money Number',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: 'e.g. 670 000 000',
                        prefixIcon: const Icon(Icons.phone_android_rounded),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF2D2D2D) : Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),

                    // Platform Commission Section
                    Text(
                      'Rent Commission (%)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Percentage Home237 keeps from each rent payment before the landlord payout (0–20).',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white30 : Colors.grey[500]),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _commissionController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'e.g. 5',
                        prefixIcon: const Icon(Icons.percent_rounded),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF2D2D2D) : Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 24),

                    // Fapshi Settings Section
                    Text(
                      'Fapshi API Credentials',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Obtain your API User and Key from dashboard.fapshi.com',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white30 : Colors.grey[500]),
                    ),
                    const SizedBox(height: 16),

                    // Fapshi API User
                    Text(
                      'Fapshi API User',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white60 : Colors.grey[700]),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _apiUserController,
                      decoration: InputDecoration(
                        hintText: 'e.g. abc123',
                        prefixIcon: const Icon(Icons.person_outline),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF2D2D2D) : Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Fapshi API Key
                    Text(
                      'Fapshi API Key',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white60 : Colors.grey[700]),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _apiKeyController,
                      obscureText: _obscureApiKey,
                      decoration: InputDecoration(
                        hintText: 'e.g. xyz789...',
                        prefixIcon: const Icon(Icons.vpn_key_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureApiKey ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF2D2D2D) : Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Fapshi Mode Dropdown
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Fapshi Environment Mode',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white60 : Colors.grey[700]),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2D2D2D) : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedMode,
                              items: const [
                                DropdownMenuItem(value: 'live', child: Text('Live (Real money)')),
                                DropdownMenuItem(value: 'sandbox', child: Text('Sandbox (Testing)')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedMode = val);
                                }
                              },
                              dropdownColor: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),
                    
                    ElevatedButton(
                      onPressed: _saveSettings,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xFF8B5CF6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Save Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
