import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'admin_service.dart';

class BroadcastScreen extends StatefulWidget {
  const BroadcastScreen({super.key});

  @override
  State<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends State<BroadcastScreen> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  
  String _selectedTarget = 'all'; // all, unverified, owners
  bool _sendPush = true;
  bool _sendEmail = false;
  bool _isSending = false;

  @override
  Widget build(BuildContext context) {
    final adminService = Provider.of<AdminService>(context, listen: false);
    const Color brandColor = Color(0xFF2563EB);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Compozitor Notificări & Email', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Side: Editor
            Expanded(
              flex: 2,
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Conținut Mesaj", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Titlu Subiect',
                          hintText: 'ex: Ofertă de weekend sau Mentenanță sistem',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _messageController,
                        maxLines: 8,
                        decoration: const InputDecoration(
                          labelText: 'Mesaj principal',
                          hintText: 'Scrie aici textul notificării sau al email-ului...',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 32),
            // Right Side: Configuration & Summary
            Expanded(
              child: Column(
                children: [
                  // Target Segmentation
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Segmentare Utilizatori", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          _buildTargetOption('all', 'Toți Utilizatorii', Icons.people),
                          _buildTargetOption('owners', 'Posesori Locuri Parcare', Icons.local_parking),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Channels
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Canale de Livrare", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          SwitchListTile(
                            title: const Text("Push Notification (FCM)"),
                            subtitle: const Text("Trimite pe telefonul mobil"),
                            value: _sendPush,
                            onChanged: (v) => setState(() => _sendPush = v),
                            secondary: const Icon(Icons.notifications_active_outlined),
                          ),
                          const Divider(),
                          SwitchListTile(
                            title: const Text("Email oficial"),
                            subtitle: const Text("Trimite via SendGrid/Mailgun"),
                            value: _sendEmail,
                            onChanged: (v) => setState(() => _sendEmail = v),
                            secondary: const Icon(Icons.alternate_email),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton.icon(
                      onPressed: _isSending ? null : _handleSend,
                      icon: _isSending 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.rocket_launch, color: Colors.white),
                      label: Text(
                        _isSending ? "Se trimite..." : "Lansează Campanie",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetOption(String value, String label, IconData icon) {
    bool isSelected = _selectedTarget == value;
    return InkWell(
      onTap: () => setState(() => _selectedTarget = value),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? const Color(0xFF2563EB) : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? const Color(0xFF2563EB) : Colors.grey),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? const Color(0xFF2563EB) : Colors.black87,
            )),
            const Spacer(),
            if (isSelected) const Icon(Icons.check_circle, color: Color(0xFF2563EB), size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSend() async {
    if (_titleController.text.isEmpty || _messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vă rugăm să completați Titlul și Mesajul!'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (!_sendPush && !_sendEmail) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selectați cel puțin un canal de livrare!'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final adminService = Provider.of<AdminService>(context, listen: false);
      await adminService.sendBroadcast(
        title: _titleController.text,
        message: _messageController.text,
        target: _selectedTarget,
        sendPush: _sendPush,
        sendEmail: _sendEmail,
      );

      if (mounted) {
        _titleController.clear();
        _messageController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Campania a fost lansată cu succes!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eroare: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
}
