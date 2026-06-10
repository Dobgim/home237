import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class EmailService {
  // Replace this with the actual Gmail address where you generated the app password
  static const String _username = 'dobgimajoshua52@gmail.com';  
  static const String _password = 'gptfovlohzlzfams'; // The App Password provided

  static Future<bool> send2FACode(String toEmail, String code) async {
    final smtpServer = gmail(_username, _password);

    final message = Message()
      ..from = const Address(_username, 'Home237 Security')
      ..recipients.add(toEmail)
      ..subject = 'Your Home237 Verification Code'
      ..text = 'Your Home237 verification code is: $code\n\nThis code expires in 10 minutes.\nIf you did not request this, please ignore this email.\n\n— The Home237 Team'
      ..html = '''
      <div style="font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto;">
        <div style="background: #3B82F6; padding: 24px; text-align: center; border-radius: 12px 12px 0 0;">
          <h1 style="color: white; font-size: 24px; margin: 0;">🏠 Home237</h1>
        </div>
        <div style="background: #f9fafb; padding: 32px; border-radius: 0 0 12px 12px; border: 1px solid #e5e7eb;">
          <h2 style="color: #1e293b; margin-bottom: 8px;">Your Verification Code</h2>
          <p style="color: #64748b;">Use the code below to complete your two-factor authentication setup:</p>
          <div style="background: white; border: 2px solid #3B82F6; border-radius: 12px; padding: 20px; text-align: center; margin: 24px 0;">
            <span style="font-size: 36px; font-weight: bold; letter-spacing: 12px; color: #1e293b;">$code</span>
          </div>
          <p style="color: #64748b; font-size: 14px;">This code expires in <strong>10 minutes</strong>.</p>
          <p style="color: #9ca3af; font-size: 12px;">If you did not request this code, please ignore this email or contact support if you have concerns.</p>
        </div>
        <p style="text-align: center; color: #9ca3af; font-size: 12px; margin-top: 16px;">© 2026 Home237. All rights reserved.</p>
      </div>
      ''';

    try {

      await send(message, smtpServer);
      return true;
    } catch (e) {
      print('SMTP Email Error: $e');
      return false;
    }
  }
}
