import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

class MarkdownViewScreen extends StatelessWidget {
  final String title;
  final String markdownData;

  const MarkdownViewScreen({
    super.key,
    required this.title,
    required this.markdownData,
  });

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch \$url';
      }
    } catch (e) {
      // Error handling is implicitly handled by not launching
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
      ),
      body: Markdown(
        data: markdownData,
        onTapLink: (text, href, title) {
          if (href != null) {
            _launchUrl(href);
          }
        },
        styleSheet: MarkdownStyleSheet(
          p: const TextStyle(fontSize: 15, color: Colors.black87),
          h1: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          h2: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          listBullet: const TextStyle(fontSize: 15, color: Colors.black87),
        ),
      ),
    );
  }
}
