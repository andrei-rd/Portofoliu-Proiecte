import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_settings/app_settings.dart';
import '../services/language_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final _lang = LanguageService();
  bool _reservationsEnabled = true;
  bool _expiryAlertsEnabled = true;
  bool _promotionsEnabled = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _reservationsEnabled = prefs.getBool('notif_reservations') ?? true;
      _expiryAlertsEnabled = prefs.getBool('notif_expiry') ?? true;
      _promotionsEnabled = prefs.getBool('notif_promos') ?? true;
      _isLoading = false;
    });
  }

  Future<void> _toggleReservations(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _reservationsEnabled = value);
    await prefs.setBool('notif_reservations', value);

    if (value) {
      await FirebaseMessaging.instance.subscribeToTopic('reservations');
    } else {
      await FirebaseMessaging.instance.unsubscribeFromTopic('reservations');
    }
  }

  Future<void> _toggleExpiry(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _expiryAlertsEnabled = value);
    await prefs.setBool('notif_expiry', value);
    // Logic will be handled by the notification scheduler reading from SharedPreferences
  }

  Future<void> _togglePromotions(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _promotionsEnabled = value);
    await prefs.setBool('notif_promos', value);

    if (value) {
      await FirebaseMessaging.instance.subscribeToTopic('promotions');
    } else {
      await FirebaseMessaging.instance.unsubscribeFromTopic('promotions');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _lang,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FB),
          appBar: AppBar(
            title: Text(_lang.translate('notif_settings_title'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            centerTitle: false,
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    _buildSwitchTile(
                      title: _lang.translate('notif_reservations'),
                      subtitle: _lang.translate('notif_reservations_desc'),
                      value: _reservationsEnabled,
                      onChanged: _toggleReservations,
                      icon: Icons.confirmation_number_outlined,
                    ),
                    const SizedBox(height: 16),
                    _buildSwitchTile(
                      title: _lang.translate('notif_expiry'),
                      subtitle: _lang.translate('notif_expiry_desc'),
                      value: _expiryAlertsEnabled,
                      onChanged: _toggleExpiry,
                      icon: Icons.timer_outlined,
                    ),
                    const SizedBox(height: 16),
                    _buildSwitchTile(
                      title: _lang.translate('notif_promos'),
                      subtitle: _lang.translate('notif_promos_desc'),
                      value: _promotionsEnabled,
                      onChanged: _togglePromotions,
                      icon: Icons.campaign_outlined,
                    ),
                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 16),
                    ListTile(
                      onTap: () => AppSettings.openAppSettings(
                          type: AppSettingsType.notification),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.settings,
                            color: Color(0xFF2563EB)),
                      ),
                      title: Text(
                        _lang.translate('notif_system_settings'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF2563EB),
        title: Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF2563EB)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(left: 32, top: 4),
          child: Text(
            subtitle,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}
