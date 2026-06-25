import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/language_service.dart';
import '../utils/legal_texts.dart';
import 'markdown_view_screen.dart';
import 'chat_conversation_screen.dart';

class HelpAndSupportScreen extends StatefulWidget {
  const HelpAndSupportScreen({super.key});

  @override
  State<HelpAndSupportScreen> createState() => _HelpAndSupportScreenState();
}

class _HelpAndSupportScreenState extends State<HelpAndSupportScreen> {
  final _lang = LanguageService();
  String _appVersion = '1.0.0 (1)';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = '${packageInfo.version} (${packageInfo.buildNumber})';
      });
    } catch (e) {
      // Fallback to default
    }
  }

  void _openSupportChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ChatConversationScreen(
          receiverId: 'parkly_support',
          receiverName: 'Echipa Parkly',
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _lang,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FB),
          appBar: AppBar(
            title: Text(_lang.translate('support'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            centerTitle: false,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 0. User Guide Section
                Text(_lang.translate('user_guide_title'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildGuideCard(
                  Icons.directions_car_filled_outlined,
                  _lang.translate('guide_driver_title'),
                  _lang.translate('guide_driver_desc'),
                  _lang.translate('guide_driver_detail'),
                  const Color(0xFF2563EB),
                ),
                _buildGuideCard(
                  Icons.admin_panel_settings_outlined,
                  _lang.translate('guide_owner_title'),
                  _lang.translate('guide_owner_desc'),
                  _lang.translate('guide_owner_detail'),
                  const Color(0xFF10B981),
                ),
                _buildGuideCard(
                  Icons.account_balance_wallet_outlined,
                  _lang.translate('guide_payment_title'),
                  _lang.translate('guide_payment_desc'),
                  _lang.translate('guide_payment_detail'),
                  const Color(0xFFF59E0B),
                ),

                const SizedBox(height: 32),

                // 1. FAQ Section
                Text(_lang.translate('faq_title'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildFAQTile(
                    _lang.translate('faq_1_q'), _lang.translate('faq_1_a')),
                _buildFAQTile(
                    _lang.translate('faq_2_q'), _lang.translate('faq_2_a')),
                _buildFAQTile(
                    _lang.translate('faq_3_q'), _lang.translate('faq_3_a')),
                _buildFAQTile(
                    _lang.translate('faq_4_q'), _lang.translate('faq_4_a')),
                _buildFAQTile(_lang.translate('faq_reported_q'),
                    _lang.translate('faq_reported_a')),
                _buildFAQTile(_lang.translate('faq_nav_q'),
                    _lang.translate('faq_nav_a')),
                _buildFAQTile(_lang.translate('faq_security_q'),
                    _lang.translate('faq_security_a')),
                _buildFAQTile(_lang.translate('faq_profile_q'),
                    _lang.translate('faq_profile_a')),
                _buildFAQTile(_lang.translate('faq_wallet_q'),
                    _lang.translate('faq_wallet_a')),
                _buildFAQTile(_lang.translate('faq_transfer_q'),
                    _lang.translate('faq_transfer_a')),
                _buildFAQTile(_lang.translate('faq_cancel_q'),
                    _lang.translate('faq_cancel_a')),
                _buildFAQTile(_lang.translate('faq_cars_q'),
                    _lang.translate('faq_cars_a')),
                _buildFAQTile(_lang.translate('faq_extend_q'),
                    _lang.translate('faq_extend_a')),

                const SizedBox(height: 32),

                // 2. Contact Section
                Center(
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _openSupportChat,
                          icon: const Icon(Icons.chat_bubble_outline,
                              color: Colors.white),
                          label: Text(_lang.translate('contact_support_btn'),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // 3. Legal Section
                Text(_lang.translate('legal_info'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.description_outlined,
                      color: Color(0xFF2563EB)),
                  title: Text(_lang.translate('terms_conditions')),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MarkdownViewScreen(
                          title: _lang.translate('terms_conditions'),
                          markdownData: LegalTexts.termsConditions,
                        ),
                      ),
                    );
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined,
                      color: Color(0xFF2563EB)),
                  title: Text(_lang.translate('privacy_policy')),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MarkdownViewScreen(
                          title: _lang.translate('privacy_policy'),
                          markdownData: LegalTexts.privacyPolicy,
                        ),
                      ),
                    );
                  },
                  contentPadding: EdgeInsets.zero,
                ),

                const SizedBox(height: 60),

                // 4. Version Section
                Center(
                  child: Text(
                    '${_lang.translate('app_version_label')}: $_appVersion',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFAQTile(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ExpansionTile(
        title: Text(question,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(answer,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideCard(IconData icon, String title, String desc, String detail, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.all(16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          title: Text(title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(desc,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ),
          iconColor: Colors.grey,
          collapsedIconColor: Colors.grey,
          children: [
            const Divider(height: 1),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: Text(
                detail,
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
