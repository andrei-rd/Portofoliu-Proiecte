import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:parkly/services/language_service.dart';

class NavigationUtils {
  static Future<void> showNavigationDialog(
      BuildContext context, double lat, double lng, String name) async {
    final lang = LanguageService();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                lang.translate('choose_nav_app'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavOption(
                    context,
                    'Google Maps',
                    'assets/images/google_maps.png', // Assume user has these or we use icons
                    Icons.map,
                    () => _launchGoogleMaps(lat, lng),
                  ),
                  _buildNavOption(
                    context,
                    'Waze',
                    'assets/images/waze.png',
                    Icons.navigation,
                    () => _launchWaze(lat, lng),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildNavOption(BuildContext context, String label,
      String asset, IconData fallbackIcon, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(fallbackIcon, size: 30, color: const Color(0xFF2563EB)),
          ),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  static Future<void> _launchGoogleMaps(double lat, double lng) async {
    final googleMapsUrl = 'google.navigation:q=$lat,$lng';
    final googleMapsUri = Uri.parse(googleMapsUrl);

    final webUrl =
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
    final webUri = Uri.parse(webUrl);

    if (await canLaunchUrl(googleMapsUri)) {
      await launchUrl(googleMapsUri);
    } else if (await canLaunchUrl(webUri)) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> _launchWaze(double lat, double lng) async {
    final wazeUrl = 'waze://?ll=$lat,$lng&navigate=yes';
    final wazeUri = Uri.parse(wazeUrl);

    final webUrl = 'https://waze.com/ul?ll=$lat,$lng&navigate=yes';
    final webUri = Uri.parse(webUrl);

    if (await canLaunchUrl(wazeUri)) {
      await launchUrl(wazeUri);
    } else if (await canLaunchUrl(webUri)) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }
}
