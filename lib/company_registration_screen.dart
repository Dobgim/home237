import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import 'permission_service.dart';
import 'theme_notifier.dart';
import 'landlord_dashboard.dart';

/// Company / agency sign-up. Collects the company name and three mandatory
/// documents (business registration, taxpayer NIU card, representative's ID),
/// uploads them, and marks the account `pending`. An admin must approve before
/// the company can post. Companies get 5 free listings (vs 1 for agents).
class CompanyRegistrationScreen extends StatefulWidget {
  const CompanyRegistrationScreen({super.key});

  @override
  State<CompanyRegistrationScreen> createState() =>
      _CompanyRegistrationScreenState();
}

class _CompanyRegistrationScreenState extends State<CompanyRegistrationScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _companyNameController = TextEditingController();

  XFile? _businessRegDoc; // Business registration certificate
  XFile? _niuDoc; // Taxpayer number (NIU) card
  XFile? _repIdDoc; // Representative's ID card
  bool _isUploading = false;

  static const _navy = Color(0xFF1E3A5F);

  Future<void> _pickImage(String documentType) async {
    try {
      final granted = await PermissionService.requestPhotoPermission();
      if (!granted) {
        final status = await PermissionService.getPhotoPermissionStatus();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status.isPermanentlyDenied
                ? 'Please enable photo permission in settings'
                : 'Photo permission denied'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: () => openAppSettings(),
            ),
          ),
        );
        return;
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          if (documentType == 'businessReg') {
            _businessRegDoc = image;
          } else if (documentType == 'niu') {
            _niuDoc = image;
          } else if (documentType == 'repId') {
            _repIdDoc = image;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<String?> _uploadFile(XFile file, String fileName) async {
    try {
      if (authService.userId == null) return null;
      final supabase = Supabase.instance.client;
      final filePath = 'company/${authService.userId}/$fileName';

      const fileOptions = FileOptions(contentType: 'image/jpeg', upsert: true);

      final uploadFuture = kIsWeb
          ? () async {
              final bytes = await file.readAsBytes();
              return supabase.storage
                  .from('verifications')
                  .uploadBinary(filePath, bytes, fileOptions: fileOptions);
            }()
          : supabase.storage.from('verifications').upload(
                filePath,
                File(file.path),
                fileOptions: fileOptions,
              );

      await uploadFuture.timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw TimeoutException('Upload timed out'),
      );

      return supabase.storage.from('verifications').getPublicUrl(filePath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
      return null;
    }
  }

  Future<void> _submit() async {
    final name = _companyNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your company name')),
      );
      return;
    }
    if (_businessRegDoc == null || _niuDoc == null || _repIdDoc == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please upload all three required documents')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final businessRegUrl =
          await _uploadFile(_businessRegDoc!, 'business_registration.jpg');
      final niuUrl = await _uploadFile(_niuDoc!, 'niu_card.jpg');
      final repIdUrl = await _uploadFile(_repIdDoc!, 'representative_id.jpg');

      if (businessRegUrl == null || niuUrl == null || repIdUrl == null) {
        throw Exception('One or more documents failed to upload');
      }

      final companyDocs = {
        'businessRegUrl': businessRegUrl,
        'niuUrl': niuUrl,
        'repIdUrl': repIdUrl,
      };

      // Persist on the user document (accountType/companyStatus/etc.).
      await authService.registerAsCompany(
        companyName: name,
        companyDocs: companyDocs,
      );

      // Admin review queue.
      await FirebaseFirestore.instance.collection('company_registrations').add({
        'userId': authService.userId,
        'companyName': name,
        'userEmail': authService.userEmail,
        'status': 'pending',
        'businessRegUrl': businessRegUrl,
        'niuUrl': niuUrl,
        'repIdUrl': repIdUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      // Adopt the landlord theme now that the role is set.
      context.read<ThemeNotifier>().updateThemeForRole();

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LandlordDashboard()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting registration: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Company Registration',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
      body: _isUploading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Submitting your company for review...',
                      style: TextStyle(fontSize: 16, color: Color(0xFF64748B))),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _navy.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _navy.withOpacity(0.25)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.apartment, color: _navy),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Register your agency to post up to 5 properties for free. '
                          'Our team will review your documents before your account is activated.',
                          style: TextStyle(fontSize: 14, color: _navy),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Company Name *',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A))),
                const SizedBox(height: 8),
                TextField(
                  controller: _companyNameController,
                  decoration: InputDecoration(
                    hintText: 'e.g. Trust Realty Ltd',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Business Registration Certificate *',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A))),
                const SizedBox(height: 8),
                _buildDocumentUploadCard(
                  'Upload your company registration / incorporation document',
                  _businessRegDoc,
                  () => _pickImage('businessReg'),
                  Icons.business_center_outlined,
                  const Color(0xFF6366F1),
                ),
                const SizedBox(height: 20),
                const Text('Taxpayer Number (NIU) Card *',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A))),
                const SizedBox(height: 8),
                _buildDocumentUploadCard(
                  "Upload the company's Unique Identification Number card",
                  _niuDoc,
                  () => _pickImage('niu'),
                  Icons.receipt_long_outlined,
                  const Color(0xFFF59E0B),
                ),
                const SizedBox(height: 20),
                const Text("Representative's ID Card *",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A))),
                const SizedBox(height: 8),
                _buildDocumentUploadCard(
                  'Upload the ID card of the person managing this account',
                  _repIdDoc,
                  () => _pickImage('repId'),
                  Icons.badge_outlined,
                  const Color(0xFF10B981),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Submit for Review',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
    );
  }

  Widget _buildDocumentUploadCard(
    String description,
    XFile? file,
    VoidCallback onTap,
    IconData icon,
    Color accentColor,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                file != null ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: file == null
            ? Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 32, color: accentColor),
                  ),
                  const SizedBox(height: 16),
                  Text(description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF64748B))),
                  const SizedBox(height: 16),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Select File',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: accentColor)),
                  ),
                ],
              )
            : Column(
                children: [
                  Stack(
                    alignment: Alignment.topRight,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: kIsWeb
                            ? Image.network(file.path,
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover)
                            : Image.file(File(file.path),
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover),
                      ),
                      GestureDetector(
                        onTap: onTap,
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.black26, blurRadius: 4)
                            ],
                          ),
                          child: const Icon(Icons.edit,
                              size: 18, color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle,
                          color: Color(0xFF10B981), size: 18),
                      SizedBox(width: 6),
                      Text('Document selected',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF10B981))),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
