import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import 'permission_service.dart';

class VerificationUploadScreen extends StatefulWidget {
  final UserRole userRole;
  const VerificationUploadScreen({super.key, required this.userRole});

  @override
  State<VerificationUploadScreen> createState() => _VerificationUploadScreenState();
}

class _VerificationUploadScreenState extends State<VerificationUploadScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _idDocument;
  XFile? _secondaryDocument; // Proof of address or Ownership
  XFile? _additionalDocument;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  // Removed local _requestPermission as it is now in PermissionService


  Future<void> _pickImage(String documentType) async {
    try {
      // Request permission using robust centralized service
      final granted = await PermissionService.requestPhotoPermission();
      
      if (!granted) {
        final status = await PermissionService.getPhotoPermissionStatus();

        if (status.isPermanentlyDenied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Please enable photo permission in settings'),
                backgroundColor: Colors.red,
                action: SnackBarAction(
                  label: 'Settings',
                  textColor: Colors.white,
                  onPressed: () => openAppSettings(),
                ),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Photo permission denied'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
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
          if (documentType == 'id') {
            _idDocument = image;
          } else if (documentType == 'secondary') {
            _secondaryDocument = image;
          } else if (documentType == 'additional') {
            _additionalDocument = image;
          }
        });
      }
    } catch (e) {
      print('❌ Error picking image: $e');
      if (mounted) {
        String message = 'Error picking image: $e';
        if (e.toString().contains('photo_access_denied') || e.toString().contains('camera_access_denied')) {
          message = 'Permission denied. Please enable access in settings.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
    }
  }

  Future<String?> _uploadFile(XFile file, String fileName) async {
    try {
      if (authService.userId == null) {
        print('❌ Error: User ID is null');
        return null;
      }
      
      print('🚀 Starting Supabase upload for $fileName...');
      final supabase = Supabase.instance.client;
      
      // Read file bytes
      print('📖 Reading bytes for $fileName...');
      final bytes = await file.readAsBytes();
      
      // Upload to Supabase Storage
      final filePath = '${authService.userId}/$fileName';
      print('⬆️ Uploading to Supabase: $filePath');
      
      await supabase.storage
          .from('verifications')
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          )
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              print('⏰ Upload timed out for $fileName');
              throw TimeoutException('Upload timed out');
            },
          );
      
      // Get public URL
      final downloadUrl = supabase.storage
          .from('verifications')
          .getPublicUrl(filePath);
      
      print('✅ Upload complete for $fileName');
      print('🔗 Download URL: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('❌ Error uploading file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
      return null;
    }
  }

  Future<void> _submitVerification() async {
    if (_idDocument == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload your ID document')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      // Upload documents
      final idUrl = await _uploadFile(_idDocument!, 'id_document.jpg');
      final secondaryUrl = _secondaryDocument != null
          ? await _uploadFile(_secondaryDocument!, 'secondary_document.jpg')
          : null;
      final additionalUrl = _additionalDocument != null
          ? await _uploadFile(_additionalDocument!, 'additional_document.jpg')
          : null;

      if (idUrl == null) {
        throw Exception('Failed to upload ID document');
      }

      // Create verification request
      await FirebaseFirestore.instance.collection('verifications').add({
        'userId': authService.userId,
        'userName': authService.userName,
        'userEmail': authService.userEmail,
        'userRole': authService.userRole.toString().split('.').last,
        'status': 'pending',
        'idDocumentUrl': idUrl,
        'secondaryDocumentUrl': secondaryUrl,
        'additionalDocumentUrl': additionalUrl,
        'documents': [
          if (idUrl != null) 'ID Document',
          if (secondaryUrl != null) 
            widget.userRole == UserRole.landlord ? 'Ownership Document' : 'Proof of Address',
          if (additionalUrl != null) 'Additional Document',
        ],
        'idVerified': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification request submitted successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting verification: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
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
          'Verification Upload',
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
                  Text(
                    'Uploading documents...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF0EA5E9).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFF0EA5E9)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Upload your documents for verification. Admin will review and approve your account.',
                          style: TextStyle(
                            fontSize: 14,
                            color: const Color(0xFF0EA5E9).withOpacity(0.9),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ID Document (Required)
                const Text(
                  'Personal Identification *',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                _buildDocumentUploadCard(
                  'Upload your ID card, passport, or driver\'s license',
                  _idDocument,
                  () => _pickImage('id'),
                  Icons.person_pin_outlined,
                  const Color(0xFF6366F1),
                ),

                const SizedBox(height: 20),

                // Secondary Document (Address/Ownership)
                Text(
                  widget.userRole == UserRole.landlord 
                      ? 'Property Ownership Proof *' 
                      : 'Proof of Address *',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                _buildDocumentUploadCard(
                  widget.userRole == UserRole.landlord
                      ? 'Upload land title, tax receipt, or deed of sale'
                      : 'Upload utility bill, bank statement, or lease agreement',
                  _secondaryDocument,
                  () => _pickImage('secondary'),
                  widget.userRole == UserRole.landlord ? Icons.home_work_outlined : Icons.location_on_outlined,
                  const Color(0xFFF59E0B),
                ),

                const SizedBox(height: 20),

                // Additional Document
                const Text(
                  'Additional Document (Optional)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                _buildDocumentUploadCard(
                  'Any other document that supports your identity',
                  _additionalDocument,
                  () => _pickImage('additional'),
                  Icons.note_add_outlined,
                  const Color(0xFF10B981),
                ),

                const SizedBox(height: 32),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitVerification,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0EA5E9),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Submit for Verification',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
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
            color: file != null ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
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
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Select File',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: accentColor,
                      ),
                    ),
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
                            ? Image.network(
                                file.path,
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              )
                            : Image.file(
                                File(file.path),
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                      ),
                      GestureDetector(
                        onTap: onTap,
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                          ),
                          child: const Icon(Icons.edit, size: 18, color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18),
                      const SizedBox(width: 6),
                      const Text(
                        'Document selected',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
