import 'package:flutter/material.dart';
import 'app_localizations.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.grey[300] : Colors.grey[800];
    final headingColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(t.get('pp_title')),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.get('pp_title'),
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: headingColor)),
            const SizedBox(height: 8),
            Text(t.get('pp_updated'),
                style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[600])),
            const SizedBox(height: 24),
            _buildSection(t.get('pp_s1_t'), t.get('pp_s1_b'), headingColor, textColor),
            _buildSection(t.get('pp_s2_t'), t.get('pp_s2_b'), headingColor, textColor),
            _buildSection(t.get('pp_s3_t'), t.get('pp_s3_b'), headingColor, textColor),
            _buildSection(t.get('pp_s4_t'), t.get('pp_s4_b'), headingColor, textColor),
            _buildSection(t.get('pp_s5_t'), t.get('pp_s5_b'), headingColor, textColor),
            _buildSection(t.get('pp_s6_t'), t.get('pp_s6_b'), headingColor, textColor),
            _buildSection(t.get('pp_s7_t'), t.get('pp_s7_b'), headingColor, textColor),
            _buildSection(t.get('pp_s8_t'), t.get('pp_s8_b'), headingColor, textColor),
            _buildSection(t.get('pp_s9_t'), t.get('pp_s9_b'), headingColor, textColor),
            _buildSection(t.get('pp_s10_t'), t.get('pp_s10_b'), headingColor, textColor),
            const SizedBox(height: 40),
            Center(
              child: Text(
                t.get('pp_footer'),
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String body, Color? heading, Color? text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 8),
          child: Text(title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: heading)),
        ),
        Text(body, style: TextStyle(fontSize: 15, height: 1.6, color: text)),
      ],
    );
  }
}
